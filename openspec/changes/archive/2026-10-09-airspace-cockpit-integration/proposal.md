## Why

The deterministic Rust OpenAir parser and 3D proximity engine were recently verified, but `AirspaceService` remains disconnected from the live application runtime, and pilots cannot place the airspace side-cut profile widget on their 16x32 flight screens. Integrating airspace evaluation into the live flight loop and cockpit display provides real-time situational awareness and audio-visual proximity warnings to prevent inadvertent airspace violations during flight.

## What Changes

- **Live Flight Loop Integration**: Initialize `AirspaceService` in `main.dart`, automatically load bundled OpenAir airspace data (or DACH fixtures in simulation and testing), and feed real-time GPS telemetry and DEM terrain elevations from `FlightTrackingService` and `ElevationService` into the proximity engine at 1–2 Hz.
- **Airspace Side-Cut Widget in 16x32 Catalog**: Register `WidgetType.airspaceSideCut` in `WidgetCatalog`, `WidgetType`, and `widget_slot.dart` with minimum bounds (8x4) and responsive presets (S: 16x6, M: 16x8, L: 16x12, Full: 16x32) supporting both portrait and landscape screen configurations.
- **Flight Screen Airspace Warning Banner HUD**: Mount `AirspaceWarningBannerHud` on the flight canvas stack, rendering high-contrast warning pills and alert banners for active Advisory, Warning, and Violation states.
- **Audio Proximity Cues**: Trigger audio warning beeps via `AudioVarioService` when an airspace proximity state transitions to Warning (Level 2) or Violation (Level 3).
- **Airspace Map Layer Visualization**: Overlay `AirspaceMapLayer` on the interactive flight map to draw boundary lines and class-coded polygon highlights for nearby airspace sectors.

### Non-Goals

- Online NOTAM or dynamic airspace web API streaming during flight (offline OpenAir files remain authoritative).
- Glider flight path automation or autopilot intervention.
- Editing or modifying OpenAir text geometries directly within the mobile application.

## Capabilities

### Modified Capabilities

- `openair-airspace-parser-3d-proximity`: Mandate runtime telemetry pipeline coupling, DEM elevation integration for AGL queries, and audio alert notifications on warning escalations.
- `screen-widget-configuration`: Add `airspaceSideCut` to the placeable 16x32 widget catalog and specify the flight canvas `AirspaceWarningBannerHud` safety alert overlay.

## Impact

- `apps/mobile/lib/main.dart`: `AirspaceService` lifecycle, dependency injection, and telemetry subscription.
- `apps/mobile/lib/domain/models/widget_type.dart`, `apps/mobile/lib/domain/models/widget_catalog.dart`: `WidgetType.airspaceSideCut` enum and sizing specifications.
- `apps/mobile/lib/ui/features/flight_canvas/views/widget_slot.dart`: Render `AirspaceSideCutWidget` inside configured grid slots.
- `apps/mobile/lib/ui/features/flight_canvas/views/layout_canvas.dart`: Mount `AirspaceWarningBannerHud` on the flight canvas layer stack.
- `apps/mobile/lib/services/audio_vario_service.dart`: Emit alert tones on airspace warning escalation.
