# Design

## Context

See [proposal.md](./proposal.md) and [spec.md](./specs/sensor-readiness-alert/spec.md) for motivation and behavioral requirements.

In the current `apps/mobile` architecture:
- `BrandyFlyApp` (`apps/mobile/lib/main.dart`) boots in `MockFlightModeConfig.fromEnvironment()` when `kDebugMode || config.enabled` is true, attaching `SyntheticTelemetrySource` to `TelemetryRepository` and `FlightTrackingService`. When running a release build without mock mode, `TelemetryRepository` initializes with `_liveIdleTelemetry` (static placeholder values with `hasSource = false`) and no live onboard sensor or Bluetooth vario capability probe is surfaced to the UI.
- `TopNavBarOverlay` wraps the active screen (`UISettingsPanel`, `_LiveFlightView`, or `_MockFlightView`) inside a `Stack`, placing an invisible 48dp-tall drag/tap grab handle at `top: 0` inside `SafeArea`.
- `LayoutCanvas` anchors `AirspaceWarningBannerHUD` at `top: 8, left: 16, right: 16` inside the flight canvas when not in Edit Mode.
- `RecordingStatusOverlay` floats at `topRight` (`margin: top: 8, right: 8`) inside `_LiveFlightView`.
- `BrandyflyNative` (`plugins/brandyfly_native`) provides the platform channel boundary for Android (`BrandyflyNativePlugin.kt` + `SkyDrop1TransportManager.kt`) and iOS (`BrandyflyNativePlugin.swift`).

## Goals / Non-Goals

**Goals:**
- Keep sensor readiness evaluation in a pure Dart domain/service layer decoupled from Flutter widgets and testable with fake capabilities/streams (consistent with `layered-ui-architecture`).
- Monitor both required flight sensor domains (barometer/vario and GNSS/GPS) with minimal battery overhead and zero impact on hot sensor/audio threads.
- Render a compact, persistent top alert liner in the application shell that coexists cleanly with `SafeArea`, `TopNavBarOverlay`, `RecordingStatusOverlay`, and `AirspaceWarningBannerHUD` across phone/tablet and portrait/landscape layouts.

**Non-Goals:**
- Implementing continuous high-frequency barometer polling inside Flutter UI widgets; hardware capability detection uses lightweight OS capability/permission queries plus observation of incoming `TelemetrySnapshot` / transport state.
- Designing a full Bluetooth device pairing wizard in this change (if no BT vario UI exists yet, tapping an optional "Settings" action on the liner navigates to `UISettingsPanel`; full BT pairing flows belong to dedicated transport changes).

## Decisions

### 1. Domain State Model (`SensorReadinessState`) & Service (`SensorReadinessService`)
- **Choice**: Create an immutable domain model `SensorReadinessState` (pure Dart, zero Flutter widget dependencies) tracking per-domain availability (`SensorDomainStatus`: `availableReady`, `hardwareMissing`, `permissionDenied`, `disabled`, `waitingForFix`, `disconnected`, `stale`) for:
  - `barometer`: satisfied when either an active `TelemetrySnapshot` provides valid non-stale pressure/barometric-altitude/vario data from a live source (`hasSource == true`, not mock/replay, `isValid && !isStale`, and `pressureHpa != null` or source advertises barometric/vario capability), OR an attached external Bluetooth vario transport reports `connected` with recent valid samples.
  - `gps`: satisfied when live `TelemetrySnapshot` carries valid non-stale coordinates (`latitude != null && longitude != null`, within `[-90, 90]` / `[-180, 180]`, excluding uninitialized `(0.0, 0.0)` unless explicitly marked valid) and `isValid && !isStale`.
- **Service integration**: `SensorReadinessService extends ChangeNotifier` (or exposes `ValueListenable<SensorReadinessState>`) lives at the `BrandyFlyApp` root via `Provider`. It observes:
  1. One-shot & lifecycle-resumed platform hardware/permission capability probes via `BrandyflyNative` (`getSensorCapabilities()` returning `{hasBarometer, hasGps, locationEnabled, locationPermissionGranted, bluetoothAvailable}` — defaulting gracefully via `MissingPluginException` on unsupported/desktop/web hosts).
  2. Live `TelemetryRepository.telemetry` / source attachment events and `SkyDrop1TransportState` / BLE transport status.
  3. A lightweight staleness watchdog timer (1 Hz check against monotonic/elapsed receive timestamps, 5 s default threshold) only active in live mode when a source was previously ready or connecting, avoiding wakeups during idle/mock/replay states.
- **Alternative considered**: Evaluating readiness solely inside `CockpitTelemetry` or inside UI widgets.
  - *Rejected*: `CockpitTelemetry` represents flight instrument values and intentionally uses idle defaults (`_liveIdleTelemetry`) when no source is attached; mixing hardware capability/permission reasons ("no barometer hardware" vs "GPS permission denied" vs "Bluetooth vario disconnected") into every telemetry tick would bloat hot-path snapshots and couple domain reasons to UI widgets.

