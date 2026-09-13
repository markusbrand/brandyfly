## Why

MapLibre Native on mobile platforms (specifically Android via `android-sdk-opengl` and iOS) does not support the custom `pmtiles://` URI scheme. When the mobile app passes a `pmtiles://` file URI to MapLibre, Android's native HTTP resource loader (`Mbgl-HttpRequest`) fails to parse the URI, causing all OpenStreetMap vector layers to fail silently and leaving the flight HUD on a blank beige background.

To deliver on BrandyFly's core offline-first flight navigation requirements, the application must provide an internal loopback tile server (`127.0.0.1:{ephemeral_port}`) and a seek-based PMTiles v3 reader in Dart. MapLibre can then request standard HTTP vector tiles (`http://127.0.0.1:{port}/tiles/{z}/{x}/{y}.pbf`) from local region archives (e.g. `alps-east/map.pmtiles`), with automatic online vector fallback when running in local development or outside downloaded regions.

## What Changes

- **Embedded Loopback Tile Server**: Implement `LocalTileServer` in `apps/mobile/lib/services/local_tile_server.dart` that binds to `InternetAddress.loopbackIPv4` on an ephemeral port and handles tile requests (`/tiles/{z}/{x}/{y}.pbf`) and TileJSON metadata (`/tiles.json`).
- **Dart PMTiles Reader**: Implement random-access seek-based PMTiles v3 reader in `apps/mobile/lib/services/pmtiles_reader.dart` that parses the 127-byte header, resolves tile coordinates to Hilbert IDs, looks up offsets in directory sections, and extracts tile payload bytes without loading the archive into memory.
- **Service Integration & Dynamic Style JSON**: Update `MapLibreMapService` to start `LocalTileServer`, register local region files, and compile style JSON source URLs to `http://127.0.0.1:{port}/tiles/{z}/{x}/{y}.pbf`.
- **Online & Overview Fallback**: If a requested tile is not present in local PMTiles (or when no region is downloaded during development), gracefully proxy to open vector tile providers (such as OpenFreeMap) or serve bundled overview data.
- **Lifecycle Management**: Ensure the loopback server starts on app initialization and shuts down cleanly on dispose.

### Non-Goals

- Writing a C++ or native Kotlin/Swift custom FileSource plugin inside MapLibre Native SDK (the pure Dart loopback server avoids native SDK alterations).
- Re-architecting regional archive packaging (remains standard PMTiles v3 with OpenMapTiles schema).
- Real-time online raster tile caching via HTTP proxies (vector tiles remain the primary format).

## Capabilities

### Modified Capabilities

- `offline-vector-map-rendering`: Update local tile resolution requirements to mandate loopback HTTP tile serving for MapLibre Native compatibility on Android and iOS, with seamless online vector fallback during development simulation.

## Impact

- **Affected Code**: `apps/mobile/lib/services/maplibre_map_service.dart`, `apps/mobile/lib/widgets/flight/map_widget.dart`, `apps/mobile/lib/main.dart`.
- **New Code**: `apps/mobile/lib/services/local_tile_server.dart`, `apps/mobile/lib/services/pmtiles_reader.dart`.
- **APIs/Dependencies**: No new external dependencies required; uses standard `dart:io` (`HttpServer`, `RandomAccessFile`), `dart:convert`, and existing `crypto` package.
- **Privacy & Safety**: Safe offline operation is maintained in flight; no pilot location or flight telemetry is transmitted.
- **Offline & Battery**: Loopback server runs exclusively on local host `127.0.0.1` with sub-millisecond seek times and minimal memory footprint.
- **Licensing**: Fully MIT-compliant; uses OpenStreetMap ODbL vector tile schema.
