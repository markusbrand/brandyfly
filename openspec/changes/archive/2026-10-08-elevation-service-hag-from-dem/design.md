## Context

The terrain-RGB PMTiles files downloaded per region (issue #84, #85) serve dual purpose: MapLibre renders hillshade from them visually, and this ElevationService decodes the same pixel data programmatically for HAG queries. The Copernicus GLO-30 DEM provides 30m horizontal resolution with ~4m vertical RMSE — more than sufficient for paragliding HAG where pilots are typically 100-3000m above ground.

## Architecture Decisions

### 1. Dart PMTiles reader

Implement a lightweight Dart library to read individual tiles from PMTiles archives:
- Parse the PMTiles v3 header and root/leaf directory entries
- Support random access to individual tiles by (z, x, y) coordinate
- Handle gzip/brotli tile compression
- Operate on `RandomAccessFile` for efficient seek-based reads without loading the entire archive

This reader is independent of MapLibre — it reads the same file but through Dart I/O, enabling programmatic pixel access.

### 2. Coordinate-to-pixel pipeline

```
Input: (lat, lon)
  |
  v
Tile coordinate: (z=12, x, y) via Web Mercator projection
  |
  v
PMTiles reader: load tile image bytes from archive
  |
  v
PNG decoder: decode to raw RGBA pixel buffer
  |
  v
Pixel coordinate: (px, py) within 256x256 tile
  |
  v
Bilinear interpolation: sample 4 nearest pixels
  |
  v
Terrain-RGB decode: elevation = -10000 + ((R*65536 + G*256 + B) * 0.1)
  |
  v
Output: elevation in meters (double)
```

Fixed zoom level 12 is used for all queries: this gives ~30m pixel resolution matching the Copernicus GLO-30 source data. Higher zoom levels would just interpolate the same data.

### 3. LRU tile cache

- Cache decoded pixel buffers (not compressed tile bytes) for instant re-query
- Cache size: 8 tiles (each 256x256x4 bytes = ~256 KB decoded = ~2 MB total cache)
- At zoom 12, each tile covers ~10x10 km — the cache holds ~80x80 km coverage
- At typical paragliding speeds (30-50 km/h), a single tile stays valid for 12-20 minutes
- Cache eviction: least-recently-used

### 4. ElevationService API

```dart
class ElevationService {
  /// Returns ground elevation in meters at the given coordinate,
  /// or null if no terrain data covers this location.
  Future<double?> getElevation(double lat, double lon);

  /// Returns elevations for a batch of coordinates (terrain profile).
  /// Null entries indicate missing coverage.
  Future<List<double?>> getElevationProfile(List<({double lat, double lon})> points);

  /// Registers a terrain PMTiles file for a downloaded region.
  void addTerrainSource(String regionId, String pmtilesPath);

  /// Removes a terrain source when a region is deleted.
  void removeTerrainSource(String regionId);
}
```

### 5. HAG integration

The flight telemetry pipeline calls `getElevation()` on each GPS update:

```
GPS update (lat, lon, gpsAlt) + barometric alt
  |
  v
ElevationService.getElevation(lat, lon) -> groundElev
  |
  v
HAG = barometricAlt - groundElev  (or null if no data)
  |
  v
HAG widget displays value
```

The `getElevation` call is asynchronous but fast enough (~sub-ms from cache) to not introduce perceivable latency. If a cache miss occurs, the previous HAG value is held until the new elevation resolves.

### 6. Terrain source discovery

ElevationService discovers available terrain PMTiles by scanning the region storage directory on startup and registering paths. When the RegionManagerService (issue #85) downloads or deletes a region, it notifies ElevationService to add/remove terrain sources dynamically.
