package server

import (
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
	if deny := response.Header().Get("X-Frame-Options"); deny != "DENY" {
		t.Fatalf("X-Frame-Options = %q, want DENY", deny)
	}
	if csp := response.Header().Get("Content-Security-Policy"); csp != "default-src 'none'" {
		t.Fatalf("Content-Security-Policy = %q, want default-src 'none'", csp)
	}
}

func TestNotFoundHasSecurityHeaders(t *testing.T) {
	request := httptest.NewRequest(http.MethodGet, "/doesnotexist", nil)
	response := httptest.NewRecorder()

	NewHandler().ServeHTTP(response, request)

	if response.Code != http.StatusNotFound {
		t.Fatalf("status = %d, want %d", response.Code, http.StatusNotFound)
	}
	if nosniff := response.Header().Get("X-Content-Type-Options"); nosniff != "nosniff" {
		t.Fatalf("X-Content-Type-Options = %q, want nosniff", nosniff)
	}
	if deny := response.Header().Get("X-Frame-Options"); deny != "DENY" {
		t.Fatalf("X-Frame-Options = %q, want DENY", deny)
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