### 2. Platform Capability Probe & Thread / Battery / Platform Trade-offs
- **Choice**: Query OS sensor hardware presence asynchronously on startup and on `AppLifecycleState.resumed` via `BrandyflyNative` (`SensorManager.getDefaultSensor(Sensor.TYPE_PRESSURE)` + `PackageManager.FEATURE_LOCATION_GPS` / `LocationManager` on Android; `CMAltimeter.isRelativeAltitudeAvailable()` + `CLLocationManager` authorization/accuracy on iOS).
- **Latency & Battery trade-off**:
  - Capability checks run once on startup and on app resume (< 2 ms IPC, zero continuous sensor wake-locks).
  - Continuous sample freshness relies on timestamps of samples already flowing through the flight pipeline, rather than opening a duplicate `SensorManager` or `CLLocationManager` listener in Dart. This adds near-zero battery drain and keeps sensor acquisition off the Flutter UI thread.
- **Platform trade-off**:
  - On Android devices without `TYPE_PRESSURE` (common on budget phones/tablets), `hasBarometer == false` immediately surfaces the missing-barometer warning at launch and indicates a Bluetooth vario can supply it.
  - On iOS, since SkyDrop 1 Bluetooth Classic SPP is unsupported without MFi (`skydrop1-transport-validation`), missing onboard barometer/GPS guidance avoids falsely promising SkyDrop 1 Classic support on iOS and references compatible sensors / device settings.

### 3. Persistent Top Alert Liner Placement & Overlay Stacking
- **Choice**: Introduce `SensorAlertLiner` anchored at the top of the application shell inside `SafeArea` (above `_LiveFlightView` / `FlightsScreen` / `UISettingsPanel` or integrated into the top stack of `BrandyFlyApp` below the `TopNavBarOverlay` drawer surface when the drawer is open).
- **Layout & Stacking Details**:
  - Anchored at `top: 0` inside `SafeArea` as a full-width, compact single/two-line horizontal strip (approx. 36–44 dp height, high-contrast amber/red cockpit styling with warning icon, concise reason e.g. `"Insufficient sensors: No barometer · Waiting for GPS — Connect Bluetooth vario"`, and optional `"Settings"` quick-action chip).
  - **Grab handle compatibility**: `TopNavBarOverlay`'s 48 dp top grab handle sits above the liner or spans the top edge with `HitTestBehavior.translucent`, ensuring swiping down from the top edge always opens navigation even while the liner is displayed.
  - **Airspace HUD & Recording overlay coordination**: Expose the liner's visibility/height (e.g., via `MediaQuery` padding or a shared top-banner slot/offset) so `AirspaceWarningBannerHUD` in `LayoutCanvas` and `RecordingStatusOverlay` shift below the active liner instead of overlapping it.
- **Alternative considered**: Rendering the warning inside `LayoutCanvas` alongside `AirspaceWarningBannerHUD`.
  - *Rejected*: The requirement specifies an alert liner **on top of the application** (not only on the flight canvas), so it should remain visible across flight screen switches and while inspecting screens before takeoff, while still allowing navigation/settings/logbook access.

### 4. Suppression in Mock & Replay Modes
- **Choice**: `SensorReadinessState.shouldShowBanner` evaluates to `false` whenever `isMockFlightMode == true` or `isReplayActive == true`. Exiting replay immediately re-evaluates live readiness and displays the liner if live sensors remain insufficient.

## Risks / Trade-offs

- **Risk**: On desktop/emulator or Flutter tests where `BrandyflyNative` does not implement `getSensorCapabilities`, `MissingPluginException` could cause unexpected crashes or false positives.
  → **Mitigation**: Catch `MissingPluginException` gracefully and allow injecting a fake `SensorCapabilityProvider` into `BrandyFlyApp` and `SensorReadinessService` for deterministic unit and widget tests.
- **Risk**: Top alert liner could collide with `RecordingStatusOverlay` (anchored `topRight` with `top: 8`) or `AirspaceWarningBannerHUD` (`top: 8`).
  → **Mitigation**: Use a dedicated top `Column` / `MediaQuery.padding` inset or coordinated top offset in the app shell so downstream top-anchored overlays automatically position below the liner when visible.
- **Risk**: Transient GPS cold-start (taking 10–30 s outdoors) triggers the banner on every cold launch even on capable phones.
  → **Mitigation**: This is desirable behavior per spec ("until it has the required sensor values"), and phrasing distinguishes `"Acquiring GPS fix..."` (when GPS hardware & permission exist) from `"GPS unavailable / permission denied"` so pilots see accurate status before takeoff.
