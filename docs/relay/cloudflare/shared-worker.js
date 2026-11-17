// Public shared Guardian relay for Vista VPN.
// Unlike docs/relay/cloudflare/worker.js (a personal relay), this endpoint
// has no shared secret in its URL. It is deliberately restricted to
// https://vpn.mozilla.org/api/v1/fpn/* and protected by Cloudflare rate-limit
// bindings. Do not use this as a general-purpose proxy.

const MAX_REQUEST_BODY = 1024 * 1024; // 1 MiB
const MAX_RESPONSE_BODY = 1024 * 1024; // Guardian JSON responses are small.
const UPSTREAM_TIMEOUT_MS = 12_000;

const DROP_HEADERS = new Set([
  "host", "connection", "content-length", "keep-alive",
  "proxy-authenticate", "proxy-authorization", "te", "trailer",
  "transfer-encoding", "upgrade", "forwarded", "x-forwarded-for",
  "x-forwarded-proto", "x-forwarded-host", "x-real-ip",
  "true-client-ip",
]);

function fail(status, reason) {
  return new Response(reason, {
    status,
    headers: {
      "X-Relay-Error": reason,
      "Content-Type": "text/plain; charset=utf-8",
      "Cache-Control": "no-store",
    },
  });
}

async function readLimited(stream, limit) {
  if (!stream) return new Uint8Array();
  const reader = stream.getReader();
  const chunks = [];
  let total = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.byteLength;
    if (total > limit) {
      await reader.cancel();
      throw new RangeError("body too large");
    }
    chunks.push(value);
  }
  const body = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    body.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return body;
}

async function digest(value) {
  const bytes = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return Array.from(new Uint8Array(bytes), (byte) => byte.toString(16).padStart(2, "0")).join("");
}

function health() {
  return new Response(JSON.stringify({
    relay: "vista-vpn",
    version: 1,
    ready: true,
  }), {
    status: 200,
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
    },
  });
}

function cleanHeaders(source) {
  const headers = new Headers();
  for (const [name, value] of source) {
    const lower = name.toLowerCase();
    if (
      DROP_HEADERS.has(lower) ||
      lower.startsWith("cf-") ||
      lower === "x-vista-relay" ||
      lower === "x-relay-error"
    ) {
      continue;
    }
    headers.append(name, value);
  }
  return headers;
}

function responseHeaders(source) {
  const headers = cleanHeaders(source);
  headers.set("X-Vista-Relay", "1");
  headers.set("Cache-Control", "no-store");
  return headers;
}

export default {
  async fetch(request, env) {
    const here = new URL(request.url);
    const isHealth = here.searchParams.get("health") === "1";

    // The app probes health before it sends any account credentials.
    if (isHealth) {
      if (request.method !== "GET") return fail(405, "health requires GET");
      if (!env.USER_LIMITER || !env.IP_LIMITER) {
        return fail(503, "rate limiting bindings are not configured");
      }
      return health();
    }

    if (!here.searchParams.has("url")) {
      return new Response("Vista VPN shared Guardian relay", {
        status: 200,
        headers: { "Content-Type": "text/plain; charset=utf-8", "Cache-Control": "no-store" },
      });
    }

    const method = request.method.toUpperCase();
    if (!["GET", "HEAD", "POST"].includes(method)) {
      return fail(405, "method not allowed");
    }

    const rawTarget = here.searchParams.get("url") || "";
    if (!rawTarget || rawTarget.length > 8192) {
      return fail(400, "target URL is missing or too long");
    }

    let target;
    try {
      target = new URL(rawTarget);
    } catch {
      return fail(400, "target must be an HTTPS Guardian URL");
    }

    if (
      target.protocol !== "https:" ||
      target.hostname.toLowerCase() !== "vpn.mozilla.org" ||
      (target.port && target.port !== "443") ||
      target.username ||
      target.password ||
      target.hash ||
      !target.pathname.startsWith("/api/v1/fpn/")
    ) {
      return fail(403, "only https://vpn.mozilla.org/api/v1/fpn/* is allowed");
    }

    // Both limits are required. The account token is hashed before it is
    // used as a rate-limit key; raw credentials are never logged or stored.
    if (!env.USER_LIMITER || !env.IP_LIMITER) {
      return fail(503, "rate limiting bindings are not configured");
    }

    const ip = request.headers.get("CF-Connecting-IP") || "unknown";
    const authorization = request.headers.get("Authorization") || "";
    const actorKey = authorization ? "token:" + await digest(authorization) : "ip:" + ip;

    try {
      const [userLimit, ipLimit] = await Promise.all([
        env.USER_LIMITER.limit({ key: actorKey }),
        env.IP_LIMITER.limit({ key: ip }),
      ]);
      if (!userLimit.success || !ipLimit.success) {
        return fail(429, "shared relay rate limit exceeded");
      }
    } catch {
      // Fail closed if Cloudflare rate limiting is unavailable.
      return fail(503, "shared relay rate limiting is unavailable");
    }

    let body = null;
    if (method === "POST") {
      const declared = request.headers.get("content-length");
      if (declared !== null && (!/^\\d+$/.test(declared) || Number(declared) > MAX_REQUEST_BODY)) {
        return fail(413, "request body exceeds 1 MiB");
      }
      try {
        body = await readLimited(request.body, MAX_REQUEST_BODY);
      } catch (error) {
        return fail(error instanceof RangeError ? 413 : 400, "could not read request body within the 1 MiB limit");
      }
    }

    const upstreamHeaders = cleanHeaders(request.headers);
    // Keep the response body uncompressed so its size cap and forwarded
    // Content-Encoding headers describe the same bytes.
    upstreamHeaders.set("Accept-Encoding", "identity");

    let upstream;
    try {
      upstream = await fetch(target, {
        method,
        headers: upstreamHeaders,
        body,
        redirect: "manual",
        signal: AbortSignal.timeout(UPSTREAM_TIMEOUT_MS),
      });
    } catch {
      return fail(502, "Guardian upstream request failed or timed out");
    }

    let responseBody = null;
    if (method !== "HEAD" && upstream.status !== 204 && upstream.status !== 304) {
      const declared = upstream.headers.get("content-length");
      if (declared !== null && Number(declared) > MAX_RESPONSE_BODY) {
        await upstream.body?.cancel();
        return fail(502, "Guardian response exceeds 1 MiB");
      }
      try {
        responseBody = await readLimited(upstream.body, MAX_RESPONSE_BODY);
      } catch {
        return fail(502, "Guardian response exceeds 1 MiB");
      }
    }

    return new Response(responseBody, {
      status: upstream.status,
      statusText: upstream.statusText,
      headers: responseHeaders(upstream.headers),
    });
  },
};
