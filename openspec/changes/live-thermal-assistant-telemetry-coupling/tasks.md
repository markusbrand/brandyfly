## 1. Rust reference orchestrator

- [x] 1.1 Add `crates/flight_core/src/thermal_assistant.rs` composing circling detector, wind estimator, and core calculator with stale/invalid skipping, > 5 s gap interruption (keep last wind), reset of core buffer + track window on CIRCLING → GLIDING, and output on every GPS sample; export from `lib.rs`. Verify with new unit tests for each rule passing in `cargo test -p flight_core`.
- [x] 1.2 Refactor `BoundedFlightPipeline` to delegate thermal processing to `ThermalAssistant` (no baro dependency for snapshots). Verify existing pipeline/benchmark tests still pass and a new test asserts a GPS-only stream yields a thermal snapshot and that the core buffer resets on glide.
- [x] 1.3 Verify `cargo fmt --all --check`, `cargo clippy --workspace --all-targets -- -D warnings`, and `cargo test --workspace` pass.

## 2. Golden parity fixtures

- [x] 2.1 Add `crates/flight_core/src/bin/thermal_fixtures.rs` generating deterministic scenarios (no-wind thermal, 10 m/s drift thermal, straight glide, erratic reversals, 8 s gap, stale-flagged samples) and writing `packages/contracts/fixtures/thermal_assistant/*.json` with fixed-precision formatting. Verify by running `cargo run -p flight_core --bin thermal_fixtures` twice and confirming `git diff` is empty after the second run.
- [x] 2.2 Add a Rust test that regenerates fixtures in memory and asserts byte equality with the checked-in files. Verify it fails when a fixture file is edited and passes when restored.
- [x] 2.3 Document fixture regeneration in `docs/development.md` and verify the documented command reproduces the files.

## 3. Dart thermal assistant engine

- [x] 3.1 Create `apps/mobile/lib/domain/thermal_assistant/` (heading tracker, circling detector, wind estimator, core calculator, engine, immutable state types incl. `WindEstimate` with age/stale at 15 min, `CoreOffset`, bounded track window ≤ min(historySeconds, 300 s)) as pure Dart. Verify with unit tests mirroring the Rust unit tests (right/left entry, noise rejection, glide exit, wind 270°/36 km/h, core centroid, sink-only fallback).
- [x] 3.2 Add `test/domain/thermal_assistant_parity_test.dart` loading every fixture from `packages/contracts/fixtures/thermal_assistant/` and asserting exact mode/turn transitions and wind (0.5 km/h, 2°) / core (2 m) tolerances. Verify it passes and fails when a tolerance-breaking change is introduced locally.
- [x] 3.3 Add a benchmark test processing a 1 h, 10 Hz synthetic flight asserting mean < 1 ms/sample and bounded retained sample counts. Verify it passes under `flutter test`.

## 4. Telemetry coupling and honest wind

- [x] 4.1 Extend `CockpitTelemetry` with `ThermalAssistantState? thermal` (with `revision`) and make `windDir`/`windSpeed` nullable derived from the estimate; update `fromMap`/`copyWith` and all call sites. Verify `flutter analyze` is clean and model tests pass.
- [x] 4.2 Remove fabricated wind from `SyntheticTelemetrySource`, `TelemetrySnapshot.fromFlightPoint`/`toTelemetryMap`, `FlightReplayService.currentTelemetry`, and `TelemetryRepository.onSnapshot`. Verify with a grep test/assertion that no `heading + 180` wind derivation remains and repository tests show `wind == null` before two turns.
- [x] 4.3 Run the engine in `TelemetryRepository` for live snapshots (skip stale/invalid, gap handling via engine) and publish `thermal` on each emission. Verify with repository tests: circling flag set after 270°, wind present after 2 turns, GPS dropout > 5 s falls back to gliding and retains wind.
- [x] 4.4 Add engine deep-copy support and a `ReplayThermalTracker` that feeds replay points `(lastFed, current]` in order, checkpoints every 60 s of flight time, and restores the latest checkpoint on backward seeks; wire it into `TelemetryRepository`. Verify with tests that two full replays produce identical state sequences, that random forward/backward seeks yield exactly the continuous-replay state, and that a backward seek reprocesses ≤ 60 s of points.
- [x] 4.5 Verify `test/perf/rebuild_budget_test.dart` and `test/hag_telemetry_integration_test.dart` still pass with the new fields.

## 5. Synthetic wind drift

- [x] 5.1 Add `windFromDeg`/`windSpeedKmh` (default 0) to `SyntheticTelemetrySource`, applying wind to ground track and reporting ground speed. Verify with a test that 20 km/h from 270° drifts the track east at ≈ 5.6 m/s and the engine estimates wind within ±10°/±4 km/h after 2 turns.
- [x] 5.2 Add wind speed/direction controls to the simulation overlay. Verify with a widget test that changing the controls updates the source's wind parameters.

## 6. Cockpit UI

- [x] 6.1 Update `widget_slot.dart` thermal map case to pass track heading, engine track window, core offset, nullable wind, and `preview` (true only when no live/replay source); select on `thermal.revision`. Verify with a widget test that heading ≠ wind direction is rendered correctly.
- [x] 6.2 Update `ThermalMapWidget` to render live points/core/wind, render nothing while gliding with an empty window, and show the demo spiral only with a visible "preview" label. Verify with widget tests for the three spec scenarios.
- [x] 6.3 Update the wind direction widget (all styles) to show explicit "no estimate" and a visually distinct stale state. Verify with widget tests for null, valid, and stale (> 15 min) wind, and run `test/layout/overflow_sweep_test.dart`.

## 7. Screen auto-switching

- [x] 7.1 Add `automatic` flag to `ScreenManagerService.setActiveScreen` and implement `ScreenAutoSwitchController` (injectable clock) with circling entry switch, glide exit (glide-straight screen or previous screen), 60 s manual-override suppression, 10 s rate limit, and edit-mode suppression; wire it in `main.dart`. Verify with unit tests for each scenario in the `screen-widget-configuration` delta.
- [x] 7.2 Verify existing `test/screen_manager_test.dart` passes unchanged in behavior for manual switching and screen removal.

## 8. End-to-end validation

- [x] 8.1 Add a mock-flight integration test: synthetic source with 15 km/h wind flies glide → thermal → glide; assert auto-switch to the thermaling screen, live bubbles and core marker rendered, wind shown after 2 turns, and switch back on glide. Verify it passes under `flutter test`.
- [ ] 8.2 Manually run the app on Linux desktop and the Android emulator (`brandyfly_test_device`, host GPU) in mock flight mode with wind; record screenshots of the thermal map and wind widget as verification evidence.
- [x] 8.3 Run `cd apps/mobile && flutter analyze && flutter test`, `cargo test --workspace`, and `npx openspec validate --all --strict`; all must pass.
