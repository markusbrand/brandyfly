## Why

The BrandyFly Go backend service provides a lightweight HTTP daemon intended for ground stations, telemetry relays, and self-hosted server deployments (such as Raspberry Pi ARM64). To ensure operational readiness and defense against automated attacks, the backend requires a robust health check mechanism, timing-attack-resilient token authorization, and standardized HTTP security headers applied across all responses.

This change brings the previously implemented backend HTTP server, health check endpoint, timing attack prevention, and global security headers middleware into the official OpenSpec specification workflow.

## What Changes

- **Health Endpoint (`GET /healthz`)**:
  - Exposes an HTTP health check returning `{"status":"ok"}`.
  - Supports optional Bearer token authentication via `BRANDYFLY_HEALTH_TOKEN`.
  - Hardens authentication verification against timing attacks and length leakage using SHA-256 pre-hashing and constant-time byte comparison (`crypto/subtle.ConstantTimeCompare`).
- **Global Security Headers Middleware (`SecurityHeadersMiddleware`)**:
  - Enforces defense-in-depth HTTP response headers globally across all routes and error responses:
    - `X-Content-Type-Options: nosniff`
    - `X-Frame-Options: DENY`
    - `Content-Security-Policy: default-src 'none'`
- **Graceful Lifecycle Management**:
  - Implements bounded context shutdown with timeout handling to prevent connection drops during service restarts.
- **Client Health Prober**:
  - Provides a reusable `CheckHealth` client function with timeout and authorization token header injection.

## Capabilities

### New Capabilities

- `backend-health-and-security`: HTTP server lifecycle, health check endpoint, timing-attack-safe authentication, and global security headers middleware for the BrandyFly Go backend.

### Modified Capabilities

None.

## Non-Goals

- User account management or multi-tenant authentication.
- Flight log sync or telemetry ingestion APIs (tracked under future backend integration specs).
- Public cloud infrastructure deployment or Kubernetes orchestration.

## Impact

- **Affected Code**: `services/backend/internal/server/server.go`, `services/backend/internal/server/server_test.go`, `services/backend/cmd/server/main.go`.
- **Safety & Security**: Hardens the backend against timing attacks, MIME confusion, and clickjacking.
- **Offline Impact**: Client mobile apps remain local-first; backend health checks are decoupled from core flight operations.
- **Licensing**: Fully MIT-compliant standard Go library code.
