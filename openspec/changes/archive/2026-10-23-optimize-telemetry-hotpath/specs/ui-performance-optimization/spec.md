# Spec Delta

## ADDED Requirements

### Requirement: Single telemetry emission per sensor tick
The `TelemetryRepository` SHALL emit at most one `CockpitTelemetry` value notification for each incoming live `TelemetrySnapshot`, even when `FlightTrackingService` is simultaneously recording points in `FlightState.flying`.

#### Scenario: Active flight does not double-emit telemetry
- **WHEN** `FlightTrackingService` is in `FlightState.flying` and both `FlightTrackingService` and `TelemetryRepository` are attached to the same `ITelemetrySource`
- **THEN** each incoming `TelemetrySnapshot` SHALL produce exactly 1 notification on `TelemetryRepository.telemetry` (not 2)
- **AND** `FlightTrackingService` SHALL only notify `ChangeNotifier` listeners when flight state, settings, source attachment, or the displayed whole-second recording duration changes.

#### Scenario: Takeoff state transition immediately updates RTL telemetry
- **WHEN** `FlightTrackingService` transitions from `FlightState.groundPreflight` to `FlightState.flying` (either automatically or via `startManualRecording()`)
- **THEN** `TelemetryRepository` SHALL update `takeoffTime`, `takeoffLocation`, and `takeoffAltitude` on the active `CockpitTelemetry` snapshot without waiting for user interaction.

### Requirement: Blur-free overlay surfaces over MapLibre canvas
Cockpit overlays rendered above the live MapLibre GL platform view and flight canvas (`ReplayControlOverlay` and `TopNavBarOverlay`) SHALL use high-opacity dark bezel surfaces instead of real-time `BackdropFilter` Gaussian blur filters (`ImageFilter.blur`) to prevent per-frame GPU texture readback and raster jank.

#### Scenario: ReplayControlOverlay renders without BackdropFilter
- **WHEN** `ReplayControlOverlay` is mounted in either expanded or collapsed state over the flight canvas
- **THEN** its widget subtree SHALL NOT contain a `BackdropFilter` widget
- **AND** it SHALL render with a high-contrast dark surface container and border.

#### Scenario: TopNavBarOverlay translucentDrawer renders without BackdropFilter
- **WHEN** `TopNavBarOverlay` is rendered with `NavBarStyle.translucentDrawer`
- **THEN** its widget subtree SHALL NOT contain a `BackdropFilter` widget
- **AND** it SHALL preserve legibility using a dark translucent surface decoration.

### Requirement: Live rolling glide ratio calculation
The `TelemetryRepository` SHALL compute a smoothed rolling glide ratio (`L/D`) over a 15-second window of horizontal speed and vertical climb/sink samples during live flight, rather than emitting a static constant placeholder.

#### Scenario: Steady descending glide produces accurate L/D
- **WHEN** the aircraft glides at a steady groundspeed of $36\text{ km/h}$ ($10\text{ m/s}$) and a sink rate of $-1.25\text{ m/s}$ over a 15-second window
- **THEN** `CockpitTelemetry.glide` SHALL converge to $8.0$ ($\pm 0.1$).

#### Scenario: Climbing or near-zero sink clamps or holds last valid glide ratio
- **WHEN** the rolling average vertical speed is $\ge -0.05\text{ m/s}$ (climbing or zero-sink) or groundspeed is $< 5.0\text{ km/h}$
- **THEN** the glide calculation SHALL NOT divide by zero or emit negative/infinite values, and SHALL clamp valid descending glide ratios to $[0.5, 50.0]$ (retaining the last valid glide ratio or configured idle default when climbing).

#### Scenario: Telemetry gap resets rolling glide buffer
- **WHEN** a timestamp gap between consecutive telemetry samples exceeds $5\text{ seconds}$
- **THEN** the rolling glide sample window SHALL clear prior stale samples before accumulating new samples.

## MODIFIED Requirements

### Requirement: RepaintBoundary isolation on custom painters
Every `CustomPaint` widget rendering flight telemetry (sparkline charts, vario bars, thermal maps, airspace side-cut profiles, flight track overlays) SHALL be wrapped in a `RepaintBoundary` so that paint invalidation does not propagate beyond the boundary to parent or sibling widgets.

#### Scenario: Vario bar repaint does not cascade
- **WHEN** the vario climb rate value changes at 20 Hz
- **THEN** only the `VarioLiftSinkBar` subtree SHALL repaint; adjacent altitude and speed widgets SHALL NOT repaint

#### Scenario: Thermal map pulse animation is isolated
- **WHEN** the thermal map pulse animation controller fires at 60 FPS
- **THEN** the repaint SHALL be contained within the thermal map widget boundary and SHALL NOT cause the parent layout container to repaint

#### Scenario: Airspace side-cut repaint is isolated
- **WHEN** `AirspaceSideCutWidget` repaints due to an altitude, heading, or forward airspace change
- **THEN** the repaint SHALL be contained within its `RepaintBoundary` and SHALL NOT invalidate sibling instrument slots on the flight canvas

### Requirement: Field-Scoped Telemetry Rebuilds
Telemetry SHALL be delivered to the flight canvas as an immutable typed snapshot, and each instrument widget (including `airspaceSideCut`) SHALL rebuild only when the snapshot fields it displays change at display precision. Layout containers, edit chrome and widgets whose displayed fields are unchanged SHALL NOT rebuild on a telemetry update.

#### Scenario: Altitude-only change
- **WHEN** a telemetry update changes altitude but leaves speed, glide, climb and wind unchanged
- **THEN** only widgets displaying altitude (altitude instrument, altitude chart, airspace side-cut, map legend) SHALL rebuild
- **AND** the layout canvas and speed, glide, vario and wind widgets SHALL NOT rebuild.

#### Scenario: Airspace side-cut ignores sub-threshold jitter and unrelated fields
- **WHEN** a telemetry update changes only `windSpeed`, `thermalSession`, or sub-meter altitude/heading jitter below display quantization thresholds
- **THEN** the `airspaceSideCut` widget slot SHALL NOT rebuild.

#### Scenario: Rebuild budget per tick
- **WHEN** a screen with 10 widgets receives 100 telemetry updates in which all displayed fields change
- **THEN** the layout canvas SHALL build at most once (initial build) and each instrument SHALL build at most 101 times.

#### Scenario: Stale or missing telemetry fields
- **WHEN** a snapshot field is missing or older than the stale threshold of the telemetry source
- **THEN** the instrument SHALL display its placeholder or stale indication without rebuilding unrelated widgets.
