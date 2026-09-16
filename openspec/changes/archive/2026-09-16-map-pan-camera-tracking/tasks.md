## 1. Camera Center State & Overlay Projection Refactor

- [x] 1.1 Replace `_panOffset` with `LatLng _cameraCenter` in `_MapWidgetState` and initialize/sync with `_effectivePilotPosition` when `_centerOnPilot` is active; verify state transitions cleanly on telemetry updates.
- [x] 1.2 Refactor `_FlightOverlayPainter` to project all flight overlays (glider marker, flight track points, airspace polygons, and thermal hotspots) relative to `cameraCenter` rather than an ad-hoc screen offset; verify overlay positions stay anchored to map coordinates.

## 2. Pan Gesture Calculation & Map Camera Dispatch

- [x] 2.1 Implement Mercator-based pixel-to-coordinate displacement in `GestureDetector.onPanUpdate` to translate `_cameraCenter` and dispatch `_mapService.moveCamera()`, disengaging center-lock and resetting the 6-second inactivity timer; verify camera movement during drag.
- [x] 2.2 Wire `MapLibreMap.onEvent` to listen for `MapEventMoveCamera` to keep `_cameraCenter` and `_currentZoom` synchronized with native gesture pans; verify bidirectional gesture synchronization.

## 3. Recenter Controls & Automated Test Suite

- [x] 3.1 Update the manual recenter action (`btn_map_recenter`) and the 6-second inactivity timer callback to reset `_cameraCenter` to `_effectivePilotPosition`, restore center-lock, and animate camera back to pilot; verify with timer advancement.
- [x] 3.2 Update and extend `test/map_widget_integration_test.dart` to assert that dragging translates the map camera and preserves geographic anchoring of pilot and track points without ad-hoc overlay shifting; verify all tests pass with `flutter test test/map_widget_integration_test.dart`.
