package proxy

import (
	"net"
	"testing"
	"time"
)

func TestRepeatedFailuresCollapseAndSettle(t *testing.T) {
	var r repeatedFailures
	if log, held := r.note("timeout"); !log || held != 0 {
		t.Fatalf("first: log=%v held=%d", log, held)
	}
	for i := 0; i < 149; i++ {
		if log, _ := r.note("timeout"); log {
			t.Fatalf("repeat %d was logged", i+1)
		}
	}
	if log, held := r.note("connection refused"); !log || held != 149 {
		t.Fatalf("new reason: log=%v held=%d", log, held)
	}
	if _, held := r.settled(); held != 0 {
		t.Fatalf("settled unexpectedly held %d", held)
	}
}

func TestRepeatedFailuresSpeakAgainAfterWindow(t *testing.T) {
	var r repeatedFailures
	r.note("timeout")
	r.note("timeout")
	r.note("timeout")
	r.mu.Lock()
	r.at = time.Now().Add(-repeatWindow - time.Second)
	r.mu.Unlock()
	if log, held := r.note("timeout"); !log || held != 2 {
		t.Fatalf("after window: log=%v held=%d", log, held)
	}
}

func TestRepeatedFailuresSettleOnRecovery(t *testing.T) {
	var r repeatedFailures
	r.note("timeout")
	for i := 0; i < 5; i++ {
		r.note("timeout")
	}
	if reason, held := r.settled(); reason != "timeout" || held != 5 {
		t.Fatalf("settled: %q %d", reason, held)
	}
	if _, held := r.settled(); held != 0 {
		t.Fatalf("settled twice: %d", held)
	}
}

func TestConnectionLimitRefusalsAreCollapsed(t *testing.T) {
	s := NewSOCKSServer(nil, time.Second, time.Second, 1)
	if !s.acquireConnSlot() {
		t.Fatal("first slot must be free")
	}
	for i := 0; i < 150; i++ {
		client, server := net.Pipe()
		_ = client.Close()
		s.handleConn(server)
	}
	s.rejections.mu.Lock()
	held := s.rejections.held
	s.rejections.mu.Unlock()
	if held != 149 {
		t.Fatalf("held %d refusals, want 149", held)
	}
	s.releaseConnSlot()
	client, server := net.Pipe()
	_ = client.Close()
	s.handleConn(server)
	if reason, held := s.rejections.settled(); reason != "" || held != 0 {
		t.Fatalf("accepted client did not settle refusals: %q %d", reason, held)
	}
}
