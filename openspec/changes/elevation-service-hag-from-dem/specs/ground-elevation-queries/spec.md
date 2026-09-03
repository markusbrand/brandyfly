## ADDED Requirements

### Requirement: Point elevation query from local DEM
The ElevationService SHALL return the ground elevation in meters for a given geographic coordinate by decoding terrain-RGB data from locally stored PMTiles archives.

#### Scenario: Coordinate within downloaded region
- **WHEN** `getElevation(lat, lon)` is called for a coordinate covered by a downloaded region's terrain PMTiles
- **THEN** the service returns the ground elevation in meters (WGS84 ellipsoidal height) within the accuracy of the Copernicus GLO-30 dataset (~30m horizontal, ~4m vertical RMSE)

#### Scenario: Coordinate outside downloaded regions
- **WHEN** `getElevation(lat, lon)` is called for a coordinate not covered by any downloaded terrain PMTiles
- **THEN** the service returns null without errors, and the calling code handles the absence gracefully

#### Scenario: Multiple overlapping regions
- **WHEN** multiple downloaded regions contain terrain data for the same coordinate
- **THEN** the service returns the elevation from any available region (deterministic, e.g. first match by region load order)

### Requirement: Telemetry-rate query performance
The ElevationService SHALL respond to elevation queries at the flight telemetry update rate without blocking the UI thread.

#### Scenario: Cached tile query
- **WHEN** the terrain tile containing the queried coordinate is already in the in-memory LRU cache
- **THEN** the query completes in under 1 millisecond

#### Scenario: Cache miss with disk read
- **WHEN** the terrain tile is not cached and must be read from the PMTiles archive on disk
- **THEN** the query completes in under 50 milliseconds and the tile is added to the LRU cache

#### Scenario: Sustained 10 Hz query rate
- **WHEN** elevation is queried at 10 Hz during active flight (pilot moving at typical paragliding speeds)
- **THEN** at most one cache miss occurs per ~12-20 minutes of flight (terrain tiles at zoom 12 cover ~10 km), and all other queries are served from cache

### Requirement: Terrain-RGB decoding
The service SHALL correctly decode Mapbox terrain-RGB encoding to obtain elevation values.

#### Scenario: Terrain-RGB pixel decoding
- **WHEN** a terrain tile pixel has RGB values (R, G, B)
- **THEN** the decoded elevation is calculated as: `elevation = -10000 + ((R * 256 * 256 + G * 256 + B) * 0.1)` meters

#### Scenario: Bilinear interpolation
- **WHEN** a queried coordinate falls between tile pixel centers
- **THEN** the service interpolates between the four nearest pixels using bilinear interpolation for smoother elevation values
