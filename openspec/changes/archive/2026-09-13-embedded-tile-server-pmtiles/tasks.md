## 1. PMTilesReader Implementation

- [x] 1.1 Implement seek-based binary PMTiles v3 reader in `apps/mobile/lib/services/pmtiles_reader.dart` supporting header decoding, Hilbert tile ID resolution, directory searching, and payload extraction.
- [x] 1.2 Write unit tests in `apps/mobile/test/services/pmtiles_reader_test.dart` verifying header parsing, Hilbert tile math, seek-based tile extraction, and graceful error handling on corrupt archives, and verify with `flutter test test/services/pmtiles_reader_test.dart`.

## 2. LocalTileServer Loopback Service

- [x] 2.1 Implement `LocalTileServer` in `apps/mobile/lib/services/local_tile_server.dart` binding to `InternetAddress.loopbackIPv4` on port 0, serving `/tiles/{z}/{x}/{y}.pbf` with gzip headers and online vector tile fallback during simulation.
- [x] 2.2 Write unit tests in `apps/mobile/test/services/local_tile_server_test.dart` verifying loopback port allocation, tile response headers, local PMTiles serving, and fallback response behavior, and verify with `flutter test test/services/local_tile_server_test.dart`.

## 3. MapLibreMapService Integration

- [x] 3.1 Update `MapLibreMapService` in `apps/mobile/lib/services/maplibre_map_service.dart` to initialize `LocalTileServer`, register local region files, and compile vector source tiles URL to `http://127.0.0.1:{port}/tiles/{z}/{x}/{y}.pbf`.
- [x] 3.2 Update `MapWidget` in `apps/mobile/lib/widgets/flight/map_widget.dart` and `main.dart` to ensure clean startup and shutdown lifecycle for the local tile server.
- [x] 3.3 Verify existing service tests in `apps/mobile/test/services/maplibre_map_service_test.dart` and widget tests pass cleanly with `flutter test`.

## 4. End-to-End Android Simulation Verification

- [x] 4.1 Run static analysis (`dart analyze`) across the mobile package to verify zero errors and warnings.
- [x] 4.2 Run the updated application on the Android emulator (`sdk gphone64 x86_64`) in mock flight simulation mode.
- [x] 4.3 Pull up the sample walkthrough replay session (*Krippenstein - Bad Aussee*), capture screenshots, and autonomously verify that OpenStreetMap vector features (water, roads, peaks, terrain) render visibly beneath the flight HUD.
- [x] 4.4 Validate OpenSpec change integrity with `npx openspec validate --all --strict`.
