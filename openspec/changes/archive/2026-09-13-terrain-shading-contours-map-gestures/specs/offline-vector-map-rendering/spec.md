## MODIFIED Requirements

### Requirement: Hillshade terrain relief rendering
The application SHALL render hillshade terrain relief from Copernicus GLO-30 terrain-RGB raster DEM tiles stored in local PMTiles archives, with the hillshade layer defined in the Alpine Relief style JSON and rendered by the native MapLibre GL engine.

#### Scenario: Hillshade from local DEM
- **WHEN** a terrain PMTiles archive is present for the current map viewport
- **THEN** MapLibre renders a hillshade layer (illumination from NW 315 degrees, exaggeration factor configurable, shadow and highlight colors tuned for Alpine terrain) beneath the vector map layers, making mountain ridges, valleys, and cols visually distinct

#### Scenario: No terrain data available
- **WHEN** no terrain PMTiles archive covers the current viewport
- **THEN** the style builder removes the terrain source and hillshade layer from the generated style JSON, and the map renders without hillshade (flat background tint) without errors or blank areas

#### Scenario: Hillshade present in bundled style
- **WHEN** the Alpine Relief style JSON is loaded from the app bundle
- **THEN** the style contains a `hillshade` layer referencing the `terrain` raster-dem source, positioned in the layer stack after the background and before landuse layers

### Requirement: Flight overlay preservation
The application SHALL render all existing flight overlays (airspace polygons, flight track, thermal markers, pilot marker, compass, HUD controls) on top of the MapLibre base map with correct geographic synchronization to the native MapLibre GL camera.

#### Scenario: Overlay rendering on MapLibre
- **WHEN** the map is displayed during flight or replay
- **THEN** airspace polygons (CTR/TMA), GPS breadcrumb flight track (color-coded by climb rate), thermal updraft markers, pilot position marker with heading rotation, compass indicator, zoom controls, and scale bar are rendered correctly over the MapLibre vector tile base map

#### Scenario: Overlay geographic synchronization during pan
- **WHEN** the pilot pans the map by dragging
- **THEN** the flight overlays (track, airspace, thermals, pilot marker) move in exact lockstep with the MapLibre base map tiles, with no visible desynchronization or drift between the overlay layer and the underlying map

#### Scenario: Overlay geographic synchronization during pinch-zoom
- **WHEN** the pilot pinch-zooms the map
- **THEN** the flight overlays scale and reposition correctly in sync with the MapLibre camera zoom level change

#### Scenario: Overlay interaction unaffected
- **WHEN** the pilot interacts with zoom (+/-), recenter, or pans the map
- **THEN** overlays respond identically to the current flutter_map behavior (zoom steppers, auto-recenter toggle, pan-to-dismiss-center)

## ADDED Requirements

### Requirement: Native map gesture handling
The application SHALL delegate all map touch gestures (pan, pinch-zoom, two-finger rotate) to the native MapLibre GL engine instead of intercepting them in a Flutter GestureDetector.

#### Scenario: Single-finger pan moves the map
- **WHEN** the pilot drags one finger on the map surface
- **THEN** the MapLibre camera pans to follow the drag, moving both the base map tiles and the flight overlays together, without moving only the overlay or only the cursor

#### Scenario: Pinch-to-zoom
- **WHEN** the pilot performs a two-finger pinch gesture on the map
- **THEN** the MapLibre camera zooms in or out smoothly, and both the base map and flight overlays reflect the new zoom level

#### Scenario: Two-finger rotate
- **WHEN** the pilot performs a two-finger rotation gesture on the map
- **THEN** the MapLibre camera bearing changes, rotating both the base map and flight overlays together

#### Scenario: Auto-recenter after user pan
- **WHEN** the pilot pans the map away from the current pilot position via a touch gesture
- **THEN** the map automatically re-centers on the pilot position after 6 seconds of no further user gesture input, and the center-on-pilot mode is re-engaged

#### Scenario: Programmatic camera move does not trigger recenter timer
- **WHEN** the map camera is moved programmatically (e.g., auto-recenter, pilot position update)
- **THEN** the recenter timer is not started or reset, and the center-on-pilot state is not changed
