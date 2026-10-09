## Context

See proposal.md. Observed on 2026-10-09: runner `bosgame-brandyfly` online with labels `self-hosted,Linux,X64`; runner `raspberrypi-brandyfly` offline (`self-hosted,Linux,ARM64,raspberry-pi`). The Bosgame runs `brandyfly-backend` from a manually built `ghcr.io/markusbrand/brandyfly-backend:latest-amd64` (compose project `deploy` in `~/brandyfly-src/deploy`), `~/brandyfly/deploy/.env` exists, and the Cloudflare tunnel routes `brandyfly.brandstaetter.rocks` to `192.168.0.152:8090`. Neither the developer machine nor the server has buildx.

## Goals / Non-Goals

**Goals:** pushes to `main` deploy again without manual steps; the image runs on the new and the old architecture; a failed deploy is visible.

**Non-Goals:** see proposal.

## Decisions

### 1. Multi-arch `latest` instead of an amd64-only tag
Publish `linux/amd64,linux/arm64` under the single `latest` tag. Docker selects the matching variant per host, so `deploy/compose.yaml` stays unchanged and the Pi remains a fallback.
- *Alternative: separate `latest-amd64` tag.* Rejected: needs compose changes per host and drifts from CI.

### 2. Cross-compile on `$BUILDPLATFORM`
`FROM --platform=$BUILDPLATFORM golang:…` with `GOOS/GOARCH` from `TARGETOS/TARGETARCH` (already present). Go cross-compiles statically (`CGO_ENABLED=0`), avoiding QEMU emulation for arm64, which keeps the multi-arch build time close to a single-arch build.

### 3. Target runners by default labels `self-hosted, Linux, X64`
The default labels exactly describe the server's platform and need no manual label management. Only one online runner of this repository may carry them (documented).
- *Alternative: custom `bosgame` label.* Rejected for now: extra manual step on every runner re-registration; the README migration checklist covers moves.

### 4. Post-deploy health check
After `docker compose up -d`, poll `http://127.0.0.1:${BRANDYFLY_HOST_PORT:-8090}/healthz` for up to 30 s (15 × 2 s); on failure print `docker compose logs --tail 50` and fail the job.

## Risks / Trade-offs

- [Docker Hub outages break the buildx setup (`moby/buildkit`, `docker/dockerfile` frontend)] → transient; rerun the job. Observed during this change (504 from `auth.docker.io`).
- [Another X64 runner registered to this repository could receive deploys] → documented constraint; currently only `bosgame-brandyfly`.
- [Removing the local `latest-amd64` override before the first automatic deploy] → the running container is unaffected; a manual `docker compose up` in `~/brandyfly-src` would pull `latest`, which is arm64-only until this change is merged and published. Documented in the cleanup task.

## Migration Plan

1. Merge → `build-and-push` publishes multi-arch `latest` → `deploy` runs on the Bosgame and replaces the manually started container (same compose project `deploy`).
2. Verify `/healthz` on LAN and via the tunnel; check `docker image inspect … --format '{{.Architecture}}'` is `amd64`.
3. Rollback: revert the PR; the previous container image (`latest-amd64`) remains in the local image cache.
