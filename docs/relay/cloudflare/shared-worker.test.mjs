import { test } from "node:test";
import assert from "node:assert/strict";
import sharedWorker from "./shared-worker.js";

function makeEnv({ userAllowed = true, ipAllowed = true, onUserKey = () => {}, onIPKey = () => {} } = {}) {
  return {
    USER_LIMITER: {
      async limit({ key }) {
        onUserKey(key);
        return { success: userAllowed };
      },
    },
    IP_LIMITER: {
      async limit({ key }) {
        onIPKey(key);
        return { success: ipAllowed };
      },
    },
  };
}

function relayRequest(target, init = {}) {
  const query = new URLSearchParams({ url: target });
  return new Request("https://shared.example/?" + query.toString(), init);
}

test("health is available without account credentials when rate limiters exist", async () => {
  const response = await sharedWorker.fetch(
    new Request("https://shared.example/?health=1"),
    makeEnv(),
  );
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), {
    relay: "vista-vpn",
    version: 1,
    ready: true,
  });
});

test("health fails closed when a rate limiter is missing", async () => {
  const response = await sharedWorker.fetch(
    new Request("https://shared.example/?health=1"),
    { USER_LIMITER: { limit: async () => ({ success: true }) } },
  );
  assert.equal(response.status, 503);
});

test("forwards only the Guardian FPN endpoint and sanitizes hop headers", async () => {
  const originalFetch = globalThis.fetch;
  let seen;
  let userKey = "";
  try {
    globalThis.fetch = async (target, init) => {
      seen = { target: String(target), method: init.method, headers: new Headers(init.headers) };
      return new Response('{"token":"fixture"}', {
        status: 200,
        headers: { "Content-Type": "application/json", "X-Vista-Relay": "spoofed" },
      });
    };
    const response = await sharedWorker.fetch(
      relayRequest("https://vpn.mozilla.org/api/v1/fpn/token", {
        headers: {
          Authorization: "Bearer private-fixture-token",
          "CF-Connecting-IP": "203.0.113.10",
          "X-Forwarded-For": "spoofed",
          "X-Vista-Relay": "spoofed",
        },
      }),
      makeEnv({ onUserKey: (key) => { userKey = key; } }),
    );

    assert.equal(response.status, 200);
    assert.equal(response.headers.get("X-Vista-Relay"), "1");
    assert.equal(response.headers.get("Cache-Control"), "no-store");
    assert.equal(seen.target, "https://vpn.mozilla.org/api/v1/fpn/token");
    assert.equal(seen.method, "GET");
    assert.equal(seen.headers.get("Authorization"), "Bearer private-fixture-token");
    assert.equal(seen.headers.get("X-Forwarded-For"), null);
    assert.equal(seen.headers.get("X-Vista-Relay"), null);
    assert.ok(userKey.startsWith("token:"));
    assert.equal(userKey.includes("private-fixture-token"), false);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test("rejects destinations outside the exact Guardian FPN path", async () => {
  const originalFetch = globalThis.fetch;
  let called = false;
  try {
    globalThis.fetch = async () => {
      called = true;
      return new Response("{}");
    };
    const response = await sharedWorker.fetch(
      relayRequest("https://vpn.mozilla.org.evil.example/api/v1/fpn/token"),
      makeEnv(),
    );
    assert.equal(response.status, 403);
    assert.equal(called, false);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test("rate-limit rejection never reaches Guardian", async () => {
  const originalFetch = globalThis.fetch;
  let called = false;
  try {
    globalThis.fetch = async () => {
      called = true;
      return new Response("{}");
    };
    const response = await sharedWorker.fetch(
      relayRequest("https://vpn.mozilla.org/api/v1/fpn/token"),
      makeEnv({ userAllowed: false }),
    );
    assert.equal(response.status, 429);
    assert.equal(response.headers.get("X-Relay-Error"), "shared relay rate limit exceeded");
    assert.equal(called, false);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test("rejects request bodies larger than 1 MiB", async () => {
  const originalFetch = globalThis.fetch;
  let called = false;
  try {
    globalThis.fetch = async () => {
      called = true;
      return new Response("{}");
    };
    const response = await sharedWorker.fetch(
      relayRequest("https://vpn.mozilla.org/api/v1/fpn/activate", {
        method: "POST",
        body: new Uint8Array(1024 * 1024 + 1),
      }),
      makeEnv(),
    );
    assert.equal(response.status, 413);
    assert.equal(called, false);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test("rejects upstream responses larger than 1 MiB", async () => {
  const originalFetch = globalThis.fetch;
  try {
    globalThis.fetch = async () => new Response(new Uint8Array(1024 * 1024 + 1), { status: 200 });
    const response = await sharedWorker.fetch(
      relayRequest("https://vpn.mozilla.org/api/v1/fpn/token"),
      makeEnv(),
    );
    assert.equal(response.status, 502);
    assert.match(await response.text(), /exceeds 1 MiB/);
  } finally {
    globalThis.fetch = originalFetch;
  }
});
