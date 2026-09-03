## ADDED Requirements

### Requirement: OpenStreetMap Tile Background
The application SHALL render standard OpenStreetMap and OpenTopoMap raster tiles as the map background in `MapWidget` using `flutter_map`.

#### Scenario: Online tile rendering
- **WHEN** network connectivity is available and the map is displayed
- **THEN** the map displays OpenStreetMap raster tiles centered on the pilot's geographic coordinates with valid attribution.

#### Scenario: User-Agent policy compliance
- **WHEN** the application requests map tiles from tile servers
- **THEN** it sends a descriptive `User-Agent` header identifying the application (`BrandyFly/0.1.0`).

### Requirement: Offline Tile Caching
The application SHALL cache downloaded map tiles to local disk storage and serve them without internet connectivity.

#### Scenario: Offline flight operation
- **WHEN** the device is offline or in airplane mode in flight
- **THEN** cached map tiles are displayed seamlessly without errors or interruptions to flight telemetry.

#### Scenario: Cache miss while offline
- **WHEN** an uncached tile is requested while offline
- **THEN** a fallback background is displayed without crashing, stalling, or throwing unhandled exceptions.

### Requirement: Per-Widget Zoom Configuration
The application SHALL allow configuring and persisting the initial zoom level for each map widget instance.

#### Scenario: Configuring zoom level in edit mode
- **WHEN** the pilot opens the configuration dialog for a map widget and adjusts the zoom slider or stepper
- **THEN** the selected zoom level is saved in `WidgetPlacementModel.mapZoomLevel` and applied immediately.

#### Scenario: Screen configuration persistence
- **WHEN** the application is restarted
- **THEN** each flight screen restores its map widgets with their configured individual zoom levels from persistent storage.

### Requirement: Geographic Telemetry & Overlays
The application SHALL render flight paths, airspaces, thermals, and pilot marker accurately on the geographic coordinate grid.

#### Scenario: Pilot position and trail synchronization
- **WHEN** telemetry coordinates update during live flight or IGC replay
- **THEN** the pilot marker updates its position, rotates to the current heading, and draws the GPS breadcrumb trail polyline.

#### Scenario: In-flight zoom and centering interaction
- **WHEN** the pilot taps zoom in (+), zoom out (-), or center-pilot buttons on the map HUD
- **THEN** the map dynamically updates its viewport zoom and pans to keep the pilot centered.
