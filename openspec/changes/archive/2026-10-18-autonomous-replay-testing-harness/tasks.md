# Tasks

## 1. Scenario Catalog & Telemetry Drivers

- [x] 1.1 Implement declarative `ReplayScenario`, `ReplayMilestone`, and scenario catalog (`steady_glide`, `thermal_climb`, `heavy_sink`, `airspace_alert`, `sensor_dropouts`, `boundary_extremes`) in `apps/mobile/test/harness/scenario_catalog.dart` and verify unit tests validate scenario duration, telemetry bounds, and milestone definitions with `flutter test test/harness/scenario_catalog_test.dart`.
- [x] 1.2 Implement mock telemetry and state feed utilities (`HarnessTelemetryDriver`) that step through scenarios at simulated clock intervals and verify state transitions via unit tests with `flutter test test/harness/telemetry_driver_test.dart`.

## 2. Invariant Assertion Engine & Report Generation

- [x] 2.1 Implement `LayoutInvariantChecker` with custom `FlutterError.onError` interceptor to capture `RenderFlex` overflows, text clipping bounds, and NaN/infinity geometry errors without crashing tests, verifying detection with `flutter test test/harness/invariant_checker_test.dart`.
- [x] 2.2 Implement `ReplayReportGenerator` producing structured `build/harness/replay_report.json` with execution metadata, canvas dimensions, pass/fail status, and milestone screenshot references, verifying JSON schema conformance with `flutter test test/harness/report_generator_test.dart`.

## 3. Autonomous Replay Harness Integration & Multi-Canvas Runner

- [x] 3.1 Implement `AutonomousReplayHarness` runner capable of testing cockpit screens (`LayoutCanvas`, default cockpit configurations) across target canvas matrix (`phone_portrait`, `phone_landscape`, `tablet_landscape`) with font loading support, verifying execution with `flutter test test/harness/autonomous_replay_harness_test.dart`.
- [x] 3.2 Add milestone screenshot capture (opt-in via `SCREENSHOTS=1`) writing keyframe PNGs to `build/harness/screenshots/` and verify artifact generation with `SCREENSHOTS=1 flutter test test/harness/autonomous_replay_harness_test.dart`.
- [x] 3.3 Validate overall test suite execution time (< 5 seconds) and verify strict OpenSpec validation passes with `npx openspec validate --all --strict`.

## Workflow follow-up

- Archive the change after the project's review requirements are satisfied.
- Commit, push, and open a Pull Request targeting main.
