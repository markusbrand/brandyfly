# Proposal

## Why

Paragliding and hang gliding pilots require continuous, glanceable situational awareness regarding their airborne duration and their ability to safely glide back to the launch site. Currently, the cockpit instrument catalog offers instantaneous flight metrics (altitude, speed, glide ratio, HAG, vario) and thermal statistics, but lacks a dedicated in-cockpit Flight Time / Clock instrument and a Return to Launch (RTL) / Glide to Takeoff navigation instrument. 

Without these instruments, pilots must divert attention to phone system clocks to track sunset deadlines, battery endurance, and XC competition windows, and must mentally estimate whether their current altitude allows them to clear terrain and return to takeoff when scratchy thermals fail. Introducing dedicated `flightTime` and `returnGlide` widgets into the responsive 16x32 cockpit grid solves this need safely, offline, and with zero-latency updates.

## What Changes

- **Telemetry Pipeline Expansion**:
  - Extend `CockpitTelemetry` with flight timing fields (`takeoffTime`, `flightDuration`, `localTime`) and return-to-launch navigation state (`takeoffLocation`, `takeoffAltitude`, `distanceToTakeoffMeters`, `bearingToTakeoffDegrees`, `requiredGlideToTakeoff`, `takeoffAltitudeMarginMeters`).
  - Wire `FlightTrackingService` takeoff events and `FlightReplayService` elapsed duration into `TelemetryRepository` so live flights, synthetic simulation, and replay sessions all provide consistent timing and launch geometry.
- **Flight Time Widget (`flightTime`)**:
  - Add a dedicated cockpit instrument displaying elapsed flight time (`hh:mm:ss` or `mm:ss`), current local time clock, and takeoff timestamp across regular, compact, and tiny size tiers.
  - Display `00:00` or `--:--` with a standby/pre-flight badge during pre-takeoff.
- **Return to Launch Widget (`returnGlide`)**:
  - Add a dedicated cockpit navigation instrument displaying distance back to launch (km/m), required glide ratio (L/D) to reach takeoff altitude, altitude margin above launch ($\Delta h$), and relative/cardinal bearing direction back to launch.
  - Provide safe, unambiguous fallback display (`---` or `+0m`) when before takeoff, when distance is zero, or when current altitude is below launch altitude.
- **Widget Catalog & Layout Editor Integration**:
  - Register `WidgetType.flightTime` and `WidgetType.returnGlide` in `widget_type.dart`, `widget_catalog.dart`, and layout migrator/schema.
  - Define minimum dimensions and size presets (`S`, `M`, `L`, `Full`) ensuring clean touch targets and overflow-free rendering.
  - Add both widgets to the layout editor widget picker sheet with distinct icons, descriptive labels, and inspector style controls.

### Non-Goals
- FAI turnpoint and competition task cylinder navigation (a comprehensive XC task navigation engine is deferred to a future specification).
- 3D terrain collision detection or wind-drifted RTL routing (return glide computes direct line-of-sight distance, bearing, and altitude margin relative to the launch coordinate).
- Configurable unit systems (Imperial/Nautical units will be addressed in a separate dedicated change).
- Spoken voice announcements or acoustic RTL boundary alarms.

## Capabilities

### New Capabilities
- `flight-time-and-rtl-instruments`: Computes flight duration, takeoff timestamps, and return-to-launch navigation metrics (distance to launch, bearing, required glide ratio, and launch altitude margin), exposing them through reactive telemetry and presenting them in dedicated cockpit instrument views.

### Modified Capabilities
- `screen-widget-configuration`: Extends the 16x32 virtual grid widget catalog, placement schema, size presets, layout migrator, inspector panel, and widget slot content dispatcher to support `flightTime` and `returnGlide` instrument types.

## Impact

- **Mobile Domain & Models**: `CockpitTelemetry`, `WidgetType`, `widgetCatalog`, `LayoutMigrator`.
- **Telemetry & Services**: `TelemetryRepository`, `FlightTrackingService`, `FlightReplayService`.
- **UI & Instruments**: New views `FlightTimeWidget` and `ReturnGlideWidget` under `apps/mobile/lib/ui/features/instruments/views/`, updated `WidgetSlot` content dispatcher, updated `WidgetPickerSheet`.
- **Safety, Offline & Privacy**: Fully offline calculation with no network calls or privacy leakage; zero division and graceful degradation when below launch altitude.
- **Performance**: High-efficiency granular selectors via `ValueSelector` in `WidgetSlot` preventing unnecessary redraws of unrelated instruments.
