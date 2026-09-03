## Tasks

### Blocked: Resolve engine selection
- [ ] Wait for benchmark #17 to complete and select the MapLibre Flutter package (`maplibre` or `maplibre_gl`)

### MapLibre integration
- [ ] Add selected MapLibre Flutter package to `pubspec.yaml`, remove `flutter_map` and `latlong2`
- [ ] Verify PMTiles local file:// source support in the selected MapLibre package on Android, iOS, and Linux
- [ ] Create `MapLibreMapService` to manage MapLibre controller lifecycle, style loading, and source configuration
- [ ] Implement local PMTiles source configuration (vector map + terrain DEM from region file paths)

### Alpine Relief style
- [ ] Create `assets/map_styles/alpine_relief.json` MapLibre style with hillshade, hypsometric tints, water, roads, peak labels, place labels
- [ ] Configure `RasterDemSource` for Copernicus terrain-RGB tiles from local terrain.pmtiles
- [ ] Configure `HillshadeLayer` (azimuth 315, altitude 45, exaggeration 1.5)
- [ ] Tune hypsometric color ramp for Alpine terrain (green, brown, grey, white progression)
- [ ] Test style rendering at zoom levels 6-16 with representative Alpine data

### Bundled fallback
- [ ] Generate a ~5 MB global overview PMTiles (vector, zoom 0-6) from Natural Earth or low-zoom OSM extract
- [ ] Bundle fallback PMTiles in `assets/map_data/`
- [ ] Implement fallback detection: if no region covers current viewport, use bundled overview
- [ ] Add "No offline data" translucent badge overlay when rendering from fallback

### MapWidget refactoring
- [ ] Rewrite `MapWidget` to use MapLibre Flutter widget instead of `FlutterMap`
- [ ] Port zoom controls (zoom in/out buttons, current zoom tracking)
- [ ] Port auto-recenter and manual pan behavior
- [ ] Port compass indicator with track-up / north-up rotation
- [ ] Port scale bar and altitude/speed HUD overlay

### Flight overlay migration
- [ ] Migrate airspace polygon rendering (CTR/TMA) to MapLibre FillLayer or Flutter overlay
- [ ] Migrate GPS breadcrumb flight track to MapLibre LineLayer with GeoJSON source (color-coded by climb rate)
- [ ] Migrate thermal updraft markers to Flutter overlay
- [ ] Migrate pilot position marker with heading rotation to Flutter overlay
- [ ] Remove synthetic contour polylines (replaced by hillshade)
- [ ] Remove hardcoded peak markers (replaced by vector tile peak data)

### Cleanup
- [ ] Remove `BrandyFlyTileProvider`, `BrandyFlyTileCacheService`, `MapTileStyleConfig` from `map_tile_service.dart`
- [ ] Update `MapWidgetStyle` enum to reflect new style options (Alpine Relief as primary)
- [ ] Update `ThermalMapWidget` to use MapLibre (if applicable)
- [ ] Remove `flutter_map` related test files and create MapLibre equivalents
- [ ] Update THIRD_PARTY_DATA.md with Copernicus DEM attribution
