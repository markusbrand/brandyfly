# offline-vector-map-rendering Specification Delta

## MODIFIED Requirements

### Requirement: Local PMTiles vector tile rendering
The application SHALL render OpenStreetMap vector tiles from valid locally stored PMTiles v3 archives (>= 4,096 bytes) using the native MapLibre GL engine on Android and iOS without network requests during flight. When regional data is absent, an embedded loopback HTTP tile server without wildcard CORS headers SHALL serve overview or disk-cached online fallback tiles.

#### Scenario: Offline map display from local PMTiles
- **WHEN** a valid regional PMTiles archive (>= 4,096 bytes with a valid PMTiles v3 header) is present in the local region storage for the pilot's current location
- **THEN** the map renders vector tiles from the local archive with the configured style, without making any network requests

#### Scenario: Rejecting stub or truncated regional PMTiles archives
- **WHEN** a regional directory contains a `map.pmtiles` file smaller than 4,096 bytes or with an invalid PMTiles v3 header
- **THEN** the map service ignores the invalid regional archive, leaves the primary archive unset, and falls back to the overview archive and online tile proxy rather than claiming offline regional PMTiles coverage

#### Scenario: Loopback HTTP tile server compatibility
- **WHEN** the MapLibre Native engine loads local PMTiles vector tiles on Android or iOS
- **THEN** tiles are resolved via an internal loopback HTTP server (`127.0.0.1`) serving tile payloads directly from local archives or cached proxy storage without requiring custom native URI scheme support, permitted by platform network security configurations on both Android and iOS

#### Scenario: Restrictive loopback CORS policy
- **WHEN** an HTTP client queries the local loopback tile server health or tile endpoints
- **THEN** the server responses omit wildcard `Access-Control-Allow-Origin` headers to protect local tile assets from cross-origin browser extraction

#### Scenario: Development simulation vector fallback
- **WHEN** the application runs in local mock flight mode or development testing without a downloaded regional archive
- **THEN** vector tile requests gracefully fall back to an active open vector tile endpoint (OpenFreeMap snapshot) or bundled overview data, caching downloaded tiles locally so OpenStreetMap features render visibly on simulation displays

#### Scenario: No local PMTiles available (fallback)
- **WHEN** no downloaded region covers the pilot's current GPS coordinates
- **THEN** the map renders from the bundled low-zoom global overview PMTiles or online proxy cache and displays a visual indicator distinguishing whether an online preview or pure overview fallback without data is active

#### Scenario: Cached online tile reuse
- **WHEN** a vector tile has previously been fetched via online fallback and is requested again while offline or without regional PMTiles
- **THEN** the embedded tile server serves the cached tile from local disk storage without issuing duplicate network requests

#### Scenario: Disconnected fallback failure handling
- **WHEN** no regional PMTiles exist for the current coordinates and the device is disconnected from cellular or Wi-Fi networks
- **THEN** tile requests timeout in no more than 3 seconds, return HTTP 204 No Content, and the map displays the fallback overview tint without throwing unhandled exceptions or disrupting telemetry rendering

#### Scenario: Multiple overlapping regions
- **WHEN** multiple downloaded regions overlap at the pilot's location
- **THEN** the renderer uses the available data seamlessly without visual artifacts at region boundaries

#### Scenario: Native mobile execution target
- **WHEN** the application is run in development, testing, or release flight operations
- **THEN** the map is rendered through the native MapLibre GL mobile engine on Android (including x86_64 AVD emulator and arm64-v8a physical devices in release builds with R8 code shrinking enabled) or iOS (including iOS Simulator), without `PlatformException` or `NullPointerException` during platform view creation

#### Scenario: Android release build R8 code shrinking compatibility
- **WHEN** the Android application is compiled in release mode (`flutter build apk --release`) with R8 minification and shrinking active
- **THEN** ProGuard/R8 keep rules preserve all JNI-bridged Flutter platform view interfaces (`io.flutter.plugin.platform.**`, `io.flutter.embedding.engine.plugins.**`, `io.flutter.plugin.common.**`) and MapLibre native bridge classes (`com.github.josxha.maplibre.**`, `org.maplibre.**`), allowing the MapLibre platform view to mount and render vector and terrain tiles without throwing `NullPointerException` or `ClassNotFoundException`
