# Design

## Context

See `proposal.md`. The native flight track and pilot marker overlay architecture was successfully implemented in `MapFlightLayers` using native MapLibre GeoJSON sources and `LineStyleLayer`s. However, `AirspaceMapLayer` was left as a `CustomPaint` overlay running on the Flutter UI thread, leading to jitter and asynchronous lag during high-framerate camera panning. `AirspaceService` currently loads airspace polygons using a Rust backend and holds them in `loadedAirspaces`.

## Goals / Non-Goals

**Goals:**
- Move all 2D airspace map visualization into MapLibre GL native layers.
- Maintain existing visual cues: Fill colors based on class, red highlighting during alerts.
- Use MapLibre's label placement engine to draw airspace names without overlapping.

**Non-Goals:**
- Changing the OpenAir parsing logic in `crates/flight_core`.
- Changing how the 3D side-cut profile widget evaluates airspace proximity.
- Moving other UI elements (like the thermal assistant radar) to MapLibre.

## Decisions

- **Decision 1: GeoJSON Serialization of Airspace Entities**
  - *Rationale*: MapLibre handles massive GeoJSON FeatureCollections extremely efficiently. Since airspace models change only when a file is explicitly loaded (or during rare proximity alerts), serializing the `List<AirspaceModel>` to a GeoJSON string in Dart and pushing it via `style.updateGeoJsonSource(airspaceSourceId)` is fast and simple.
  - *Alternatives*: Expose OpenAir features as a native PMTiles/MVT local server endpoint (rejected: too complex, unnecessary for low-frequency updates).

- **Decision 2: Dynamic Alert Highlighting via GeoJSON Properties**
  - *Rationale*: MapLibre allows data-driven styling. By writing a `"color"` property directly into the GeoJSON Feature and updating the GeoJSON when the `activeAlertLevel` changes, the map engine smoothly updates the polygon's appearance.
  - *Alternatives*: Using MapLibre feature-state APIs (rejected: Maplibre Flutter plugin support is limited/clunky for feature states). Updating layer paint properties globally (rejected: we only want to highlight specific polygons, not the entire layer).

- **Decision 3: Native SymbolStyleLayer for Airspace Labels**
  - *Rationale*: A `SymbolStyleLayer` bound to the `bf-airspace` source will automatically evaluate polygon centroids to place text fields (using the `"name"` property). MapLibre's built-in collision detection prevents text clumping.
  - *Alternatives*: Continue using Flutter `TextPainter` (rejected: requires manual projection and causes UI stutter).

## Risks / Trade-offs

- [Risk] **GeoJSON String Allocation Overhead**: Pushing thousands of airspace polygons into a single JSON string might cause momentary jank during file load.
  - *Mitigation*: Airspace files are loaded primarily during startup or offline setup, not continuously in flight. Updates to the GeoJSON for alerting (changing a single property) are rare (1-2 times a flight).
- [Risk] **MapLibre Layer Collision**: Native text labels might collide with important geographical POIs.
  - *Mitigation*: MapLibre automatically drops lower-priority colliding text. We will set the airspace labels to have a lower collision priority than the pilot marker and track data.
