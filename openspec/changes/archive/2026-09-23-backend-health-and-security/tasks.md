## 1. HTTP Server & Health Check Implementation

- [x] 1.1 Implement `GET /healthz` endpoint returning `{"status":"ok"}` in `services/backend/internal/server/server.go` and verify with unit tests in `server_test.go`.
- [x] 1.2 Implement bearer token authentication using environment variable `BRANDYFLY_HEALTH_TOKEN` in `services/backend/internal/server/server.go`.

## 2. Security Hardening & Middleware

- [x] 2.1 Protect authentication token checks against timing attacks and length leakage using SHA-256 pre-hashing and `crypto/subtle.ConstantTimeCompare`.
- [x] 2.2 Implement `SecurityHeadersMiddleware` setting `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, and `Content-Security-Policy: default-src 'none'`.
- [x] 2.3 Wrap all routes and error returns in `SecurityHeadersMiddleware` ensuring headers are present on 401 Unauthorized responses, verified via `TestSecurityHeadersOnUnauthorized`.

## 3. Lifecycle & Client Prober

- [x] 3.1 Implement bounded graceful shutdown with context cancellation and 10-second timeout in `Run()`.
- [x] 3.2 Implement `CheckHealth` client function with timeout and Authorization header support, verified via `TestCheckHealth`.

## 4. Verification

- [x] 4.1 Run all backend unit tests via `go test ./...` in `services/backend` and verify all tests pass.
- [x] 4.2 Run OpenSpec validation with `openspec validate --all --strict`.
