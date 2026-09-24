package server

import (
	"context"
	"io"
	"log/slog"
	"net"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func TestHealthEndpoint(t *testing.T) {
	t.Setenv("BRANDYFLY_HEALTH_TOKEN", "")
	request := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	response := httptest.NewRecorder()

	NewHandler().ServeHTTP(response, request)

	if response.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", response.Code, http.StatusOK)
	}
	if nosniff := response.Header().Get("X-Content-Type-Options"); nosniff != "nosniff" {
		t.Fatalf("X-Content-Type-Options = %q, want nosniff", nosniff)
	}
	if contentType := response.Header().Get("Content-Type"); contentType != "application/json" {
		t.Fatalf("content type = %q, want application/json", contentType)
	}
	if body := response.Body.String(); body != "{\"status\":\"ok\"}\n" {
		t.Fatalf("body = %q, want health response", body)
	}
}

func TestHealthEndpointAuthorized(t *testing.T) {
	t.Setenv("BRANDYFLY_HEALTH_TOKEN", "secret-token")
	request := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	request.Header.Set("Authorization", "Bearer secret-token")
	response := httptest.NewRecorder()

	NewHandler().ServeHTTP(response, request)

	if response.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", response.Code, http.StatusOK)
	}
}

func TestHealthEndpointUnauthorized(t *testing.T) {
	t.Setenv("BRANDYFLY_HEALTH_TOKEN", "secret-token")
	request := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	response := httptest.NewRecorder()

	NewHandler().ServeHTTP(response, request)

	if response.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want %d", response.Code, http.StatusUnauthorized)
	}
	if nosniff := response.Header().Get("X-Content-Type-Options"); nosniff != "nosniff" {
		t.Fatalf("X-Content-Type-Options = %q, want nosniff", nosniff)
	}
	if xframe := response.Header().Get("X-Frame-Options"); xframe != "DENY" {
		t.Fatalf("X-Frame-Options = %q, want DENY", xframe)
	}
	if csp := response.Header().Get("Content-Security-Policy"); csp != "default-src 'none'" {
		t.Fatalf("Content-Security-Policy = %q, want default-src 'none'", csp)
	}
}

func TestCheckHealthRejectsUnhealthyResponse(t *testing.T) {
	testServer := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, _ *http.Request) {
		response.WriteHeader(http.StatusServiceUnavailable)
	}))
	t.Cleanup(testServer.Close)

	if err := CheckHealth(testServer.URL, time.Second); err == nil {
		t.Fatal("CheckHealth() error = nil, want non-nil")
	}
}

func TestCheckHealthSuccess(t *testing.T) {
	t.Setenv("BRANDYFLY_HEALTH_TOKEN", "")
	testServer := httptest.NewServer(NewHandler())
	t.Cleanup(testServer.Close)

	if err := CheckHealth(testServer.URL+"/healthz", time.Second); err != nil {
		t.Fatalf("CheckHealth() unexpected error = %v", err)
	}
}

func TestCheckHealthSuccessWithToken(t *testing.T) {
	t.Setenv("BRANDYFLY_HEALTH_TOKEN", "secret-token")
	testServer := httptest.NewServer(NewHandler())
	t.Cleanup(testServer.Close)

	if err := CheckHealth(testServer.URL+"/healthz", time.Second); err != nil {
		t.Fatalf("CheckHealth() unexpected error = %v", err)
	}
}

func TestCheckHealthInvalidURL(t *testing.T) {
	err := CheckHealth(":\x7f", time.Second)
	if err == nil {
		t.Fatal("CheckHealth() with invalid URL error = nil, want non-nil")
	}
}

func TestRunSuccessAndShutdown(t *testing.T) {
	t.Setenv("BRANDYFLY_HEALTH_TOKEN", "")

	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("failed to listen: %v", err)
	}
	addr := ln.Addr().String()
	ln.Close()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	errCh := make(chan error, 1)

	go func() {
		errCh <- Run(ctx, logger, addr)
	}()

	url := "http://" + addr + "/healthz"
	var healthErr error
	for i := 0; i < 50; i++ {
		time.Sleep(20 * time.Millisecond)
		healthErr = CheckHealth(url, 100*time.Millisecond)
		if healthErr == nil {
			break
		}
	}
	if healthErr != nil {
		t.Fatalf("server failed to become healthy at %s: %v", url, healthErr)
	}

	cancel()

	select {
	case err := <-errCh:
		if err != nil {
			t.Fatalf("Run() returned error: %v", err)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("Run() timed out waiting for shutdown")
	}
}

func TestRunListenError(t *testing.T) {
	ctx := context.Background()
	logger := slog.New(slog.NewTextHandler(io.Discard, nil))

	err := Run(ctx, logger, "127.0.0.1:-1")
	if err == nil {
		t.Fatal("Run() with invalid address error = nil, want non-nil")
	}
}
