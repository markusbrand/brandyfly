## 1. Mode Gating and Runtime Wiring

- [x] 1.1 Add a single `local_mock_flight_mode` startup configuration path shared by Flutter, Rust core, and native adapters
- [x] 1.2 Enforce build-profile gating so mock mode is unavailable in production artifacts
- [x] 1.3 Add runtime guardrails that reject mock-mode activation outside development/test builds
- [x] 1.4 Validate mode gating with automated checks for both dev-enabled and production-blocked startup paths

## 2. Deterministic Replay Engine and Fixtures

- [x] 2.1 Define versioned scenario fixture schema including seed, logical clock step, and provenance metadata
- [x] 2.2 Implement deterministic synthetic telemetry generation and mocked external-response sequencing from fixture inputs
- [x] 2.3 Emit reproducibility metadata and canonical event hashes for every replay run
- [x] 2.4 Validate deterministic replay by asserting identical hashes for identical inputs and traceable diffs for changed inputs

## 3. Mocked Interface Integration Coverage

- [x] 3.1 Implement boundary mock adapters for sensor and external network-dependent interfaces used by end-to-end app flows
- [x] 3.2 Ensure mock mode executes feature workflows offline without live sensors or network routes
- [x] 3.3 Add scenario support for stale data, delayed responses, dropped updates, and hard failures
- [x] 3.4 Validate nominal/offline/stale/failure flows with integration tests that assert expected state transitions and structured errors

## 4. Privacy and Safety Controls

- [x] 4.1 Enforce fixture provenance checks and block startup when required synthetic/anonymized metadata is missing
- [x] 4.2 Add persistent UI/session labeling that marks mock runs as simulated
- [x] 4.3 Ensure exported or logged mock-session outputs carry machine-readable simulated-session markers
- [x] 4.4 Validate privacy/safety controls with tests that fail on missing provenance, missing labels, or unmarked exports

## 5. Tooling, Documentation, and Final Verification

- [x] 5.1 Add developer documentation for running deterministic local mock scenarios on a laptop
- [x] 5.2 Add CI smoke coverage for mock-mode replay determinism and production-exclusion checks
- [x] 5.3 Record baseline scenario fixtures (nominal, offline, stale, failure) for repeatable regression runs
- [x] 5.4 Run OpenSpec strict validation and project tests relevant to mock mode before implementation sign-off
