package proxy

import (
	"sync"
	"time"
)

// repeatWindow is how long one reason stays collapsed before the log says
// again that it is still going, with a count.
const repeatWindow = 30 * time.Second

// repeatedFailures collapses identical warnings from one outage. The first
// is logged immediately; repeats are counted until the reason changes, the
// window expires, or service recovers.
type repeatedFailures struct {
	mu     sync.Mutex
	reason string
	at     time.Time
	held   int
}

func (r *repeatedFailures) note(reason string) (log bool, held int) {
	now := time.Now()
	r.mu.Lock()
	defer r.mu.Unlock()
	if reason == r.reason && now.Sub(r.at) < repeatWindow {
		r.held++
		return false, 0
	}
	held, r.held = r.held, 0
	r.reason, r.at = reason, now
	return true, held
}

func (r *repeatedFailures) settled() (reason string, held int) {
	r.mu.Lock()
	defer r.mu.Unlock()
	if r.held == 0 && r.reason == "" {
		return "", 0
	}
	reason, held = r.reason, r.held
	r.reason, r.held, r.at = "", 0, time.Time{}
	return reason, held
}
