## Context

See `proposal.md` for motivation. The deterministic Rust OpenAir parser and 3D proximity engine were implemented in `flight_core` and wrapped by `AirspaceService` (`apps/mobile/lib/services/airspace_service.dart`). However, `AirspaceService` is not instantiated or provided in `main.dart`, nor is it connected to real-time flight telemetry or terrain elevation data. Furthermore, `AirspaceSideCutWidget`, `AirspaceWarningBannerHud`, and `AirspaceMapLayer` are isolated widgets in `apps/mobile/lib/widgets/flight/` that cannot be placed on the 16x32 flight grid.

## Goals / Non-Goals

**Goals:**
- Provide `AirspaceService` in `main.dart` and automatically load the bundled DACH OpenAir airspace fixture in mock flight mode and local testing.
- Subscribe `AirspaceService` to `FlightTrackingService` telemetry stream and `ElevationService` terrain queries, throttling proximity evaluation to 1 Hz to prevent UI thread jitter.
- Add `WidgetType.airspaceSideCut` to `widget_catalog.dart` with minimum bounds (8x4) and responsive presets (S: 16x6, M: 16x8, L: 16x12, Full: 16x32).
- Wire `AirspaceSideCutWidget` into `widget_slot.dart` to render real-time glide slope projections and forward airspace vertical cross-sections.
- Mount `AirspaceWarningBannerHud` on the `LayoutCanvas` overlay layer and trigger audio warning beeps via `AudioVarioService` upon alert level escalation.

**Non-Goals:**
- Online NOTAM feeds or remote airspace download services (relies on local OpenAir files).
- Interactive vector boundary editing or splitting inside the app.

## Decisions

### Decision 1: Service Lifecycle & Telemetry Coupling
- *Approach*: Instantiate `AirspaceService` in `main.dart` and expose it via `ChangeNotifierProvider<AirspaceService>`. In `initState`, bind to `_trackingService` telemetry stream. When a new flight point arrives, query `_elevationService.getElevation(lat, lon)` and evaluate proximity via `evaluateProximity(...)` at an interval of 1.0 second.
- *Rationale*: Running proximity checks at 1 Hz provides timely collision awareness (a paraglider moving at 50 km/h travels ~14 meters per second) while keeping CPU usage minimal.
- *Alternatives*: Evaluating on every GPS point at 10-20 Hz (excessive battery consumption and FFI marshalling overhead with zero practical benefit).

### Decision 2: Placeable `WidgetType.airspaceSideCut` in 16x32 Grid
- *Approach*: Add `airspaceSideCut` to `WidgetType` enum and `widgetCatalog`:
  - `minSize`: `GridSize(8, 4)`
  - `defaultSize`: `GridSize(16, 8)`
  - `presets`: S (`16x6`), M (`16x8`), L (`16x12`), Full (`16x32`).
- *Rationale*: A side-cut profile requires sufficient horizontal resolution to render the forward lookahead distance (10-15 km) and vertical altitude axis without compressing airspace labels.
- *Alternatives*: Fixed full-screen-only view (rejected; pilots frequently want a compact 16x6 bottom profile beneath their map).

### Decision 3: Canvas-Layered Warning Banner HUD
- *Approach*: Insert `AirspaceWarningBannerHud` directly into `LayoutCanvas` above the widget slots. The banner listens to `AirspaceService` alert changes.
- *Rationale*: Placing the HUD at the canvas layer ensures warnings are immediately visible across all screen layout configurations without requiring pilots to allocate an explicit grid slot for safety alerts.
- *Alternatives*: Grid-bound warning widget (risks being omitted if a pilot designs a custom layout without that widget).

### Decision 4: Audio Alert Dispatching via `AudioVarioService`
- *Approach*: Add `playAirspaceAlert(AirspaceAlertLevel level)` to `AudioVarioService`. When `AirspaceService` detects a state escalation from Safe -> Advisory/Warning or Warning -> Violation, dispatch the audio alert.
- *Rationale*: Pilots flying in thermals or turbulent conditions keep their eyes on the horizon and terrain; acoustic warning cues are essential for flight safety.
- *Alternatives*: OS system beep/vibrate only (unreliable through helmet audio / Bluetooth headsets).

## Risks / Trade-offs

- **[Risk] High CPU load when evaluating dozens of airspaces** → Mitigation: `flight_core` uses an R-Tree index that quickly discards airspaces outside the 15 km candidate radius, taking < 0.2 ms per evaluation cycle.
- **[Risk] Terrain DEM miss during AGL calculation** → Mitigation: Fall back to standard MSL reference and log a debug notice without interrupting horizontal proximity evaluations.
- **[Risk] Multiple overlapping warning banners** → Mitigation: `AirspaceWarningBannerHud` ranks active alerts by severity (Violation > Warning > Advisory) and closest separation distance, displaying the highest-priority threat prominently.

## Migration Plan

1. Update `WidgetType` and `WidgetCatalog` with `airspaceSideCut`.
2. Integrate `AirspaceService` into `main.dart` and attach telemetry listeners.
3. Wire `AirspaceSideCutWidget` into `widget_slot.dart`.
4. Add `AirspaceWarningBannerHud` to `LayoutCanvas`.
5. Connect `AudioVarioService` alert tone generator.
6. Verify via mock flight session and automated tests.
