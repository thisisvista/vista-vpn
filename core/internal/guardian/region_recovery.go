package guardian

import (
	"context"
	"errors"
	"net/http"
	"strings"
	"sync"

	"github.com/thisisvista/vista-vpn/core/internal/controlplane"
)

var regionRecovery struct {
	sync.RWMutex
	retry func(*http.Request) (*http.Response, error)
}

// SetRegionRecovery supplies optional recovery after Guardian HTTP 451 or a
// safe-method transport failure. It does not replace the shared control-plane
// transport or its TLS profile. A nil response or failed retry preserves the
// original response or error.
func SetRegionRecovery(retry func(*http.Request) (*http.Response, error)) {
	regionRecovery.Lock()
	regionRecovery.retry = retry
	regionRecovery.Unlock()
}

func do(req *http.Request) (*http.Response, error) {
	resp, err := controlplane.Do(req)
	if err != nil {
		// An explicit cancellation belongs to the caller and must never be
		// bypassed. A transport failure is retried only for safe, read-only
		// Guardian methods: POST /activate may have succeeded remotely even
		// when its response was lost, so replaying it could duplicate effects.
		if errors.Is(err, context.Canceled) || errors.Is(req.Context().Err(), context.Canceled) {
			return resp, err
		}
		if req.Method != http.MethodGet && req.Method != http.MethodHead {
			return resp, err
		}
		if retry := regionRecoveryRetry(); retry != nil {
			recoveryReq := req
			if errors.Is(req.Context().Err(), context.DeadlineExceeded) {
				// The recovery callback owns a separate, bounded timeout.
				recoveryReq = req.Clone(context.WithoutCancel(req.Context()))
			}
			if recovered, retryErr := retry(recoveryReq); retryErr == nil && recovered != nil {
				return recovered, nil
			}
		}
		return resp, err
	}
	if resp == nil || resp.StatusCode != http.StatusUnavailableForLegalReasons {
		return resp, nil
	}

	// Mozilla's CDN edge refuses the region for the literal Guardian path
	// before the request reaches Guardian. A doubled leading slash does not
	// match that edge rule, while the origin still routes it to the same
	// handler. Try that direct route first, so no relay is needed, and fall
	// back to the configured recovery only if it is still refused.
	if direct, ok := doubledPathRequest(req); ok {
		doubled, doubledErr := controlplane.Do(direct)
		if doubledErr == nil && doubled != nil {
			if doubled.StatusCode != http.StatusUnavailableForLegalReasons {
				resp.Body.Close()
				return doubled, nil
			}
			doubled.Body.Close()
		}
	}

	if retry := regionRecoveryRetry(); retry != nil && req.Context().Err() == nil {
		if recovered, retryErr := retry(req); retryErr == nil && recovered != nil {
			resp.Body.Close()
			return recovered, nil
		}
	}
	return resp, nil
}

func regionRecoveryRetry() func(*http.Request) (*http.Response, error) {
	regionRecovery.RLock()
	defer regionRecovery.RUnlock()
	return regionRecovery.retry
}

// doubledPathRequest clones req with one more leading slash on its path. It
// returns false when the path is already doubled or the body cannot be
// replayed.
func doubledPathRequest(req *http.Request) (*http.Request, bool) {
	if req.URL == nil || !strings.HasPrefix(req.URL.Path, "/") || strings.HasPrefix(req.URL.Path, "//") {
		return nil, false
	}
	if req.Body != nil && req.GetBody == nil {
		return nil, false
	}
	out := req.Clone(req.Context())
	u := *req.URL
	u.Path = "/" + u.Path
	u.RawPath = ""
	out.URL = &u
	if req.GetBody != nil {
		body, err := req.GetBody()
		if err != nil {
			return nil, false
		}
		out.Body = body
	}
	return out, true
}
