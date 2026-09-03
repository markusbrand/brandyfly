## Summary

Add an ElevationService that queries ground elevation from locally stored Copernicus DEM terrain-RGB PMTiles, enabling accurate height-above-ground (HAG) calculation during flight by subtracting ground elevation from the barometric/GPS altitude.

## Problem Statement

The app has a `hag` (height above ground) widget type in the UI configuration, but no actual ground elevation data source. Without DEM data, HAG cannot be computed accurately — it would require either a hardcoded launch site elevation or internet-dependent elevation API queries, neither of which work reliably during flight. The terrain-RGB PMTiles files downloaded as part of offline regions (issues #84 and #85) contain the elevation data needed, but it must be decoded and queried programmatically — separate from MapLibre's visual hillshade rendering.

## Proposed Solution

1. **Dart PMTiles Reader**: Implement a Dart library to read raster tiles from PMTiles archives by tile coordinates, enabling direct access to terrain-RGB pixel data without going through MapLibre's rendering pipeline.
2. **ElevationService**: A service that accepts a geographic coordinate (lat, lon) and returns the ground elevation in meters by decoding the terrain-RGB pixel value at that location from the locally stored terrain PMTiles.
3. **In-Memory Tile Cache**: An LRU cache of recently decoded terrain tiles to ensure queries at telemetry rate (1-10 Hz) are served from memory without repeated disk reads.
4. **HAG Integration**: Wire the ElevationService into the flight telemetry pipeline so the existing `hag` widget displays live height-above-ground computed as `barometric_altitude - ground_elevation`.
5. **Terrain Profile** (stretch): Optionally expose a batch query API for computing elevation profiles along a flight track or planned route.

## Prerequisites

- **Issue #84** (`migrate-to-maplibre-pmtiles`) must be complete — terrain PMTiles files must be stored locally per region.
- **Issue #85** (`offline-region-download-manager`) should be functional — regions with terrain data must be downloadable.

## Goals

- Provide accurate ground elevation queries at any geographic coordinate covered by downloaded regions, with sub-millisecond response time from cached tiles.
- Enable live HAG display during flight at telemetry update rate (1-10 Hz).
- Reuse the same terrain PMTiles files already downloaded for hillshade rendering (no additional data download).
- Graceful degradation: return null when no terrain data covers the queried location (outside downloaded regions).

## Non-Goals

- Online elevation API fallback (this is an offline-first service).
- Sub-meter elevation accuracy (Copernicus GLO-30 at 30m resolution is sufficient for flight HAG).
- 3D terrain mesh or cross-section rendering.
- Terrain collision warnings (may be a future feature built on this service).

## Capabilities

### New Capabilities

- `ground-elevation-queries`: Query ground elevation at arbitrary geographic coordinates from locally stored DEM data for HAG calculation and terrain awareness.

### Modified Capabilities

- `hag-widget-display`: The existing HAG widget receives real ground elevation data from the ElevationService instead of placeholder values.

## Impact

- **New code**: Dart PMTiles reader library, ElevationService, LRU tile cache.
- **Memory**: LRU cache of ~4-8 decoded terrain tiles in RAM (~10-20 MB peak).
- **Performance**: Sub-millisecond queries from cache; ~5-20 ms on cache miss (disk read + PNG decode).
- **No additional storage**: Reuses terrain PMTiles already downloaded by the region manager.
