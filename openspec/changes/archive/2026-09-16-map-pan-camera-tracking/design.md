## Context

In `MapWidget`, the map canvas is rendered via `MapLibreMap`, over which a `CustomPaint` widget (`_FlightOverlayPainter`) renders paragliding telemetry layers:
1. Airspace warning polygons
2. Vario-colored flight track breadcrumbs
3. Thermal hotspots
4. Glider position marker (halo and arrow)

Previously, panning was implemented using a `GestureDetector` that updated an ad-hoc `_panOffset: Offset`. Instead of panning the MapLibre map camera, `_panOffset` was added directly to the screen coordinates in `_FlightOverlayPainter._toScreen()`. This caused the glider cursor and flight track to slide across the screen while the underlying map remained completely frozen.

## Goals / Non-Goals

**Goals:**
- Move the MapLibre camera center coordinate across geographic space when the user drags/pans on `MapWidget`.
- Keep the glider position marker, flight track breadcrumbs, airspace polygons, and thermal hotspots anchored to their geographic coordinates on the map so that they stay in place on the terrain.
- Support both North-Up and Track-Up (with forward bias) orientation modes smoothly during pan gestures.
- Maintain full compatibility with `test/map_widget_integration_test.dart` and headless widget test environments (`_HeadlessMapLibrePlatform`).
- Ensure the 6-second auto-recenter timer and the manual "Recenter" button immediately restore center-locked tracking on the pilot.

**Non-Goals:**
- Replacing Flutter `CustomPaint` overlays with native MapLibre GeoJSON layers (would introduce method channel serialization overhead for 10Hz vario color changes and break headless test execution).
- Modifying `ThermalMapWidget`, which is intentionally glider-centric radar navigation.

## Decisions

### 1. Camera Center as Viewport & Projection Anchor
Instead of an arbitrary screen `_panOffset`, `MapWidget` maintains `LatLng _cameraCenter`.
- When center-locked (`_centerOnPilot == true`), `_cameraCenter` mirrors `_effectivePilotPosition`.
- When the user drags the map, the drag pixel vector is converted to latitude/longitude deltas based on Mercator projection at `_currentZoom` and viewport bearing:
  $$\Delta \text{lng} = \frac{-\Delta x_{\text{rot}}}{\text{pixelsPerDegreeLng}}$$
  $$\Delta \text{lat} = \frac{\Delta y_{\text{rot}}}{\text{pixelsPerDegreeLat}}$$
  where $(\Delta x_{\text{rot}}, \Delta y_{\text{rot}})$ is derotated by the map bearing in Track-Up mode.
- `_cameraCenter` updates accordingly, and `_mapService.moveCamera(position: _cameraCenter, zoom: _currentZoom, bearing: bearing)` moves the MapLibre camera.
- In `_FlightOverlayPainter`, `_toScreen()` projects all features (pilot marker, flight track points, thermals, airspace) relative to `_cameraCenter`.
- *Rationale*: Overlays and base map tiles move in complete 1:1 synchronization. Relative to the terrain, all flight features stay pinned to their geographical positions on the earth.

### 2. Dual Native and Flutter Gesture Synchronization
- Provide `onEvent` to `MapLibreMap` to listen for `MapEventMoveCamera`. When camera movement is driven by native gestures (`CameraChangeReason.apiGesture`), `MapWidget` syncs `_cameraCenter` and `_currentZoom`.
- Retain Flutter `GestureDetector` pan handling on the map view for environments where native platform views do not intercept Flutter gesture events (such as desktop simulators and headless automated widget tests).
- When a pan begins, `_centerOnPilot` is set to `false`, the visual center button highlights the uncentered state, and the 6-second inactivity recenter timer is started/reset.

### 3. Alternatives Considered
- *Alternative A: Native MapLibre GeoJSON Style Layers for Track & Overlays.*
  - *Trade-off*: High serialization overhead updating GeoJSON at 5–10 Hz with dynamic vario gradient colors. Furthermore, headless test harness in `flutter_test_config.dart` does not render native MapLibre layers.
- *Alternative B: Fix pilot cursor to screen center while dragging map.*
  - *Trade-off*: Would prevent exploring distant terrain or airspace ahead of flight path; paragliding flight instruments allow panning the map away from the current position with an auto-recenter safeguard.

## Risks / Trade-offs

- **[Risk] High-frequency camera movements during pan drag**: Rapid `moveCamera` calls across platform channels could cause micro-stutter on low-end devices.
  - *Mitigation*: `moveCamera` in `MapLibreMapService` is lightweight and non-blocking. If needed, pan updates update the local `_cameraCenter` state for instantaneous 60Hz CustomPaint redraws and dispatch camera updates smoothly.
- **[Risk] Projection drift between Mercator approximation and MapLibre projection at high pitch/latitudes**:
  - *Mitigation*: BrandyFly operates at paragliding latitudes (-60° to +60°) with pitch = 0 in standard flight mode; the local flat-earth / spherical Mercator projection at screen scale matches MapLibre's projection within sub-pixel accuracy across the viewport bounds.
