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
tools/validate-data-sources.sh
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

## OpenSpec change management

OpenSpec change state — proposal, requirements delta specs, design, tasks, and verification
evidence — is stored in standard OpenSpec Markdown directories under `openspec/changes/<change-name>/`.
Durable capability specs stay under `openspec/specs/` and configuration under `openspec/config.yaml`.

```sh
# List active changes
npx openspec list

# Check status of a change
npx openspec status --change <change-name>

# Validate all specs and active changes
npx openspec validate --all --strict

# Archive a completed change
npx openspec archive <change-name>
```

## Releases and versioning

Releases and changelogs are managed automatically across monorepo packages using [Release Please](https://github.com/googleapis/release-please) via GitHub Actions (`.github/workflows/release-please.yml`).

- Configuration: `release-please-config.json`
- Versions manifest: `.release-please-manifest.json`

When conventional commits (e.g. `feat:`, `fix:`, `feat(mobile):`) are pushed to `main`, Release Please maintains release PRs for affected packages. Merging a release PR automatically tags the release and publishes GitHub Releases.

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
