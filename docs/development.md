# Development

## Prerequisites

- Flutter stable with Dart 3.12 or newer
- Rust stable
- Go 1.25.12 or newer within the Go 1.25 release line
- Node.js 20.19 or newer for OpenSpec
- Docker with BuildKit for backend container validation
- Xcode for iOS builds and the Android SDK for Android builds

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
