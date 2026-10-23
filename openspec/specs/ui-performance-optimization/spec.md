# ui-performance-optimization Specification

## Purpose
Establishes performance guardrails for the BrandyFly flight cockpit UI, ensuring scoped widget rebuilds, RepaintBoundary isolation, const constructor enforcement, and garbage-free hot-path contracts to maintain smooth frame rates during active flight telemetry rendering.

## Requirements

### Requirement: Scoped widget rebuilds
The flight cockpit UI SHALL scope `ListenableBuilder` and `AnimatedBuilder` listeners to the narrowest possible subtree so that telemetry updates, edit-mode state changes, and overlay toggles do not trigger full-screen rebuilds of unrelated widget branches.

#### Scenario: Telemetry update does not rebuild MaterialApp
- **WHEN** the telemetry source emits a new data snapshot at 10 Hz
- **THEN** only the individual instrument widgets (altitude, speed, vario bar, etc.) SHALL rebuild; the MaterialApp, theme configuration, and route scaffold SHALL NOT rebuild

#### Scenario: Edit-mode toggle does not rebuild instrument content
- **WHEN** the user enters or exits layout edit mode
- **THEN** only the edit-mode overlay controls SHALL rebuild; the underlying instrument widget content SHALL NOT be destroyed and recreated

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

### Requirement: Garbage-free telemetry hot paths
Telemetry processing code executing at 10 Hz or faster SHALL NOT allocate temporary `String` objects for numeric rounding, SHALL NOT create new `List` instances from existing data on every tick, and SHALL NOT instantiate `Paint`, `Path`, or `TextPainter` objects inside `paint()` methods on every frame.

#### Scenario: Synthetic telemetry rounding uses math operations
- **WHEN** the `SyntheticTelemetrySource` generates a telemetry snapshot at 10 Hz
- **THEN** numeric values SHALL be rounded using mathematical operations (e.g., `(val * 10).round() / 10.0`) instead of `double.parse(toStringAsFixed())`

#### Scenario: Replay track list is cached incrementally
- **WHEN** the `FlightReplayService` advances by one point during playback
- **THEN** the track list SHALL be extended incrementally rather than re-slicing the full point array

#### Scenario: CustomPainter reuses allocated objects
- **WHEN** a `CustomPainter.paint()` method executes for any flight instrument widget
- **THEN** `Paint`, `Path`, and `TextPainter` instances SHALL be cached as class fields and reused across frames

### Requirement: Zero-dimension paint safety guard
All `CustomPainter` implementations SHALL guard against zero or negative canvas dimensions before executing drawing loops, preventing infinite loops that freeze the UI thread.

#### Scenario: Sparkline chart with zero-size canvas
- **WHEN** `AltitudeSparklineChart` receives layout constraints with `width == 0` or `height == 0`
- **THEN** the painter SHALL return immediately without executing grid drawing loops and SHALL NOT enter an infinite iteration

### Requirement: Const constructor enforcement on leaf widgets
Stateless leaf widgets that accept only primitive or enum parameters SHALL use `const` constructors, and static decoration objects, text styles, and edge insets SHALL be declared as `const` where the values are compile-time constants.

#### Scenario: ModeChip uses const constructor
- **WHEN** the `_ModeChip` widget is instantiated with a label string and color
- **THEN** the widget SHALL be eligible for const construction and Flutter's widget identity optimization

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

### Requirement: Edit Chrome Isolation
Edit Mode chrome (selection frames, handles, alignment guides, inspector, toolbar) SHALL rebuild only on layout, selection or edit-mode changes and SHALL NOT rebuild on telemetry updates.

#### Scenario: Telemetry during editing
- **WHEN** Edit Mode is active with a widget selected and 50 telemetry updates arrive
- **THEN** the inspector panel and edit frames SHALL NOT rebuild.

### Requirement: Single-Layer Grid Guide Painting
Edit Mode grid guides SHALL be painted by a single paint layer per canvas instead of one widget per guide line, and SHALL be repainted only when canvas size or grid geometry changes.

#### Scenario: Guide layer on 16x32 grid
- **WHEN** Edit Mode is shown on a 16x32 grid
- **THEN** grid guides SHALL be drawn by one painter and SHALL NOT repaint on telemetry updates or selection changes.

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
