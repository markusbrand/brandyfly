# Tasks

## 1. Domain Readiness Model & Rules

- [x] 1.1 Define immutable sensor readiness domain types (`SensorDomainStatus`, `SensorCapabilities`, `SensorReadinessState`, and pure-Dart readiness evaluation rules for barometer/vario and GPS/GNSS including staleness and mock/replay suppression) in `apps/mobile/lib/domain/models/sensor_readiness.dart`, and verify with plain Dart unit tests covering missing barometer, missing/denied GPS, combined onboard+Bluetooth satisfaction, stale timeout, and mock/replay suppression (`flutter test test/domain/sensor_readiness_test.dart`).

## 2. Native Sensor Capability Probe

- [x] 2.1 Add `getSensorCapabilities` to `BrandyflyNativePlatform` / `MethodChannelBrandyflyNative` / `BrandyflyNative` in `plugins/brandyfly_native/lib/` with a typed `NativeSensorCapabilities` model and graceful `MissingPluginException` fallback, and verify with plugin Dart unit tests (`flutter test` inside `plugins/brandyfly_native`).
- [x] 2.2 Implement `getSensorCapabilities` in Android (`BrandyflyNativePlugin.kt` inspecting `Sensor.TYPE_PRESSURE`, `PackageManager.FEATURE_LOCATION_GPS`, `LocationManager` providers, and location/Bluetooth permission state) and iOS (`BrandyflyNativePlugin.swift` inspecting `CMAltimeter.isRelativeAltitudeAvailable()` and `CLLocationManager` authorization/service state), and verify with native Android unit tests (`./gradlew test` in `plugins/brandyfly_native/example/android` or `BrandyflyNativePluginTest.kt`) and `flutter analyze` across `plugins/brandyfly_native`.

## 3. Sensor Readiness Service & App Wiring

- [x] 3.1 Implement `SensorReadinessService` in `apps/mobile/lib/services/sensor_readiness_service.dart` observing `SensorCapabilities` (on startup and `AppLifecycleState.resumed`), live `TelemetryRepository` / `ITelemetrySource` snapshots, external Bluetooth vario transport state, and a 5-second staleness watchdog in live mode, and verify with service unit tests using fake capability providers and fake telemetry streams (`flutter test test/services/sensor_readiness_service_test.dart`).
- [x] 3.2 Wire `SensorReadinessService` into `BrandyFlyApp` (`apps/mobile/lib/main.dart`) via `Provider` with injectable dependencies for tests, re-probing capabilities on app resume and suppressing live readiness alerts while `config.enabled` (mock mode) or replay mode is active; verify no regression in existing `main` / app startup tests (`flutter test test/widget_test.dart`).

## 4. Persistent Top Alert Liner UI & Stacking

- [x] 4.1 Implement `SensorAlertLiner` widget in `apps/mobile/lib/widgets/flight/sensor_alert_liner.dart` displaying a high-contrast, non-dismissable warning strip with concise missing-sensor diagnostics (e.g., missing barometer, missing GPS, connect Bluetooth vario) and an accessible quick action to open Settings without blocking navigation; verify with widget tests across missing-baro, missing-GPS, combined missing, auto-clear, and reconnection transitions (`flutter test test/widgets/sensor_alert_liner_test.dart`).
- [x] 4.2 Integrate `SensorAlertLiner` at the top of the `BrandyFlyApp` shell within `SafeArea` and coordinate top offsets/insets with `TopNavBarOverlay`, `RecordingStatusOverlay`, and `AirspaceWarningBannerHUD`, verifying no `RenderFlex` overflow or overlap in widget tests across `390x844` (portrait), `844x390` (landscape), and `1280x800` (tablet) viewports (`flutter test test/widgets/sensor_alert_liner_layout_test.dart`).

## 5. End-to-End Verification & Spec Compliance

- [x] 5.1 Run full `apps/mobile` static analysis (`flutter analyze`) and the targeted mobile & plugin test suites, verifying offline readiness evaluation, zero fabricated telemetry, and all `sensor-readiness-alert` scenarios pass.
- [x] 5.2 Run `npx openspec validate --all --strict` and verify all planning artifacts and spec deltas pass strict validation before review/archive.
