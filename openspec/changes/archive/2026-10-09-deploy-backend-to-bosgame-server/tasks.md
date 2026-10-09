## 1. Image and pipeline

- [x] 1.1 Build the backend image stage on `$BUILDPLATFORM` and cross-compile for the target; verify `gofmt`, `go vet`, `go test` and `CGO_ENABLED=0` builds for amd64 and arm64 succeed in `golang:1.27-alpine` on the server.
- [x] 1.2 Publish `latest` for `linux/amd64,linux/arm64` in `build-and-push`; verify `ci.yml` parses and the PR `backend-container` job (buildx, both platforms) passes.
- [x] 1.3 Run the `deploy` job on `[self-hosted, Linux, X64]`; verify the only matching runner for this repository is the online `bosgame-brandyfly`.
- [x] 1.4 Add a post-deploy `/healthz` check (30 s) that prints service logs and fails the job on error; verify the step runs `curl` against `127.0.0.1:${BRANDYFLY_HOST_PORT:-8090}` and `curl` exists on the server.

## 2. Documentation and context

- [x] 2.1 Rewrite `deploy/README.md` for the Ubuntu x86_64 server (`192.168.0.152`), runner labels, tunnel route and migration checklist; update `deploy/.env.example` and `openspec/config.yaml`; verify `openspec validate --all --strict` passes.

## 3. Operational cleanup

- [x] 3.1 Remove the offline `raspberrypi-brandyfly` runner registration; verify the runner list only contains `bosgame-brandyfly`.
- [x] 3.2 Remove the local `latest-amd64` override in `~/brandyfly-src/deploy/compose.yaml` on the server without restarting the running container; verify `git status` is clean there and `/healthz` still answers on LAN and via `https://brandyfly.brandstaetter.rocks`.
