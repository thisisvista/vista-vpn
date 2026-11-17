package proxy

import (
	"context"
	"net"
	"time"

	"github.com/thisisvista/vista-vpn/core/internal/controlplane"
)

// withRenewalTunnel borrows the current usable session for Guardian requests.
// It must not try to rebuild a session: renewal already holds renewMu, and a
// rebuild could wait on that same lock.
func (c *Controller) withRenewalTunnel(ctx context.Context) (context.Context, func()) {
	if !controlplane.UsesDefaultTransport() ||
		!c.hasUsableSessionOtherThan(nil, time.Now()) {
		return ctx, func() {}
	}
	return controlplane.WithRenewalTunnel(ctx, func(ctx context.Context, address string) (net.Conn, error) {
		return openTunnelContext(ctx, renewalSessionOpener{controller: c}, address)
	})
}

type renewalSessionOpener struct{ controller *Controller }

func (o renewalSessionOpener) OpenTunnel(address string) (net.Conn, error) {
	_, session, release, err := o.controller.acquireSession()
	if err != nil {
		return nil, err
	}
	if !isSessionAlive(session) {
		release()
		return nil, errProxySessionUnhealthy
	}
	conn, err := session.OpenTunnel(address)
	if err != nil {
		release()
		return nil, err
	}
	return &managedTunnelConn{Conn: conn, release: release}, nil
}

// openTunnelContext makes cancellation effective even when opening a stream
// is blocked by the upstream implementation.
func openTunnelContext(ctx context.Context, opener renewalSessionOpener, authority string) (net.Conn, error) {
	type result struct {
		conn net.Conn
		err  error
	}
	ch := make(chan result, 1)
	go func() {
		conn, err := opener.OpenTunnel(authority)
		select {
		case ch <- result{conn: conn, err: err}:
		case <-ctx.Done():
			if conn != nil {
				_ = conn.Close()
			}
		}
	}()
	select {
	case r := <-ch:
		return r.conn, r.err
	case <-ctx.Done():
		return nil, ctx.Err()
	}
}
