## Why

When dragging or panning `MapWidget` on mobile or the simulator, the gesture previously shifted the pilot cursor, track, thermals, and airspace overlays across the screen via an ad-hoc screen offset (`_panOffset`) while leaving the underlying MapLibre base map completely stationary. Pilots expect authentic map panning behavior: dragging must move the map camera across geographic space to inspect surroundings, while the pilot cursor and recorded flight track stay anchored to their true geographic locations on the terrain.

## What Changes

- **Map Camera Pan Navigation**: Panning on `MapWidget` now shifts the MapLibre camera center coordinate across geographic coordinates (accounting for zoom level and viewport orientation/bearing) instead of applying a screen offset to overlay elements.
- **Geographic Overlay Anchoring**: Flight track breadcrumbs, pilot cursor, airspace polygons, and thermal hotspots remain anchored to their real-world GPS coordinates relative to the active camera center, staying in place on the map rather than sliding across the screen.
- **Center-Lock Disengagement & Recenter Inactivity Timer**: Starting a pan gesture disengages center-lock (`_centerOnPilot = false`), activates the visual "Recenter" HUD button, and starts the 6-second inactivity timer to restore center-lock automatically.
- **Native & Flutter Gesture Harmony**: Ensures touch events pan the map seamlessly whether driven by native platform view gestures (`MapEventMoveCamera`) or Flutter pan gestures in simulator and test environments.

### Non-Goals

- Changing the mock flight simulator or telemetry ingestion rates.
- Modifying `ThermalMapWidget` radar display, which operates on relative glider-centric radar coordinates.
- Introducing multi-touch rotate gestures if disabled by map orientation locks (e.g. North-Up mode).

## Capabilities

### New Capabilities

*(None)*

### Modified Capabilities

- `center-glider-map-with-auto-recenter`: Clarify and enforce that manual pan interactions on `MapWidget` translate the map camera center across geographic coordinates so that the map terrain moves under the touch point while flight tracks and pilot markers remain geographically anchored to the map surface.

## Impact

- **Affected Code**: `apps/mobile/lib/widgets/flight/map_widget.dart`, `apps/mobile/test/map_widget_integration_test.dart`.
- **APIs & Dependencies**: Utilizes existing `MapLibreMapService.moveCamera` and `MapLibreMap.onEvent` hooks; no external package dependencies added.
- **Safety & Offline**: Preserves full offline map rendering and deterministic replay capabilities; ensures safety-critical telemetry remains rendered in correct geographical relation to terrain and airspace.
- **Licensing**: Fully compliant with project MIT license.
