# offline-vector-map-rendering Specification

## Purpose

Provides local-first, offline vector map rendering and terrain hillshade visualization using MapLibre GL and PMTiles archives for paragliding navigation.

## Requirements

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

### Requirement: Hillshade terrain relief rendering
The application SHALL render hillshade terrain relief from Copernicus GLO-30 terrain-RGB raster DEM tiles stored in local PMTiles archives or cached loopback DEM proxy storage.

#### Scenario: Hillshade from local DEM
- **WHEN** a terrain PMTiles archive is present for the current map viewport
- **THEN** MapLibre renders a hillshade layer (illumination from NW 315 degrees, exaggeration factor 1.5) beneath the vector map layers, making mountain ridges, valleys, and cols visually distinct

#### Scenario: No terrain data available
- **WHEN** no terrain PMTiles archive covers the current viewport and no online proxy connection is available
- **THEN** the map renders without hillshade (flat background tint) without errors or blank areas

#### Scenario: Hillshade development simulation fallback
- **WHEN** the application runs in local mock flight mode or development without downloaded regional terrain archives
- **THEN** terrain tile requests to the embedded loopback tile server resolve from cached online raster DEM sources or an upstream terrarium endpoint, rendering visible hillshade relief in development environments

### Requirement: Alpine Relief map style
The application SHALL render maps using a custom "Alpine Relief" MapLibre style optimized for paragliding situational awareness conforming to the OpenMapTiles v3 schema.

#### Scenario: Style layer hierarchy
- **WHEN** the map is rendered with the Alpine Relief style
- **THEN** the visual prominence hierarchy is: (1) hillshade relief dominant, (2) hypsometric elevation color ramp (green valleys to brown rock to white peaks), (3) water bodies in blue, (4) major roads and aerialways as thin muted lines, (5) sparse labels (peak names with elevations at zoom >= 11, town/village names zoom-dependent), and no building outlines or generic POI icons

#### Scenario: Style bundled in app
- **WHEN** the app is installed or updated
- **THEN** the Alpine Relief style JSON is included in the app bundle and can be iterated without requiring region data re-downloads

#### Scenario: OpenMapTiles v3 schema compatibility
- **WHEN** vector tiles generated with OpenMapTiles v3 (Planetiler) or served by OpenFreeMap are loaded into the map engine
- **THEN** features in `landcover`, `landuse`, `water`, `waterway`, `transportation`, `mountain_peak`, and `place` layers match style layer filters and render visibly without cluttering the screen with unfiltered dots

### Requirement: Flight overlay preservation
The application SHALL render all existing flight overlays (airspace polygons, flight track, thermal markers, pilot marker, compass, HUD controls) on top of the MapLibre base map. Mock airspace restriction polygons and thermal updraft markers SHALL be anchored to static geographical coordinates on the map rather than following the pilot's position during flight.

#### Scenario: Overlay rendering on MapLibre
- **WHEN** the map is displayed during flight or replay
- **THEN** airspace polygons (CTR/TMA), GPS breadcrumb flight track (color-coded by climb rate), thermal updraft markers, pilot position marker with heading rotation, compass indicator, zoom controls, and scale bar are rendered correctly over the MapLibre vector tile base map

#### Scenario: Static geographic coordinates for mock airspace and thermals
- **WHEN** the pilot maneuvers or flies across the map
- **THEN** mock airspace restriction polygons and thermal updraft markers remain anchored at their fixed geographical positions on Earth, and do not translate with the glider's movement

#### Scenario: Overlay interaction unaffected
- **WHEN** the pilot interacts with zoom (+/-), recenter, or pans the map
- **THEN** overlays respond identically to the current flutter_map behavior (zoom steppers, auto-recenter toggle, pan-to-dismiss-center)

### Requirement: MapLibre replaces flutter_map
The application SHALL use MapLibre GL as the sole map rendering engine, removing the flutter_map dependency.

#### Scenario: Clean dependency removal
- **WHEN** the migration is complete
- **THEN** `flutter_map` and its tile caching infrastructure (`BrandyFlyTileProvider`, `BrandyFlyTileCacheService`, `MapTileStyleConfig`) are removed from the codebase, and `pubspec.yaml` no longer lists `flutter_map` as a dependency

### Requirement: Licensing attribution
The application SHALL display proper attribution for OpenStreetMap data and Copernicus DEM data.

#### Scenario: Attribution visible on map
- **WHEN** the map is displayed
- **THEN** attribution text for OpenStreetMap contributors (ODbL) and Copernicus GLO-30 (CC-BY-4.0, ESA) is visible or accessible via an attribution button
