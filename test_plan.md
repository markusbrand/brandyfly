1. **Add `SecurityHeadersMiddleware` to `server.go`**
   - Create `SecurityHeadersMiddleware` in `services/backend/internal/server/server.go` to set security headers globally.
   - Wrap the `mux` with `SecurityHeadersMiddleware(mux)` in `NewHandler()`.
   - Remove the manual setting of security headers from the `/healthz` handler so it doesn't duplicate them, and ensure error responses (e.g., Unauthorized) also receive these headers.
2. **Run tests**
   - Run tests in `services/backend` via `cd services/backend && go test ./...`.
3. **Complete pre-commit steps**
   - Complete pre-commit steps to ensure proper testing, verification, review, and reflection are done.
4. **Submit PR**
   - Submit the PR with the required PR title and description for Sentinel.
