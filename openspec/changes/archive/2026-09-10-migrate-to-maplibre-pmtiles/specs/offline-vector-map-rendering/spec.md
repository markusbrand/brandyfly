## ADDED Requirements

### Requirement: Local PMTiles vector tile rendering
The application SHALL render OpenStreetMap vector tiles from locally stored PMTiles archives using MapLibre GL without any network requests during flight.

#### Scenario: Offline map display from local PMTiles
- **WHEN** a PMTiles archive is present in the local region storage for the pilot's current location
- **THEN** the map renders vector tiles from the local archive with the configured style, without making any network requests

#### Scenario: No local PMTiles available (fallback)
- **WHEN** no downloaded region covers the pilot's current GPS coordinates
- **THEN** the map renders from the bundled low-zoom global overview PMTiles (no hillshade) and displays a visual indicator that offline map data is not available for this area

#### Scenario: Multiple overlapping regions
- **WHEN** multiple downloaded regions overlap at the pilot's location
- **THEN** the renderer uses the available data seamlessly without visual artifacts at region boundaries

### Requirement: Hillshade terrain relief rendering
The application SHALL render hillshade terrain relief from Copernicus GLO-30 terrain-RGB raster DEM tiles stored in local PMTiles archives.

#### Scenario: Hillshade from local DEM
- **WHEN** a terrain PMTiles archive is present for the current map viewport
- **THEN** MapLibre renders a hillshade layer (illumination from NW 315 degrees, exaggeration factor 1.5) beneath the vector map layers, making mountain ridges, valleys, and cols visually distinct

#### Scenario: No terrain data available
- **WHEN** no terrain PMTiles archive covers the current viewport
- **THEN** the map renders without hillshade (flat background tint) without errors or blank areas

### Requirement: Alpine Relief map style
The application SHALL render maps using a custom "Alpine Relief" MapLibre style optimized for paragliding situational awareness.

#### Scenario: Style layer hierarchy
- **WHEN** the map is rendered with the Alpine Relief style
- **THEN** the visual prominence hierarchy is: (1) hillshade relief dominant, (2) hypsometric elevation color ramp (green valleys to brown rock to white peaks), (3) water bodies in blue, (4) major roads only as thin muted lines, (5) sparse labels (peak names with elevations, town/village names zoom-dependent), and no building outlines or POI icons

#### Scenario: Style bundled in app
- **WHEN** the app is installed or updated
- **THEN** the Alpine Relief style JSON is included in the app bundle and can be iterated without requiring region data re-downloads

### Requirement: Flight overlay preservation
The application SHALL render all existing flight overlays (airspace polygons, flight track, thermal markers, pilot marker, compass, HUD controls) on top of the MapLibre base map.

#### Scenario: Overlay rendering on MapLibre
- **WHEN** the map is displayed during flight or replay
- **THEN** airspace polygons (CTR/TMA), GPS breadcrumb flight track (color-coded by climb rate), thermal updraft markers, pilot position marker with heading rotation, compass indicator, zoom controls, and scale bar are rendered correctly over the MapLibre vector tile base map

#### Scenario: Overlay interaction unaffected
- **WHEN** the pilot interacts with zoom (+/-), recenter, or pans the map
- **THEN** overlays respond identically to the current flutter_map behavior (zoom steppers, auto-recenter toggle, pan-to-dismiss-center)

### Requirement: MapLibre replaces flutter_map
The application SHALL use MapLibre GL as the sole map rendering engine, removing the flutter_map dependency.

#### Scenario: Clean dependency removal
- **WHEN** the migration is complete
- **THEN** `flutter_map` and its tile caching infrastructure (`BrandyFlyTileProvider`, `BrandyFlyTileCacheService`, `MapTileStyleConfig`) are removed from the codebase, and `pubspec.yaml` no longer lists `flutter_map` as a dependency

### Requirement: Licensing attribution
The application SHALL display proper attribution for OpenStreetMap data and Copernicus DEM data.

#### Scenario: Attribution visible on map
- **WHEN** the map is displayed
- **THEN** attribution text for OpenStreetMap contributors (ODbL) and Copernicus GLO-30 (CC-BY-4.0, ESA) is visible or accessible via an attribution button
