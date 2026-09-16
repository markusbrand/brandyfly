## MODIFIED Requirements

### Requirement: Hillshade terrain relief rendering
The application SHALL render hillshade terrain relief from Copernicus GLO-30 terrain-RGB raster DEM tiles stored in local PMTiles archives or cached loopback DEM proxy storage.

#### Scenario: Hillshade from local DEM
- **WHEN** a terrain PMTiles archive is present for the current map viewport
- **THEN** MapLibre renders a hillshade layer (illumination from NW 315 degrees, exaggeration factor 1.5) beneath the vector map layers, making mountain ridges, valleys, and cols visually distinct

#### Scenario: No terrain data available
- **WHEN** no terrain PMTiles archive covers the current viewport and no online proxy connection is available
- **THEN** the map renders without hillshade (flat background tint) without errors or blank areas

#### Scenario: Hillshade development simulation fallback
- **WHEN** the application runs in local mock flight mode or development without downloaded regional terrain archives
- **THEN** terrain tile requests to the embedded loopback tile server resolve from cached online raster DEM sources or an upstream terrarium endpoint, rendering visible hillshade relief in development environments

### Requirement: Alpine Relief map style
The application SHALL render maps using a custom "Alpine Relief" MapLibre style optimized for paragliding situational awareness conforming to the OpenMapTiles v3 schema.

#### Scenario: Style layer hierarchy
- **WHEN** the map is rendered with the Alpine Relief style
- **THEN** the visual prominence hierarchy is: (1) hillshade relief dominant, (2) hypsometric elevation color ramp (green valleys to brown rock to white peaks), (3) water bodies in blue, (4) major roads and aerialways as thin muted lines, (5) sparse labels (peak names with elevations at zoom >= 11, town/village names zoom-dependent), and no building outlines or generic POI icons

#### Scenario: Style bundled in app
- **WHEN** the app is installed or updated
- **THEN** the Alpine Relief style JSON is included in the app bundle and can be iterated without requiring region data re-downloads

#### Scenario: OpenMapTiles v3 schema compatibility
- **WHEN** vector tiles generated with OpenMapTiles v3 (Planetiler) or served by OpenFreeMap are loaded into the map engine
- **THEN** features in `landcover`, `landuse`, `water`, `waterway`, `transportation`, `mountain_peak`, and `place` layers match style layer filters and render visibly without cluttering the screen with unfiltered dots
