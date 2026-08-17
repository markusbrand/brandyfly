# Development

## Prerequisites

- Flutter stable with Dart 3.12 or newer
- Rust stable
- Go 1.25.12 or newer within the Go 1.25 release line
- Node.js 20.19 or newer for OpenSpec
- Docker with BuildKit for backend container validation
- Xcode for iOS builds and the Android SDK for Android builds
- Linux desktop preview needs the Flutter Linux desktop dependencies (clang,
  cmake, ninja, pkg-config, gtk3 development headers)

## Validation

```sh
npx --yes @fission-ai/openspec@latest validate --all --strict

cargo fmt --all --check
cargo clippy --workspace --all-targets -- -D warnings
cargo test --workspace
cd apps/mobile
flutter pub get
flutter analyze
flutter test
flutter build web

cd ../../plugins/brandyfly_native
flutter pub get
flutter analyze
flutter test

cd ../../services/backend
gofmt -w .
go vet ./...
go test ./...

docker build -t brandyfly-backend:dev services/backend
docker run --rm -d --name brandyfly-backend-dev -p 8080:8080 \
  brandyfly-backend:dev
docker exec brandyfly-backend-dev /brandyfly-backend -healthcheck
docker stop brandyfly-backend-dev
```

Do not run formatting commands with unrelated uncommitted changes unless their
scope is constrained to the module being changed.

The OpenSpec validation above checks source-controlled durable specs under
`openspec/specs/`. It does not validate change state, which lives in GitHub
issues (see below).

## OpenSpec change management (GitHub issues)

OpenSpec change state — proposal, requirements, design, tasks, and verification
evidence — is stored in **GitHub issues**, one issue per change, discovered by
the `openspec` label. Durable capability specs stay under `openspec/specs/` and
configuration under `openspec/config.yaml`; neither is change storage.

All issue reads and writes go through the repository-owned adapter, which uses
`gh` and fails explicitly (no local Markdown fallback) when GitHub is
unavailable or access is insufficient. See
[`tools/openspec-issue/CONTRACT.md`](../tools/openspec-issue/CONTRACT.md).

```sh
# Prepare labels and verify write access
tools/openspec-issue/openspec-issue.sh preflight --write
tools/openspec-issue/openspec-issue.sh ensure-labels

# List and inspect changes
tools/openspec-issue/openspec-issue.sh list --state open
tools/openspec-issue/openspec-issue.sh find <change-name>
tools/openspec-issue/openspec-issue.sh get-section <issue> tasks

# Adapter tests (fixture-backed, no network) and the local-storage guard
bash tools/openspec-issue/test/run.sh
tools/openspec-issue/check-local-change-storage.sh
```

The guard `check-local-change-storage.sh` fails if a workflow reintroduces
per-change Markdown storage (a `openspec/changes/` directory is prohibited).

## Local mock flight mode

Run the mobile app with deterministic synthetic flight data and mocked
interfaces on a development laptop:

```sh
cd apps/mobile
flutter run --dart-define=BRANDYFLY_LOCAL_MOCK_FLIGHT_MODE=true
```

Optional defines:

- `BRANDYFLY_LOCAL_MOCK_FIXTURE_VERSION`
- `BRANDYFLY_LOCAL_MOCK_SEED`
- `BRANDYFLY_LOCAL_MOCK_CLOCK_STEP_MS`
- `BRANDYFLY_LOCAL_MOCK_START_ISO8601`
- `BRANDYFLY_LOCAL_MOCK_PROVENANCE`

Mock mode is rejected in release builds.
