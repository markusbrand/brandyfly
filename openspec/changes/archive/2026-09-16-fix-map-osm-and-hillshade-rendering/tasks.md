## 1. Style Alignment & Hillshade Layer

- [x] 1.1 Add `hillshade` raster-dem layer with NW 315° illumination and terrain source in `alpine_relief.json`
- [x] 1.2 Refactor landcover, landuse, water, and waterway layers in `alpine_relief.json` to match OpenMapTiles v3 classes and verify with schema inspection
- [x] 1.3 Refactor transportation hierarchy (highways, secondary roads, tracks, hiking paths, aerialways) in `alpine_relief.json` to match OpenMapTiles v3 schema
- [x] 1.4 Replace unfiltered `peak-omt-points` with zoom-constrained mountain peak labels displaying name and elevation in meters at zoom >= 11 in `alpine_relief.json`

## 2. Terrain Loopback Serving & Fallback

- [x] 2.1 Add `/terrain/{z}/{x}/{y}.png` endpoint to `LocalTileServer` with local `terrain.pmtiles` support, persistent disk caching, and online AWS Terrarium proxy fallback
- [x] 2.2 Update `MapLibreMapService.buildStyleJson` to maintain the terrain source pointing to `LocalTileServer` without dropping the hillshade layer in fallback mode
- [x] 2.3 Add unit tests in `local_tile_server_test.dart` and `maplibre_map_service_test.dart` to verify terrain endpoint serving, caching, and style compilation

## 3. Verification & OpenSpec Validation

- [x] 3.1 Run `flutter test` across `apps/mobile` to ensure all tests pass and style JSON is valid
- [x] 3.2 Run `npx openspec validate --all --strict` to ensure full OpenSpec change compliance
