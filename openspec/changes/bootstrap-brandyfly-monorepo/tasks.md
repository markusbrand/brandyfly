## 1. Repository and governance

- [x] 1.1 Add root licensing, contribution, security, architecture, and development documentation
- [x] 1.2 Add shared ignore, editor, formatting, and dependency-update configuration
- [x] 1.3 Validate the complete OpenSpec change in strict mode

## 2. Source modules

- [x] 2.1 Generate the Android/iOS Flutter application and add a smoke test
- [x] 2.2 Generate the Android/iOS native Flutter plugin and add a contract smoke test
- [x] 2.3 Create the Rust flight-core crate with formatting, lint, and unit tests
- [x] 2.4 Create the Go backend health service with timeouts and unit tests
- [x] 2.5 Create map-pipeline and shared-contract boundaries without speculative product logic

## 3. Container baseline

- [x] 3.1 Add a multi-stage non-root backend Dockerfile and minimal build context
- [x] 3.2 Add a production Compose definition with read-only runtime, resource limits, health check, and persistent data volume
- [x] 3.3 Build and inspect the production container locally

## 4. Continuous validation

- [x] 4.1 Add OpenSpec, Flutter, Rust, Go, and backend-container CI jobs
- [x] 4.2 Add dependency update and secret-free automation configuration
- [x] 4.3 Run all available targeted checks and record any host-only validation limits

## 5. Publication

- [ ] 5.1 Create the public `markusbrand/brandyfly` GitHub repository and push the validated bootstrap
- [ ] 5.2 Confirm repository visibility, MIT license detection, and initial GitHub Actions status

## Verification evidence

- OpenSpec strict validation passed for all current artifacts.
- Rust formatting, Clippy with warnings denied, unit tests, and doc tests passed.
- Flutter analysis and tests passed for the app and native plugin.
- An Android debug APK including the native plugin built successfully.
- Go formatting, vet, and tests passed.
- The backend image built at 3.5 MB, ran as `nonroot:nonroot`, and passed both
  HTTP and embedded health checks.
- Compose ran with a read-only root filesystem, all capabilities dropped,
  256 MB memory and 0.5 CPU limits, and reached healthy status.
- The Linux host cannot execute the iOS build, and its Docker installation lacks
  Buildx for a local ARM64 image; dedicated GitHub Actions jobs cover both gates.
