# Proposal

## Why

When BrandyFly launches on a device that lacks required flight sensors (for example, an Android phone or Wi-Fi-only tablet without a barometer or GNSS receiver), lacks sensor permissions, or has not yet connected an external Bluetooth vario, the cockpit currently starts in live mode with static idle values and no explicit warning that flight telemetry is unavailable. Displaying a persistent top alert liner whenever required sensor inputs are missing prevents pilots from assuming live vario, altitude, or GPS tracking is active before takeoff or during sensor dropouts.

## What Changes

- Introduce a live sensor readiness evaluation model that tracks whether the application is receiving valid required sensor values for barometric/vario telemetry (barometer pressure, barometric altitude, or vertical speed) and GNSS positioning (latitude/longitude fix).
- Display a persistent, non-dismissable top alert liner at the top of the application whenever BrandyFly is in live mode and one or more required sensor streams are unavailable, unpermitted, disconnected, or not yet delivering valid values.
- Clearly identify which required sensor capabilities are missing (e.g., barometer missing/unavailable, GPS missing/no fix) and indicate remediation options such as connecting an external Bluetooth vario or enabling device location/sensors.
- Automatically clear the alert liner as soon as valid required sensor values are available (whether from internal device sensors, an external Bluetooth vario such as SkyDrop 1, or a combined internal + external source setup), and automatically re-display it if required sensor streams disconnect or become invalid/stale during live operation.
- Suppress the live sensor warning liner during intentional non-live modes (local mock/synthetic flight mode and IGC flight replay mode).

### Non-Goals

- Implementing new Bluetooth vario hardware drivers or iOS MFi workarounds beyond existing `ITelemetrySource` and `BrandyflyNative` transport contracts (e.g., SkyDrop 1 remains governed by `skydrop1-transport-validation`).
- Blocking access to offline logbook replay, layout editing, map browsing, or application settings while sensors are missing.
- Automatically fabricating synthetic barometer or GPS readings to mask missing hardware sensors in live mode.

## Capabilities

### New Capabilities
- `sensor-readiness-alert`: Evaluates live flight sensor availability and sample readiness (barometer/vario and GPS/GNSS) and renders a persistent top alert liner across the application until required sensor values are received.

### Modified Capabilities
<!-- None: existing capabilities (layered-ui-architecture, skydrop1-transport-validation, screen-widget-configuration) remain unchanged in their requirements. -->

## Impact

- **Safety**: Improves pre-flight and in-flight safety by preventing silent reliance on idle/fallback telemetry when a device lacks a barometer, lacks GPS, or loses its Bluetooth vario link; works completely offline with zero network dependency.
- **Offline & Privacy**: Sensor readiness checks run purely on-device using local hardware/transport state and never transmit sensor diagnostics or location data over the network.
- **Licensing**: No new third-party dependencies or license impacts (pure Dart/Flutter + existing MIT-licensed `brandyfly_native` plugin boundary).
- **Affected Areas (planned)**:
  - `apps/mobile/lib/domain/` & `apps/mobile/lib/services/` — sensor readiness state model/service combining onboard capability/permission checks, `ITelemetrySource` / `TelemetryRepository` live snapshots, and Bluetooth vario transport state.
  - `apps/mobile/lib/main.dart` & `apps/mobile/lib/widgets/` — persistent top alert liner widget integrated into the application shell above active views without obstructing navigation or airspace alerts.
  - `plugins/brandyfly_native/` — read-only hardware sensor capability query (e.g., barometer/GNSS availability) if not yet exposed by platform channels.
