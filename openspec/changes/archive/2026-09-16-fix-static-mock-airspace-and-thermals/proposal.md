## Why

Currently in `MapWidget`, mock airspace restriction polygons and thermal updraft markers are calculated as relative offsets from `pilotPosition`. During live and simulated mock flights, this causes the red airspace polygon and thermal hotspot markers to follow the glider across the terrain instead of remaining stationary on Earth.

## What Changes

- **Static Geographic Anchoring for Mock Airspace**: Replace dynamic pilot-offset calculations with static coordinates (e.g. around the default Alpine reference launch area at Krippenstein/Dachstein, 47.525°N, 13.685°E) so airspace restriction polygons remain stationary on the map.
- **Static Geographic Anchoring for Thermal Hotspots**: Anchor thermal updraft hotspot markers (`+2.8`, `+3.4`, `+1.9`) to fixed Earth coordinates so they remain in place as the glider maneuvers and flies past them.
- **Preserve Overlay Projection**: Ensure `_toScreen()` continues to project fixed geographic coordinates smoothly with camera panning, track-up/north-up rotation, and zoom.

## Non-Goals

- Implementing a full dynamic OpenAir parser integration or OpenAir file downloader (tracked separately in `openair-airspace-parser-3d-proximity`).
- Changing flight track breadcrumb interpolation or altitude telemetry.

## Capabilities

### New Capabilities
<!-- None -->

### Modified Capabilities
- `offline-vector-map-rendering`: Update the flight overlay preservation requirement to specify that airspace limitation zones and thermal hotspot overlays are anchored to static geographic coordinates on the map rather than following pilot position.

## Impact

- **Affected Code**: `apps/mobile/lib/widgets/flight/map_widget.dart` and its widget/integration tests (`test/map_widget_integration_test.dart`).
- **Safety / Offline**: No breaking changes; enhances spatial awareness and prevents disorientation caused by moving airspace boundaries.
