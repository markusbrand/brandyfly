# Proposal

## Why

The current `AirspaceMapLayer` uses a Flutter `CustomPaint` overlay to render loaded OpenAir airspace polygons. This causes the airspace boundaries to "swim" or lag against the base map during camera movements, mimicking the exact issue previously solved for the flight track. Moving airspaces into a native MapLibre GeoJSON layer ensures they stay geographically locked to the map, leverages hardware-accelerated GPU rendering, and allows MapLibre's built-in collision-aware text engine to cleanly place airspace labels without manual centroid calculations or overlapping track data.

## What Changes

- Remove the Flutter-based `AirspaceMapLayer` widget entirely.
- Connect `AirspaceService`'s `loadedAirspaces` and `latestProximity` directly to `MapFlightLayers` inside `MapWidget`.
- Serialize the list of `AirspaceModel`s into a native MapLibre GeoJSON `FeatureCollection` in `TrackGeoJson`, replacing the static single-polygon mock airspace.
- Add a native `SymbolStyleLayer` for airspace names and classes, allowing the MapLibre engine to handle text placement and collision automatically.
- Update the GeoJSON source dynamically whenever airspaces are loaded or the active proximity alert level changes to provide visual highlighting (red stroke/fill).

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `native-map-flight-overlays`: Upgrade the static mock airspace layer to render the complete list of loaded OpenAir airspaces, updating dynamically on proximity alerts, and add a native symbol layer for collision-aware airspace labeling.

## Impact

- **UI/UX**: Airspaces will no longer jitter or swim during map pans/zooms. Airspace labels will be much cleaner and won't obscure critical map features or overlap each other.
- **Performance**: Eliminates the heavy UI-thread `CustomPaint` loop calculating geographical projections for every airspace polygon vertex on every frame.
- **Code**: `AirspaceMapLayer` and its CustomPainter are deleted. `MapFlightLayers` is expanded.
