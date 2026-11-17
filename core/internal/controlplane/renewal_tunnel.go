package controlplane

import (
	"bytes"
	"context"
	"crypto/tls"
	"io"
	"net"
	"net/http"
	"net/http/httptrace"
	"sync/atomic"
	"time"
)

const (
	renewalTunnelHandshake = 5 * time.Second
	renewalTunnelTimeout   = 15 * time.Second
)

type renewalTunnelClientKey struct{}

// WithRenewalTunnel supplies a short-lived HTTPS client whose TCP streams are
// opened inside an already-established Mozilla proxy session. It is used only
// for Guardian renewal requests; it does not replace the normal control-plane
// transport or its Firefox TLS profile.
func WithRenewalTunnel(ctx context.Context, dial func(context.Context, string) (net.Conn, error)) (context.Context, func()) {
	if ctx.Value(renewalTunnelClientKey{}) != nil {
		return ctx, func() {}
	}
	transport := &http.Transport{
		ForceAttemptHTTP2:   true,
		TLSHandshakeTimeout: renewalTunnelHandshake,
		TLSClientConfig:     &tls.Config{MinVersion: tls.VersionTLS12},
		DialContext: func(ctx context.Context, _, address string) (net.Conn, error) {
			return dial(ctx, address)
		},
	}
	tunnel := &http.Client{
		Transport: transport,
		Jar:       client.Jar,
		Timeout:   renewalTunnelTimeout,
		CheckRedirect: func(*http.Request, []*http.Request) error {
			return http.ErrUseLastResponse
		},
	}
	return context.WithValue(ctx, renewalTunnelClientKey{}, tunnel), transport.CloseIdleConnections
}

// TryRenewalTunnel attempts one HTTPS control-plane request through the
// current VPN session. handled=false means the caller may use its normal
// route. A write is never replayed after a connection was established.
func TryRenewalTunnel(req *http.Request) (*http.Response, error, bool) {
	tunnel, _ := req.Context().Value(renewalTunnelClientKey{}).(*http.Client)
	if tunnel == nil || req.URL == nil || req.URL.Scheme != "https" ||
		!UsesDefaultTransport() {
		return nil, nil, false
	}

	var connected atomic.Bool
	ctx := httptrace.WithClientTrace(req.Context(), &httptrace.ClientTrace{
		GotConn: func(httptrace.GotConnInfo) { connected.Store(true) },
	})
	out := req.Clone(ctx)
	if req.Body != nil && req.Body != http.NoBody {
		if req.GetBody == nil {
			return nil, nil, false
		}
		body, err := req.GetBody()
		if err != nil {
			return nil, err, true
		}
		out.Body = body
	}

	resp, err := tunnel.Do(out)
	readOnly := req.Method == http.MethodGet || req.Method == http.MethodHead
	if err != nil {
		if req.Context().Err() == nil && (readOnly || !connected.Load()) {
			return nil, nil, false
		}
		return resp, err, true
	}
	if resp.StatusCode == http.StatusNotAcceptable ||
		resp.StatusCode == http.StatusMisdirectedRequest ||
		resp.StatusCode == http.StatusUnavailableForLegalReasons ||
		(readOnly && resp.StatusCode >= 500) {
		resp.Body.Close()
		return nil, nil, false
	}
	if readOnly && resp.StatusCode == http.StatusOK {
		body, readErr := io.ReadAll(resp.Body)
		resp.Body.Close()
		if readErr != nil {
			if req.Context().Err() != nil {
				return nil, req.Context().Err(), true
			}
			return nil, nil, false
		}
		resp.Body = io.NopCloser(bytes.NewReader(body))
	}
	return resp, nil, true
}

