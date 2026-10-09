# Verification: deploy-backend-to-bosgame-server

| Check | Result |
|---|---|
| Server | `bosgame`, Ubuntu 26.04.1 LTS, x86_64, `192.168.0.152`; Docker 29.1.3, Compose 2.40.3, `curl` present |
| Go (`golang:1.27-alpine` on the server) | `gofmt` clean, `go vet` / `go test` pass; `CGO_ENABLED=0` builds for amd64 and arm64 succeed |
| `ci.yml` | parses; `deploy` targets `[self-hosted, Linux, X64]` |
| Runners after cleanup | only `bosgame-brandyfly` (online, `self-hosted,Linux,X64`); offline `raspberrypi-brandyfly` removed |
| Post-deploy health check snippet (run on the server with `~/brandyfly/deploy/.env`) | `{"status":"ok"}` on port 8090 |
| `/healthz` LAN `192.168.0.152:8090` / tunnel `https://brandyfly.brandstaetter.rocks` | `{"status":"ok"}` / `{"status":"ok"}` |
| Server cleanup | `~/brandyfly-src/deploy/compose.yaml` restored to `latest` (git clean); running container untouched |
| PR `backend-container` job (buildx, `linux/amd64,linux/arm64`) | pass on re-run; build stage runs once on `linux/amd64` (cross-compile), final distroless `nonroot` stage per target |
| `openspec validate --all --strict` | pass |

## Limitations / follow-ups

- No buildx is installed locally or on the server, so the multi-arch Docker build is validated by the PR `backend-container` job. It first failed three times with Docker Hub authentication timeouts / `504` from `auth.docker.io` (before reaching this change's Dockerfile) and passed on the fourth run; such transient Docker Hub failures can also hit `build-and-push` after merge and are fixed by re-running the job.
- The first automatic deploy happens after merge; confirm afterwards that `docker image inspect ghcr.io/markusbrand/brandyfly-backend:latest --format '{{.Architecture}}'` is `amd64` on the server.
- Until merge, a manual `docker compose up` in `~/brandyfly-src/deploy` would pull the old arm64-only `latest`; the running container is unaffected.
- The old Raspberry Pi still has local runner directories (`~/actions-runner`, `~/actions-runner-brandyfly`); its registration is removed, so it cannot pick up jobs.
