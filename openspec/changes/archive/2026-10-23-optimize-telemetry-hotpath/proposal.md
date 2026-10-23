# Proposal

## Why

During active flight (5–10 Hz telemetry) and accelerated flight replay (up to 10x speed), the mobile cockpit UI currently incurs four avoidable performance bottlenecks on the hot path:
1. **Redundant double telemetry emissions per sensor tick**: Both `FlightTrackingService` and `TelemetryRepository` subscribe to the telemetry stream; because `FlightTrackingService._handleFlyingPoint()` calls `notifyListeners()` on every flying point, `TelemetryRepository._onTrackingChanged()` fires on every tick, recomputing geodesic distance/bearing and emitting a second duplicate `CockpitTelemetry` value per sensor tick.
2. **Unfiltered `AirspaceSideCutWidget` rebuilds & synchronous spatial queries**: `WidgetType.airspaceSideCut` in `FlightWidgetContent` uses an unfiltered `ValueListenableBuilder<CockpitTelemetry>` (rebuilding on every tick regardless of whether relevant fields changed) and runs `airspaceService.getForwardAirspaces(...)` (50+ polygon point-in-polygon steps per airspace) synchronously inside `build()`.
3. **Expensive GPU `BackdropFilter` blur over live MapLibre surface**: `ReplayControlOverlay` and `TopNavBarOverlay` apply real-time Gaussian blur (`ImageFilter.blur`) over the live 60 FPS MapLibre GL platform view and flight canvas, causing costly GPU texture readbacks and raster jank on mobile devices.
4. **Static placeholder Glide Ratio (`L/D`) in live telemetry**: `TelemetryRepository.onSnapshot` hardcodes `glide: _idle.glide` (`8.4`) during live flight instead of computing a smoothed rolling glide ratio from horizontal speed and vertical sink rate.

Resolving these four bottlenecks directly improves frame pacing, lowers battery consumption during multi-hour XC flights, and makes the cockpit Glide (`L/D`) and Airspace Side-Cut instruments reflect real flight performance.

## What Changes

- **Single Telemetry Emission per Sensor Tick**:
  - Decouple `TelemetryRepository` from per-point `FlightTrackingService.notifyListeners()` notifications by listening to `FlightTrackingService.stateStream` (or only reacting when `FlightState` / `takeoffPoint` transitions occur), while still allowing `RecordingStatusOverlay` to update its elapsed timer once per second when the second counter changes rather than on every 10–50 Hz sub-second point.
  - Ensure `TelemetryRepository` emits exactly one `CockpitTelemetry` notification per incoming `TelemetrySnapshot` during active flight.
- **Scoped & Throttled `AirspaceSideCutWidget` Rendering**:
  - Replace the unfiltered `ValueListenableBuilder<CockpitTelemetry>` for `WidgetType.airspaceSideCut` in `FlightWidgetContent` with a `ValueSelector` that selects quantized position, altitude, speed, heading, glide ratio, and HAG.
  - Wrap the `AirspaceSideCutWidget` in a `RepaintBoundary` and cache/Reuse `Paint` and `TextPainter` instances in `AirspaceSideCutPainter`.
  - Add spatial query caching/throttling in `AirspaceService.getForwardAirspaces(...)` so the ray-marching polygon intersection query only re-evaluates when aircraft position moves $> 25\text{ m}$, heading changes $> 2^\circ$, altitude changes $> 10\text{ m}$, glide ratio changes $> 0.5$, or loaded airspaces change.
- **Blur-Free High-Contrast Cockpit Overlays**:
  - Remove `BackdropFilter(filter: ImageFilter.blur(...))` from `ReplayControlOverlay` and `TopNavBarOverlay` (`_buildTranslucentDrawer`), replacing them with high-alpha dark cockpit bezel surfaces (`CockpitTokens.nightPanel` / `CockpitTokens.bezel` / high-opacity dark slate) that maintain sunlight readability without GPU texture readback overhead over the MapLibre platform view.
- **Live Rolling Glide Ratio (`L/D`) Calculation**:
  - Introduce a deterministic rolling `GlideAverager` (15-second rolling window over horizontal speed and vertical climb/sink samples, clearing on $> 5\text{ s}$ telemetry gaps) used by `TelemetryRepository` during both live telemetry and flight replay.
  - Compute smoothed `glide` (`L/D`) when the aircraft is gliding (`averageSinkRate < -0.05 m/s` and `averageSpeedKmh >= 5.0`), clamped to a readable range (`[0.5, 50.0]`), and fall back gracefully when climbing or stationary.

## Non-Goals

- Modifying the Rust native flight core FFI interface or native sensor drivers.
- Adding new user-facing widget types (covered separately in Issue #278).
- Adding unit-preference selectors or interactive airspace tap tooltips (covered separately in Issue #277).
- Changing offline map tile storage or OpenAir parser grammar.

## Capabilities

### New Capabilities

*(None — all changes extend existing performance and airspace capabilities.)*

### Modified Capabilities

- `ui-performance-optimization`: Add requirements for single telemetry emission per sensor tick during active flight, `ValueSelector` + `RepaintBoundary` + cached spatial query isolation for `AirspaceSideCutWidget`, blur-free overlay rendering over the MapLibre surface, and rolling glide ratio calculation in `TelemetryRepository`.
- `openair-airspace-parser-3d-proximity`: Update the `Airspace Side-Cut Profile Widget & Glide Slope Projection` requirement to specify threshold-gated spatial caching for forward airspace ray-casting and live rolling glide ratio input.

## Impact

- **Code**:
  - `apps/mobile/lib/services/flight_tracking_service.dart`
  - `apps/mobile/lib/data/repositories/telemetry_repository.dart`
  - `apps/mobile/lib/domain/thermal_assistant/glide_averager.dart` (new helper alongside `climb_averager.dart`)
  - `apps/mobile/lib/services/airspace_service.dart`
  - `apps/mobile/lib/ui/features/flight_canvas/views/widget_slot.dart`
  - `apps/mobile/lib/widgets/flight/airspace_side_cut_widget.dart`
  - `apps/mobile/lib/widgets/flight/replay_control_overlay.dart`
  - `apps/mobile/lib/widgets/navigation/top_nav_bar.dart`
- **Privacy, Safety, Offline & Licensing**:
  - **Safety**: Improves UI frame pacing and responsiveness under high-rate telemetry and airspace proximity alerts; provides real smoothed L/D to the cockpit glide and airspace side-cut instruments instead of a static `8.4` placeholder.
  - **Offline**: 100% on-device computation; zero network dependencies.
  - **Privacy & Licensing**: No external data transmission or new third-party dependencies (MIT compliant).
