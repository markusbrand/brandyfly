## MODIFIED Requirements

### Requirement: Local PMTiles vector tile rendering
The application SHALL render OpenStreetMap vector tiles from locally stored PMTiles archives using the native MapLibre GL engine on target mobile platforms (Android and iOS) and authentic mobile emulators without any network requests during flight.

#### Scenario: Offline map display from local PMTiles
- **WHEN** a PMTiles archive is present in the local region storage for the pilot's current location
- **THEN** the map renders vector tiles from the local archive with the configured style, without making any network requests

#### Scenario: No local PMTiles available (fallback)
- **WHEN** no downloaded region covers the pilot's current GPS coordinates
- **THEN** the map renders from the bundled low-zoom global overview PMTiles (no hillshade) and displays a visual indicator that offline map data is not available for this area

#### Scenario: Multiple overlapping regions
- **WHEN** multiple downloaded regions overlap at the pilot's location
- **THEN** the renderer uses the available data seamlessly without visual artifacts at region boundaries

#### Scenario: Native mobile execution target
- **WHEN** the application is run in development, testing, or flight operations
- **THEN** the map is rendered through the native MapLibre GL mobile engine on Android (including x86_64 AVD emulator) or iOS (including iOS Simulator), without parallel non-native desktop canvas fallback painters
