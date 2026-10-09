## Why

The thermal assistant algorithms (circling detection, multi-turn wind drift estimation, lift-weighted thermal core) exist and are tested in `crates/flight_core`, but no running app build executes them: the Rust core is not packaged into the mobile app, `TelemetrySnapshot.isCircling`/`thermalCoreLat/Lon` are never populated, and `ThermalMapWidget` always draws a hard-coded demo spiral. Worse, the cockpit currently displays **fabricated wind** (`heading + 180°`, `12 km/h`) from the synthetic source, replay service, and telemetry repository, and the thermal widget receives wind direction as its heading. Pilots thermaling with BrandyFly today see plausible-looking but fake centering and wind information — a safety and trust problem that must be fixed before the thermal assistant can be relied on in flight.

## What Changes

- **Dart thermal assistant engine** (`apps/mobile/lib/domain/thermal_assistant/`): pure, deterministic Dart port of `CirclingStateDetector`, `WindEstimator`, and `ThermalCoreCalculator`, orchestrated by a `ThermalAssistantEngine` that consumes `TelemetrySnapshot`s and emits an immutable `ThermalAssistantState` (flight mode, turn direction, wind estimate + validity/age, core offset, bounded circling track window). Rust remains the reference implementation.
- **Cross-runtime parity fixtures**: a `flight_core` binary emits golden JSON replay fixtures (input track + expected per-sample states); Dart tests assert parity within tolerances so the two implementations cannot silently diverge.
- **Rust spec alignment fix**: `BoundedFlightPipeline` resets the thermal core buffer on `CIRCLING → GLIDING` (already required by the existing spec, currently not done) and computes thermal snapshots on GPS-only input.
- **Telemetry coupling**: `TelemetryRepository` runs the engine on every live and replay tick and publishes `CockpitTelemetry` with real `isCircling`, wind estimate (or explicit "no estimate"), core offset, and the circling track window. Replay recomputes state deterministically from recorded points.
- **Honest wind**: **BREAKING (display behavior)** — the fabricated `heading + 180° / 12 km/h` wind is removed from all sources; wind widgets show an explicit "no estimate" / stale state until the engine produces a valid estimate.
- **Live thermal map**: `ThermalMapWidget` renders engine-provided track points, core marker, and wind arrow; the built-in demo spiral is used only in edit-mode/preview with no live data. Fixes heading/wind argument mix-up in `widget_slot.dart`.
- **Screen auto-switching**: screens with `onThermalCircling` / `onGlideStraight` triggers become active automatically on mode transitions, with dwell hysteresis and manual-override cooldown.
- **Synthetic wind drift**: `SyntheticTelemetrySource` applies a configurable wind vector to ground track so mock/simulated thermals drift and exercise wind estimation end-to-end.

### Non-Goals

- Packaging `flight_core` as a native library (FFI / native assets) into the app — a separate future change.
- Persisting wind/core/circling state into IGC, JSON, or CSV flight logs (replay recomputes from track points).
- New thermal map visual styles or redesign of existing presets.
- Using external wind sources (forecast APIs, airspeed sensors, BLE wind data).
- Audio cues for thermal core direction ("core is left/right").

### Safety, Offline, Privacy, Licensing

- **Safety**: removes fabricated wind values; all derived values carry validity and age, and stale/absent data is shown explicitly rather than with placeholders. Thermal assistant output is advisory only.
- **Offline**: computation is fully on-device with no network dependency.
- **Privacy**: no new data collection or transmission; derived state is in-memory only.
- **Licensing**: no new dependencies or datasets.

## Capabilities

### New Capabilities
- `live-thermal-assistant`: on-device runtime engine coupling live/replay telemetry to circling detection, wind estimation, and thermal core calculation; cross-runtime parity with the Rust reference; honest wind publication; live thermal map data feed; stale-data and interruption behavior.

### Modified Capabilities
- `screen-widget-configuration`: the "Screen-Level Layout Strategy and Management" auto-switching scenario is tightened to define circling entry/exit triggers, dwell hysteresis, and manual-override behavior.

## Impact

- **Rust**: `crates/flight_core/src/bounded_pipeline.rs` (reset/GPS-only snapshot fix), new fixture generator bin in `crates/flight_core/src/bin/`, golden fixtures under `packages/contracts/fixtures/thermal_assistant/`.
- **Dart domain**: new `apps/mobile/lib/domain/thermal_assistant/` module.
- **Dart data/services**: `data/repositories/telemetry_repository.dart`, `domain/models/cockpit_telemetry.dart`, `services/telemetry/telemetry_types.dart`, `services/telemetry/synthetic_telemetry_source.dart`, `services/flight_replay_service.dart`, `services/screen_manager_service.dart` (or a new auto-switch controller).
- **UI**: `ui/features/flight_canvas/views/widget_slot.dart`, `ui/features/instruments/views/thermal_map_widget.dart`, wind direction widget.
- **Tests**: new domain unit/parity tests, repository integration tests, widget tests, and a mock-flight end-to-end test.
