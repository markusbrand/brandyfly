## Why

The backend moved from the Raspberry Pi (`192.168.0.150`, Debian, arm64) to the Bosgame home server (`192.168.0.152`, Ubuntu Server, x86_64). The CI/CD pipeline still published an **arm64-only** image and pinned the `deploy` job to the `raspberry-pi` self-hosted runner, which is now offline. The next push to `main` would leave the deploy queued forever, and the published image would not run on the new server, which only works today through a manually built `latest-amd64` image.

## What Changes

- Publish the backend production image as **multi-arch** (`linux/amd64` + `linux/arm64`) under `latest`; cross-compile on the build platform instead of emulating arm64.
- Run the `deploy` job on the online Bosgame runner (labels `self-hosted, Linux, X64`) instead of the offline `raspberry-pi` runner.
- Add a post-deploy health check: the `deploy` job fails unless `/healthz` answers on the server after `docker compose up`.
- Document the Ubuntu server setup, the IP `192.168.0.152`, runner labels, the Cloudflare tunnel route (`brandyfly.brandstaetter.rocks` → `192.168.0.152:8090`), and a migration checklist in `deploy/README.md`; update `.env.example` and the project context in `openspec/config.yaml`.
- Operational cleanup: remove the offline `raspberrypi-brandyfly` runner registration and the local `latest-amd64` override on the server.

### Non-Goals

- Changing the backend's application code, API, or ports.
- Moving the map CDN (`cdn.brandyfly.org`, which currently has no DNS record) or changing the mobile app.
- Introducing new deployment tooling (Kubernetes, Watchtower, etc.).

### Safety, Offline, Privacy, Licensing

- **Safety/offline**: flight-critical functions do not depend on the backend; no app behaviour changes.
- **Privacy/security**: no secrets added; the deploy job keeps using `GITHUB_TOKEN` for ghcr.io. The container keeps its hardening (read-only, non-root, dropped capabilities).
- **Licensing**: no new dependencies.

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `continuous-validation`: the production container requirement changes from ARM64-only to multi-arch (amd64 + arm64), and an automated deployment requirement with a post-deploy health check is added.

## Impact

- `.github/workflows/ci.yml` (`build-and-push` platforms, `deploy` runner labels and health check)
- `services/backend/Dockerfile` (build stage on `$BUILDPLATFORM`)
- `deploy/README.md`, `deploy/.env.example`, `openspec/config.yaml`
- GitHub runner registrations; `~/brandyfly-src` checkout on the Bosgame server
