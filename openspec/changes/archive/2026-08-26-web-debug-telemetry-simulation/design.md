## Context

BrandyFly's vario dashboard and flight instruments require telemetry streams (barometer pressure, altitude, GPS fixes, vario vertical speed). Currently, telemetry input is tightly coupled to native Android/iOS/Linux plugins or static mock models. To enable running the app in Flutter Web (WASM/JS), emulators, automated integration tests, and UI preview environments, telemetry acquisition must be decoupled into modular providers.

## Goals & Non-Goals

### Goals
- Introduce a clean `ITelemetrySource` interface in Dart and a corresponding `TelemetrySource` trait in Rust.
- Implement an in-app IGC replayer with Play, Pause, Seek/Scrub, and speed multiplier cycling (1x, 2x, 5x, 10x).
- Stream parsed IGC B-records with time pacing directly into `flight_core` bounded pipelines.
- Implement deterministic synthetic maneuvers in `crates/flight_core` (steady glide, 360° thermaling circle with 2.5 m/s climb, sink recovery).
- Provide automatic graceful fallback for Flutter Web (`kIsWeb`) and desktop environments where native plugins are absent.

### Non-Goals
- Real BLE hardware connection implementation over Web Bluetooth.
- Full aerodynamic multi-body physical flight simulators.

## Architectural Decisions

### Decision 1: Unified `ITelemetrySource` Interface
We define an abstract interface in Dart:
```dart
abstract class ITelemetrySource {
  Stream<TelemetrySnapshot> get telemetryStream;
  Stream<SensorEvent> get rawSensorStream;
  Future<void> initialize();
  Future<void> start();
  Future<void> pause();
  Future<void> stop();
  bool get isRunning;
  TelemetrySourceType get sourceType;
}
```
Concrete implementations include:
- `BleTelemetrySource`: Wraps physical BLE hardware connections.
- `InternalSensorTelemetrySource`: Wraps onboard device IMU/barometers.
- `IgcReplayTelemetrySource`: Streams parsed IGC flight recordings.
- `SyntheticTelemetrySource`: Streams procedurally generated paragliding flight patterns.

### Decision 2: Rust `TelemetrySource` Trait and Procedural Generator
In `crates/flight_core`, define:
- `pub trait TelemetrySource { fn next_event(&mut self, timestamp_ns: u64) -> Option<SensorEvent>; }`
- `ProceduralFlightGenerator`: Generates realistic kinematics:
  - Constant glide: linear progression along fixed heading with glide ratio (~8:1) and sink rate (-1.2 m/s).
  - 360° thermal turn: circular path with bank angle, radius ~30-50m, vertical lift +2.5 m/s, barometric pressure updating via barometric formula.
  - Sink recovery: rapid altitude drop (-3.5 m/s) transitioning back to trim glide.

### Decision 3: IGC Replay Engine & Speed Multipliers
The replay controller parses IGC records into `FlightPoint` sequences and emits timestamped sensor frames. The speed multiplier supports `[1, 2, 5, 10]`, cycling on user tap. A periodic timer or logical clock dispatcher advances the stream index at `interval = base_interval / speed_multiplier`.

### Decision 4: Web and Desktop Fallback via Bootstrap Capability Detection
In `apps/mobile/lib/main.dart`:
- Check `kIsWeb` or probe `brandyfly_native` availability.
- If native bindings are unavailable, avoid calling unsupported platform channels.
- Automatically wire `SyntheticTelemetrySource` or bundled sample flight replay (`Krippenstein-Aussee`).

## Risks & Trade-offs

- **Timer drift at high multipliers (10x)**: High-speed playback at 10x with 50Hz sensor data would require 500 events/second. To avoid UI thread congestion on web, the replayer aggregates intermediate points or steps logical frames predictably.
- **Cross-platform time synchronization**: Replay uses relative time deltas from the initial record rather than absolute system time, guaranteeing consistent pacing across platforms.

## Migration Plan

1. Define contracts and interfaces in Dart and Rust without breaking existing mock flight mode.
2. Refactor existing `FlightReplayService` and `FlightTrackingService` to consume `ITelemetrySource`.
3. Add procedural generators to `flight_core` and export bindings.
4. Update `main.dart` with environment-aware bootstrap fallback.
