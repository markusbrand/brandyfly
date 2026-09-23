## Context

The BrandyFly Go backend service (`services/backend`) is a lightweight server written in Go 1.23+ using only the standard library (`net/http`, `crypto/subtle`, `crypto/sha256`, `log/slog`). It operates as an optional daemon for ground-station relay and diagnostic health checks.

Earlier iterations surfaced two critical security considerations:
1. Token comparison vulnerabilities: Direct string comparison (`!=`) leaks timing information. Furthermore, `crypto/subtle.ConstantTimeCompare` leaks the expected token length if inputs differ in byte length.
2. Error response header omission: Setting security headers inside endpoint handlers skips those headers when early returns (such as 401 Unauthorized or 405 Method Not Allowed) occur.

## Goals / Non-Goals

**Goals:**
- Provide zero-external-dependency, standard library HTTP server architecture.
- Prevent timing attacks and token length disclosure through SHA-256 pre-hashing and constant-time comparison.
- Guarantee that all HTTP responses (successful, error, unauthorized) carry baseline security headers via middleware chaining.
- Ensure clean shutdown within a 10-second timeout window.

**Non-Goals:**
- Complex routing frameworks (e.g., Gin, Chi) or heavy authentication middleware (OAuth/OIDC).
- Persistent database storage or user credential storage.

## Decisions

### Decision 1: Standard Library HTTP Middleware Pattern
- **Choice**: Wrap `http.ServeMux` with `SecurityHeadersMiddleware(next http.Handler) http.Handler`.
- **Rationale**: Go 1.22+ `http.ServeMux` provides native method matching (`GET /healthz`). Wrapping the top-level handler ensures every response—including framework-generated 404s and early 401 returns—always receives the security headers.
- **Alternatives Considered**:
  - Setting headers in each handler function: Fragile and fails on early returns.
  - Using third-party middleware packages: Violates the zero-dependency standard library design constraint for minimal ARM64 builds.

### Decision 2: Pre-Hashed Constant-Time Authentication Comparison
- **Choice**: Compute `sha256.Sum256([]byte(expectedAuth))` and `sha256.Sum256([]byte(actualAuth))`, then compare the fixed 32-byte digests using `subtle.ConstantTimeCompare`.
- **Rationale**: `subtle.ConstantTimeCompare` returns 0 immediately if input lengths differ, which an attacker can exploit via timing attacks to determine the exact length of `BRANDYFLY_HEALTH_TOKEN`. Pre-hashing with SHA-256 normalizes all inputs to exactly 32 bytes, guaranteeing constant-time execution regardless of input length.
- **Alternatives Considered**:
  - Direct string comparison (`expected == actual`): Vulnerable to byte-by-byte timing attacks.
  - Unhashed `subtle.ConstantTimeCompare`: Vulnerable to length leakage.

## Risks / Trade-offs

- **[Risk]** Missing token configuration when protection is intended → **Mitigation**: Server defaults to open health checks unless `BRANDYFLY_HEALTH_TOKEN` is explicitly set in the environment, matching standard container health-probe conventions.
- **[Risk]** Slow client connections hanging server shutdown → **Mitigation**: Bounded `context.WithTimeout(context.Background(), 10 * time.Second)` for `httpServer.Shutdown`.
