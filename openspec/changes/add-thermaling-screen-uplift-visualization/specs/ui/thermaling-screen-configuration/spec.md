## Purpose

Provides a dedicated, independently configurable user interface screen for thermaling mode that displays circle overlays, maps, and widgets without coupling its settings to the main flight screen configuration.

## ADDED Requirements

### Requirement: Separate Thermaling Screen
The system SHALL provide a dedicated thermaling screen that is visually and functionally distinct from the main flight screen.

#### Scenario: Automatically switch to thermaling screen
- **WHEN** the system detects an active thermaling episode
- **THEN** the UI automatically transitions to the thermaling screen (or presents it as an overlay/tab, depending on design)

#### Scenario: Return to main screen after thermaling ends
- **WHEN** the thermaling episode ends and no new thermaling is detected after a configurable grace period (default: 10 seconds)
- **THEN** the UI may automatically return to the main flight screen, or present a prompt allowing the pilot to do so

#### Scenario: Manual toggle between screens
- **WHEN** the pilot interacts with a screen selector (button, tab, or gesture)
- **THEN** the UI switches between main flight screen and thermaling screen

### Requirement: Thermaling Screen Background Map Configuration
The system SHALL allow independent configuration of the thermaling screen's background map and rendering properties.

#### Scenario: Select thermaling screen map source
- **WHEN** the pilot accesses settings specific to the thermaling screen
- **THEN** they can choose a map layer/source (e.g., satellite, topographic, plain, or empty) distinct from the main screen's map choice

#### Scenario: Configure map visibility and opacity
- **WHEN** the pilot adjusts thermaling screen map settings
- **THEN** they can set visibility, opacity, and other rendering properties for the thermaling screen map without affecting the main screen

#### Scenario: Persist thermaling screen map settings
- **WHEN** the pilot switches away from the thermaling screen
- **THEN** the system remembers the selected map configuration and applies it the next time the thermaling screen is shown

### Requirement: Thermaling Screen Widget Configuration
The system SHALL allow independent configuration of widgets displayed on the thermaling screen.

#### Scenario: Select thermaling screen widgets
- **WHEN** the pilot accesses thermaling screen settings
- **THEN** they can choose which widgets (e.g., uplift indicator, wind direction, altitude, speed) to display on the thermaling screen

#### Scenario: Configure widget layout
- **WHEN** the pilot configures the thermaling screen
- **THEN** they can arrange widgets (position, size, visibility) independently from the main screen layout

#### Scenario: Widget independence from main screen
- **WHEN** the pilot changes a widget setting on the thermaling screen
- **THEN** those changes apply only to the thermaling screen and do NOT affect the main screen's widget configuration

#### Scenario: Persist thermaling widget settings
- **WHEN** the pilot modifies thermaling screen widgets
- **THEN** the system saves those settings persistently and applies them on all subsequent visits to the thermaling screen

### Requirement: Circle Overlay Rendering
The system SHALL render circle markers on the thermaling screen in real time, visible against the background map.

#### Scenario: Display circle markers on thermaling screen
- **WHEN** the thermaling screen is active and thermaling is in progress
- **THEN** all circle markers (green for uplift, red for sink) are rendered at their geographic positions on the map

#### Scenario: Handle circle marker visibility at different zoom levels
- **WHEN** the user zooms or pans the thermaling screen map
- **THEN** circle markers remain visible and scale appropriately (or maintain fixed visual size, depending on design choice)

#### Scenario: Render historical circles during an episode
- **WHEN** a thermaling episode is ongoing
- **THEN** all circle markers generated during that episode are visible on the screen, not just the most recent ones

### Requirement: Thermaling Episode History
The system SHALL provide access to circle markers from recent or completed thermaling episodes on the thermaling screen.

#### Scenario: Display current episode circles
- **WHEN** an active thermaling episode is ongoing
- **THEN** the screen displays all circle markers generated in that episode

#### Scenario: View recent episodes after thermaling ends
- **WHEN** thermaling ends and the pilot remains on the thermaling screen
- **THEN** the system MAY display circle markers from recent completed episodes (e.g., last N episodes or last M minutes)

#### Scenario: Clear or archive old thermaling data
- **WHEN** a new flight begins or the pilot explicitly resets
- **THEN** the system clears thermaling circle history from the previous flight session

### Requirement: Offline Thermaling Screen Operation
The thermaling screen and all its features SHALL function without network connectivity.

#### Scenario: Render thermaling screen offline
- **WHEN** the device has no network connection
- **THEN** the thermaling screen remains fully functional, including map rendering (if using cached/offline maps) and circle marker display

#### Scenario: Handle offline map source
- **WHEN** an offline or local map is selected for the thermaling screen
- **THEN** the system uses that map source instead of requesting tiles from the network

### Requirement: Configuration Storage and Retrieval
The system SHALL persist thermaling screen configuration settings locally on the device.

#### Scenario: Save thermaling screen settings
- **WHEN** the pilot modifies any thermaling screen setting (map, widgets, layout)
- **THEN** the system persists those changes to local storage

#### Scenario: Restore settings on app restart
- **WHEN** the app is closed and reopened
- **THEN** the thermaling screen restores all previously saved settings

#### Scenario: Reset to defaults
- **WHEN** the pilot explicitly requests a reset of thermaling settings
- **THEN** the system restores thermaling screen configuration to factory defaults
