## 1. Telemetry Provider Abstraction
- [x] 1.1 Define the `ITelemetrySource` abstract interface and event data types in Dart (`apps/mobile/lib/services/telemetry/`)
- [x] 1.2 Implement the `TelemetrySource` trait and stream consumer in `crates/flight_core`
- [x] 1.3 Refactor `FlightTrackingService` to accept pluggable telemetry providers
- [x] 1.4 Add unit tests for telemetry provider lifecycle and switching

## 2. Procedural Synthetic Flight Maneuver Generator
- [x] 2.1 Implement `ProceduralFlightGenerator` in `crates/flight_core` with constant glide, 360-degree thermal turn (+2.5 m/s climb), and sink recovery
- [x] 2.2 Add unit and determinism tests for procedural flight patterns in Rust
- [x] 2.3 Implement `SyntheticTelemetrySource` in Dart wrapping the procedural generation patterns
- [x] 2.4 Add widget tests validating UI updates against synthetic telemetry streams

## 3. Enhanced IGC Replayer & Stream Injection
- [x] 3.1 Enhance `IGCParserService` to extract detailed B-records (validity, pressure alt, GPS alt, timestamp) for stream injection
- [x] 3.2 Update `FlightReplayService` and Replay HUD with 1x, 2x, 5x, 10x speed multiplier cycling and scrub navigation
- [x] 3.3 Implement `IgcReplayTelemetrySource` piping parsed records at real-time intervals into `flight_core` and UI
- [x] 3.4 Verify time synchronization and malformed record resilience during replay

## 4. Web & Unsupported Platform Fallback
- [x] 4.1 Implement environment and platform capability detection for `kIsWeb` and unsupported desktop environments
- [x] 4.2 Update `apps/mobile/lib/main.dart` bootstrap to auto-activate synthetic or bundled replay mode on web targets
- [x] 4.3 Add web compilation and platform fallback integration tests
