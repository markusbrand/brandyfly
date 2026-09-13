## Context

BrandyFly currently uses `flutter_map` v8.3.1 with raster XYZ tiles from public tile servers and an opportunistic disk cache. This works for development but fails the core local-first requirement: pilots cannot rely on having the right map tiles cached when they launch into areas with no cell coverage. The benchmark change (#17) is evaluating `maplibre` vs `maplibre_gl` Flutter packages for native vector tile rendering.

## Architecture Decisions

### 1. MapLibre GL as sole map engine

Replace `flutter_map` entirely with the MapLibre Flutter package selected by benchmark #17. MapLibre provides hardware-accelerated vector tile rendering with native support for:
- Local PMTiles file sources (no tile server needed)
- `RasterDemSource` + `HillshadeLayer` for terrain relief
- Full style control via JSON style specification
- Smooth zoom/rotation/tilt with GPU rendering

### 2. Dual PMTiles file architecture per region

Each downloaded region consists of two PMTiles files:
- `map.pmtiles`: Vector tiles (OpenMapTiles schema) containing roads, water, landuse, place names, POIs. Zoom levels 0-14 with MapLibre overzoom beyond.
- `terrain.pmtiles`: Raster terrain-RGB DEM tiles (Copernicus GLO-30). Zoom levels 0-12 at 30m resolution. Used by MapLibre for hillshade rendering, and separately by ElevationService (future change) for HAG queries.

File storage location: `{appSupportDir}/regions/{region-id}/`

### 3. Bundled low-zoom fallback

A ~5 MB global overview PMTiles (vector, zoom 0-6) is bundled in the app assets. When the pilot is outside any downloaded region, MapLibre renders from this fallback — providing continent/country outlines, major water bodies, and basic landmass without hillshade. A translucent overlay badge indicates "No offline data — download a region for terrain detail."

### 4. Alpine Relief style (MapLibre JSON)

A custom MapLibre style JSON bundled in `assets/map_styles/alpine_relief.json`:

Layer stack (bottom to top):
1. `background`: Warm grey (#f0ece4)
2. `hillshade`: From terrain.pmtiles RasterDemSource, illumination azimuth 315, altitude 45, exaggeration 1.5
3. `hypsometric-tint`: Semi-transparent elevation color ramp via `fill-color` interpolated by zoom/altitude (green valleys, brown alpine, grey rock, white snow)
4. `water`: Blue polygons + river lines
5. `landuse-forest`: Subtle green-tinted fill
6. `roads-major`: Thin (#999), only motorway/trunk/primary, low opacity
7. `peaks`: Triangle marker + label "{name} {elevation}m"
8. `place-labels`: Town/city names, zoom-dependent density

Flight overlays (airspace, track, thermals, pilot) are added as MapLibre layers on top of the style, or rendered as Flutter widgets overlaid on the MapLibre widget.

### 5. MapWidget refactoring

`MapWidget` is refactored to:
- Use the MapLibre Flutter widget instead of `FlutterMap`
- Load PMTiles from local file paths via MapLibre's source configuration
- Apply the Alpine Relief style JSON
- Add flight overlay layers (polylines, polygons, markers) via MapLibre's programmatic layer API or Flutter overlay widgets
- Preserve all existing interactions (zoom buttons, recenter, pan, compass)

### 6. Migration of overlay layers

| Current (flutter_map) | New (MapLibre) |
|---|---|
| `TileLayer` | PMTiles source + Alpine Relief style |
| `PolylineLayer` (contours) | Removed (hillshade replaces synthetic contours) |
| `MarkerLayer` (peaks) | Replaced by style-driven peak labels from vector data |
| `PolygonLayer` (airspace) | MapLibre `FillLayer` / `LineLayer` or Flutter overlay |
| `PolylineLayer` (track) | MapLibre `LineLayer` with GeoJSON source |
| `MarkerLayer` (thermals) | Flutter overlay markers |
| `MarkerLayer` (pilot) | Flutter overlay marker with rotation |

### 7. Removed components

- `BrandyFlyTileProvider` (raster network tile provider)
- `BrandyFlyTileCacheService` (md5-based disk cache)
- `MapTileStyleConfig` (raster tile URL configuration)
- Synthetic contour polyline builder (`_buildContourPolylines`)
- Hardcoded peak marker builder (`_buildPeakMarkers`) — replaced by vector tile data
