## Why

BrandyFly currently relies on physical BLE vario hardware (such as SkyDrop 1) or device sensor integrations to drive real-time flight telemetry. This dependency hinders development on desktop emulators, browser environments (Flutter Web and WASM), widget test harnesses, and automated CI pipelines where physical Bluetooth and native barometers are unavailable. Introducing a standardized telemetry source abstraction alongside deterministic IGC replay and synthetic flight maneuver generation allows full-featured development, UI testing, and web demonstrations with zero hardware dependencies.

## What Changes

- **Telemetry Source Abstraction (`ITelemetrySource` / `TelemetrySource`)**: Decouple telemetry ingestion from native BLE and internal hardware sensors across Dart and Rust, creating a unified provider interface for live sensors, synthetic generators, and log replay.
- **Enhanced IGC Replay Engine**: Refactor the in-app replay controller to support playback controls (Play, Pause, Scrub, Speed multiplier cycling: 1x, 2x, 5x, 10x) and stream parsed IGC B-records (time, lat, lon, validity, pressure altitude, GPS altitude) at real-time intervals into `flight_core`.
- **Synthetic Flight Maneuver Generator**: Implement procedural paragliding maneuver generation in `crates/flight_core` producing deterministic telemetry for constant glide, standard 360° thermal circling (+2.5 m/s climb), and sink recovery.
- **Web and Unsupported Platform Fallback**: Enable automatic fallback to demo replay or synthetic telemetry when executing in Flutter Web (`kIsWeb`) or unsupported desktop debug configurations where native hardware bindings are unavailable.

## Capabilities

### New Capabilities
- `telemetry-source-abstraction`: Common lifecycle and stream interface (`ITelemetrySource`) standardizing sensor and telemetry ingestion across hardware BLE, internal sensors, recorded flight files, and synthetic generators.
- `igc-stream-replay`: Time-synchronized streaming of parsed IGC B-records directly into `flight_core` and the UI dashboard with configurable speed controls (1x, 2x, 5x, 10x) and scrub navigation.
- `synthetic-maneuver-generation`: Deterministic generation of realistic paragliding flight phases (steady glide, 360° thermaling climb at 2.5 m/s, sink recovery) for testing and simulation.
- `web-target-fallback`: Automatic detection of unsupported platform runtime environments (`kIsWeb`, non-native desktop debug) with graceful fallback to simulated telemetry.

## Non-Goals

- Replacing production BLE Bluetooth scanning, GATT pairing, and hardware peripheral drivers for real flights.
- High-fidelity atmospheric fluid dynamics or complex turbulent wind shear physics modeling.
- Multi-glider swarm simulation or multi-pilot network synchronization in a single session.

## Impact

- **`apps/mobile`**: Introduces `ITelemetrySource` and concrete adapters (`BleTelemetrySource`, `DeviceSensorTelemetrySource`, `IgcReplayTelemetrySource`, `SyntheticTelemetrySource`), updates `FlightReplayService`, `FlightTrackingService`, and adds web-safe bootstrap fallback in `main.dart`.
- **`crates/flight_core`**: Adds procedural maneuver generation modules and unified ingestion trait feeding `BoundedFlightPipeline`.
- **`plugins/brandyfly_native`**: Provides non-blocking fallbacks and web-compatible declarations.
