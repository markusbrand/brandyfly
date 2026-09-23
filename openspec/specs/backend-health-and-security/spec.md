# backend-health-and-security Specification

## Purpose
Provides a lightweight, hardened HTTP backend service exposing operational health checks, constant-time authorization verification, and global security headers for ground stations and self-hosted BrandyFly nodes.

## Requirements

### Requirement: HTTP Health Check Endpoint
The backend HTTP server SHALL expose a `GET /healthz` endpoint returning HTTP 200 OK with `{"status":"ok"}` when the daemon is running and operational.

#### Scenario: Successful unauthenticated health probe
- **WHEN** an HTTP client sends a `GET /healthz` request
- **AND** no `BRANDYFLY_HEALTH_TOKEN` is configured on the server
- **THEN** the server SHALL respond with HTTP status 200 OK
- **AND** Content-Type `application/json` with body `{"status":"ok"}`.

### Requirement: Timing-Attack-Resilient Token Authorization
When the `BRANDYFLY_HEALTH_TOKEN` environment variable is non-empty, the backend SHALL require a matching `Authorization: Bearer <token>` header, verified using constant-time comparison to prevent timing and length leakage attacks.

#### Scenario: Authorized health probe with matching token
- **WHEN** `BRANDYFLY_HEALTH_TOKEN` is set
- **AND** the client sends a `GET /healthz` request with `Authorization: Bearer <valid_token>`
- **THEN** the server SHALL authenticate the request and return HTTP status 200 OK.

#### Scenario: Unauthorized probe without token
- **WHEN** `BRANDYFLY_HEALTH_TOKEN` is set
- **AND** the client sends a `GET /healthz` request without an `Authorization` header
- **THEN** the server SHALL reject the request with HTTP status 401 Unauthorized.

#### Scenario: Unauthorized probe with invalid or mismatched token length
- **WHEN** `BRANDYFLY_HEALTH_TOKEN` is set
- **AND** the client sends a `GET /healthz` request with an incorrect token
- **THEN** the server SHALL pre-hash both expected and received tokens with SHA-256 before constant-time comparison
- **AND** respond with HTTP status 401 Unauthorized without leaking token length or timing discrepancies.

### Requirement: Global Security Headers Enforcement
The backend SHALL enforce standard HTTP defense-in-depth security headers across all responses, including errors and unauthorized responses, via global HTTP middleware.

#### Scenario: Security headers present on success responses
- **WHEN** any HTTP request completes successfully (HTTP 200)
- **THEN** the response headers SHALL include `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, and `Content-Security-Policy: default-src 'none'`.

#### Scenario: Security headers present on error and unauthorized responses
- **WHEN** an HTTP request fails or is rejected with HTTP 401 Unauthorized or HTTP 404 Not Found
- **THEN** the response headers SHALL still include `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, and `Content-Security-Policy: default-src 'none'`.

### Requirement: Bounded Graceful Shutdown
The backend server SHALL implement graceful shutdown upon OS interrupt or context cancellation, draining active connections within a bounded timeout.

#### Scenario: Server shutdown signal
- **WHEN** the server execution context is cancelled
- **THEN** the HTTP listener SHALL stop accepting new connections
- **AND** wait up to 10 seconds for active requests to finish before terminating cleanly.
