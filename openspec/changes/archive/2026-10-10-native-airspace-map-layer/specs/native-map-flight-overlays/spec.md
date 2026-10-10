# Spec Delta

## MODIFIED Requirements

### Requirement: Map-synchronous flight overlays
The flight track, OpenAir airspace polygons, and the pilot marker SHALL be rendered as native MapLibre GeoJSON layers, so they remain geographically locked to the base map on every frame, including during camera motion, rotation, and zoom.

#### Scenario: No overlay swim during follow
- **WHEN** the center-locked camera moves and rotates continuously during flight
- **THEN** track vertices and airspace edges stay on the same geographic map features in every frame, with no visible offset relative to the base map

#### Scenario: Pinch and pan gestures
- **WHEN** the pilot pans or zooms the map
- **THEN** the track and airspace move together with the base map without lagging a frame behind

## ADDED Requirements

### Requirement: Dynamic native airspace highlighting
The native MapLibre airspace layers SHALL dynamically highlight the currently active proximity alert without requiring UI-thread projection or rendering. Highlight state is updated by pushing a new GeoJSON serialization or paint property to the native MapLibre controller.

#### Scenario: Airspace proximity alert highlight
- **WHEN** the airspace proximity alert state transitions to Level 2 (Warning) or Level 3 (Violation)
- **THEN** the native MapLibre airspace polygon for the affected airspace immediately renders with an updated highlight color (e.g., solid red stroke and high-opacity fill)
- **AND** the map does not drop frames or pause to manually recalculate geographical projections.

### Requirement: Native MapLibre airspace text labeling
The map SHALL render airspace names and classes using a native MapLibre `SymbolStyleLayer`, leveraging the engine's built-in collision detection to prevent text overlap with track data or other map features.

#### Scenario: Airspace label placement
- **WHEN** the map renders loaded OpenAir airspaces
- **THEN** the airspace name and class are drawn cleanly near the polygon centroid using native map fonts
- **AND** labels that would collide with the pilot marker or densely populated map features are automatically hidden by the MapLibre collision engine.
