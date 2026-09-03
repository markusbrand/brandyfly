## Summary

Replace `flutter_map` with MapLibre GL for offline-first vector tile rendering from local PMTiles archives, enabling full style control, hillshade terrain visualization, and the foundation for region-based offline map downloads.

## Problem Statement

The current `flutter_map` integration renders raster tiles fetched live from OpenStreetMap / OpenTopoMap / CARTO tile servers. Offline capability is limited to an opportunistic view-and-cache mechanism — only tiles the pilot has previously scrolled over are available offline. There is no control over the visual style (colors, label density, hillshade), and no path to local elevation data queries for height-above-ground calculation. Raster tile bulk downloading also violates OSM tile usage policy.

## Proposed Solution

1. **MapLibre GL Integration**: Replace `flutter_map` with the MapLibre Flutter package (specific package selected by benchmark #17) for hardware-accelerated vector tile rendering with full style control.
2. **Local PMTiles Rendering**: Render vector map tiles from locally stored PMTiles archives rather than fetching from remote tile servers. Include a bundled low-zoom (~5 MB) global overview PMTiles for fallback when outside downloaded regions.
3. **Hillshade from Terrain-RGB DEM**: Render hillshade relief using MapLibre's `RasterDemSource` / `HillshadeLayer` from Copernicus GLO-30 terrain-RGB raster tiles stored in a separate PMTiles archive per region.
4. **"Alpine Relief" Map Style**: Ship a custom MapLibre style JSON optimized for paragliding: dominant hillshade, hypsometric elevation color ramp, minimal roads, sparse labels (peaks + towns), muted palette — designed to make mountain terrain instantly readable at flying speed.
5. **Fallback Rendering**: When the pilot is outside any downloaded region, render the bundled low-zoom vector overview (no hillshade) with a "No offline map data" indicator.
6. **Preserve Flight Overlays**: Maintain all existing flight overlay layers (airspace polygons, flight track polyline, thermal markers, pilot position marker with heading rotation) on top of the new MapLibre base map.

## Prerequisites

- **Benchmark #17** (`benchmark-offline-map-engine`, issue #17) must resolve with a selected MapLibre Flutter package before implementation begins.

## Goals

- Render vector map tiles from local PMTiles files with zero network dependency during flight.
- Display hillshade terrain relief from Copernicus DEM GLO-30 terrain-RGB data for instant mountain identification.
- Provide a clean, paragliding-optimized "Alpine Relief" visual style with full control over colors, label density, and terrain emphasis.
- Maintain all existing flight overlay functionality (airspace, track, thermals, pilot marker, compass, HUD).
- Graceful fallback to low-zoom vector overview when outside downloaded regions.
- Comply with OSM data licensing (ODbL) and Copernicus DEM licensing (CC-BY-4.0) with proper attribution.

## Non-Goals

- Building the PMTiles data generation pipeline (separate change: `offline-map-data-pipeline`).
- Implementing region download/update/delete management UI (separate change: `offline-region-download-manager`).
- Implementing the ElevationService for HAG queries from DEM data (separate change: `elevation-service-hag-from-dem`).
- Supporting online raster tile fallback — offline vector is the primary rendering path.
- 3D terrain mesh rendering.

## Capabilities

### New Capabilities

- `offline-vector-map-rendering`: Renders OpenStreetMap vector tiles from local PMTiles archives using MapLibre GL with a paragliding-optimized style and hillshade terrain relief.

### Modified Capabilities

- `map-widget-rendering`: Replaces `flutter_map` TileLayer-based raster rendering with MapLibre GL vector tile rendering while preserving all flight overlay layers and interactive controls.

## Impact

- **Dependencies**: Removes `flutter_map` (^8.3.1); adds MapLibre Flutter package (TBD by benchmark), PMTiles support. App binary size increases ~15-30 MB per platform due to MapLibre native libraries.
- **Breaking**: `MapTileStyleConfig` and `BrandyFlyTileProvider` / `BrandyFlyTileCacheService` are replaced by MapLibre style JSON and local PMTiles file provider.
- **Testing**: Existing `map_widget_integration_test.dart` and `map_tile_service_test.dart` must be rewritten for MapLibre.
- **Licensing**: Requires visible attribution for OpenStreetMap (ODbL) and Copernicus DEM (CC-BY-4.0).
