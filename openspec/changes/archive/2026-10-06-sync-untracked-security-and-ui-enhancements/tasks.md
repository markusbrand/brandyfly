## Tasks

### 1. Loopback Tile Server CORS Protection
- [x] 1.1 Verify `LocalTileServer` omits `Access-Control-Allow-Origin: *` headers on responses
- [x] 1.2 Verify test in `local_tile_server_test.dart` asserting absence of wildcard CORS headers

### 2. Map Pipeline SSRF Prevention
- [x] 2.1 Verify URL prefix validation (`https://download.geofabrik.de/`) in `download_osm.py`
- [x] 2.2 Add unit test in `tools/map-pipeline/test_pipeline.py` testing rejection of untrusted URLs

### 3. Vertical Edge Bar Slender Slot Rendering
- [x] 3.1 Verify `vario_lift_sink_bar.dart` preserves vertical edge bar rendering when `tier == SizeTier.tiny`
- [x] 3.2 Add widget test in `apps/mobile/test/instrument_widgets_test.dart` asserting `verticalEdgeBar` renders graphic in tiny tier

### 4. Specification Synchronization & Validation
- [x] 4.1 Run OpenSpec strict validation across all changes and specs
- [x] 4.2 Verify all tests pass
