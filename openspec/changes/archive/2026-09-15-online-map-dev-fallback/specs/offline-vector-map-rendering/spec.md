## MODIFIED Requirements

### Requirement: Local PMTiles vector tile rendering
The application SHALL render OpenStreetMap vector tiles from locally stored PMTiles archives using the native MapLibre GL engine on target mobile platforms (Android and iOS) and authentic mobile emulators without any network requests during flight when regional data is installed, served via an embedded loopback HTTP tile service. When regional PMTiles data is absent, the tile service SHALL transparently proxy and disk-cache online vector tiles from open providers in both simulation and real application environments, and the UI SHALL indicate whether offline data or an online preview is active.

#### Scenario: Offline map display from local PMTiles
- **WHEN** a PMTiles archive is present in the local region storage for the pilot's current location
- **THEN** the map renders vector tiles from the local archive with the configured style, without making any network requests

#### Scenario: Loopback HTTP tile server compatibility
- **WHEN** the MapLibre Native engine loads local PMTiles vector tiles on Android or iOS
- **THEN** tiles are resolved via an internal loopback HTTP server (`127.0.0.1`) serving tile payloads directly from local archives or cached proxy storage without requiring custom native URI scheme support, permitted by platform network security configurations on both Android and iOS

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
- **WHEN** the application is run in development, testing, or flight operations
- **THEN** the map is rendered through the native MapLibre GL mobile engine on Android (including x86_64 AVD emulator) or iOS (including iOS Simulator), without parallel non-native desktop canvas fallback painters
