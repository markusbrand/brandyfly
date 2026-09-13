## Tasks

### Blocked: Resolve engine selection
- [x] Wait for benchmark #17 to complete and select the MapLibre Flutter package (`maplibre` or `maplibre_gl`)

### MapLibre integration
- [x] Add selected MapLibre Flutter package to `pubspec.yaml`, remove `flutter_map` and `latlong2`
- [x] Verify PMTiles local file:// source support in the selected MapLibre package on Android, iOS, and Linux
- [x] Create `MapLibreMapService` to manage MapLibre controller lifecycle, style loading, and source configuration
- [x] Implement local PMTiles source configuration (vector map + terrain DEM from region file paths)

### Alpine Relief style
- [x] Create `assets/map_styles/alpine_relief.json` MapLibre style with hillshade, hypsometric tints, water, roads, peak labels, place labels
- [x] Configure `RasterDemSource` for Copernicus terrain-RGB tiles from local terrain.pmtiles
- [x] Configure `HillshadeLayer` (azimuth 315, altitude 45, exaggeration 1.5)
- [x] Tune hypsometric color ramp for Alpine terrain (green, brown, grey, white progression)
- [x] Test style rendering at zoom levels 6-16 with representative Alpine data

### Bundled fallback
- [x] Generate a ~5 MB global overview PMTiles (vector, zoom 0-6) from Natural Earth or low-zoom OSM extract
- [x] Bundle fallback PMTiles in `assets/map_data/`
- [x] Implement fallback detection: if no region covers current viewport, use bundled overview
- [x] Add "No offline data" translucent badge overlay when rendering from fallback

### MapWidget refactoring
- [x] Rewrite `MapWidget` to use MapLibre Flutter widget instead of `FlutterMap`
- [x] Port zoom controls (zoom in/out buttons, current zoom tracking)
- [x] Port auto-recenter and manual pan behavior
- [x] Port compass indicator with track-up / north-up rotation
- [x] Port scale bar and altitude/speed HUD overlay

### Flight overlay migration
- [x] Migrate airspace polygon rendering (CTR/TMA) to MapLibre FillLayer or Flutter overlay
- [x] Migrate GPS breadcrumb flight track to MapLibre LineLayer with GeoJSON source (color-coded by climb rate)
- [x] Migrate thermal updraft markers to Flutter overlay
- [x] Migrate pilot position marker with heading rotation to Flutter overlay
- [x] Remove synthetic contour polylines (replaced by hillshade)
- [x] Remove hardcoded peak markers (replaced by vector tile peak data)

### Cleanup
- [x] Remove `BrandyFlyTileProvider`, `BrandyFlyTileCacheService`, `MapTileStyleConfig` from `map_tile_service.dart`
- [x] Update `MapWidgetStyle` enum to reflect new style options (Alpine Relief as primary)
- [x] Update `ThermalMapWidget` to use MapLibre (if applicable)
- [x] Remove `flutter_map` related test files and create MapLibre equivalents
- [x] Update THIRD_PARTY_DATA.md with Copernicus DEM attribution
