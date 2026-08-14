## Purpose

Define the application shell, primary navigation, configurable flight pages, and global preferences so pilots can reach and interpret the right information predictably and safely.

## ADDED Requirements

### Requirement: App startup opens landing page by default
After successful application bootstrap, the system SHALL open the configured Landing Page as the initial route, regardless of which normal page or settings route was active in the previous session.

#### Scenario: Application starts
- **WHEN** the application completes startup
- **THEN** the Landing Page is the first visible page
- **AND** page content matches the saved landing page widget/layout configuration

#### Scenario: Landing page configuration missing
- **WHEN** the flight UI starts and the landing page configuration is missing or unreadable
- **THEN** the system falls back to a safe built-in landing page layout
- **AND** the pilot can continue flying without blocking dialogs

### Requirement: Application shell provides primary navigation
The system SHALL provide one application shell for live flight, simulated flight, screen configuration, and global settings, and its main navigation bar SHALL provide actions to open the Flight Deck, Screen Configuration, and Settings.

#### Scenario: Pilot navigates from Settings to flight
- **WHEN** the pilot opens the main navigation bar from Settings and selects Flight Deck
- **THEN** the system opens the currently effective flight page
- **AND** live flight processing continues without being restarted

#### Scenario: Pilot opens screen configuration outside flight deck
- **WHEN** the pilot selects Screen Configuration while a non-flight route is visible
- **THEN** the system presents a page selector containing Landing Page, user-created pages, and Thermaling Screen

### Requirement: Configurable flight pages support extensible widget composition
The system SHALL allow the pilot to create, rename, reorder, configure, and delete user-created normal pages and to select and arrange widgets on every flight page, while preventing deletion of the singleton Landing Page and Thermaling Screen.

#### Scenario: Pilot enters page configuration mode
- **WHEN** the pilot opens configuration for the current normal page
- **THEN** the system presents an extensible widget catalogue
- **AND** the initial catalogue includes altitude, uplift/downlift vario, ground speed, lift-to-drag ratio, flight time, current time, wind direction, wind strength, map, and active sensor/connection status
- **AND** configuration changes are saved for that specific page

#### Scenario: New widget type becomes available
- **WHEN** a later application version registers a new compatible widget type
- **THEN** it appears in the widget catalogue without requiring migration of unchanged page definitions

#### Scenario: Required page deletion is attempted
- **WHEN** the pilot attempts to delete the Landing Page or Thermaling Screen
- **THEN** the system rejects the deletion and keeps the required page available

#### Scenario: Configuration persists offline
- **WHEN** the pilot changes page configuration while offline
- **THEN** the configuration is stored locally on device
- **AND** the same configuration is restored after app restart without network access

### Requirement: Flight widgets expose current, stale, and unavailable data safely
Every flight-data widget SHALL display its data source state and SHALL NOT present stale or unavailable data as current.

#### Scenario: Widget data becomes stale
- **WHEN** a widget's input exceeds its defined stale threshold
- **THEN** the widget displays a visible stale state within one second
- **AND** the last value is distinguishable from a current value

#### Scenario: Widget source is unavailable
- **WHEN** no valid source is available for a configured widget
- **THEN** the widget displays an unavailable state without blocking the rest of the page

### Requirement: Map widget supports source and overlay configuration
For pages that include a map widget, the system SHALL allow the pilot to choose among currently approved map sources and independently toggle overlays for flight zones, flown track, and planned track.

#### Scenario: Pilot configures map source and overlays
- **WHEN** the pilot changes map settings for a page
- **THEN** the selected map source is applied for that page's map widget
- **AND** each overlay toggle (flight zones, flown track, planned track) is applied independently
- **AND** required source attribution remains visible

#### Scenario: Source is blocked, expired, or unapproved
- **WHEN** a source is not approved for the intended display, caching, or offline use
- **THEN** the source is not offered for selection
- **AND** the system does not substitute an undocumented source

#### Scenario: Map source unavailable
- **WHEN** the selected installed map source is missing, corrupt, or cannot be loaded while offline
- **THEN** the system displays an explicit map-unavailable state or a configured approved local fallback
- **AND** the system does not fetch or substitute an online source transparently
- **AND** widget data outside the map remains visible

### Requirement: Thermaling screen is automatic and excluded from manual paging
The system SHALL reserve the Thermaling Screen for automatic activation within the Flight Deck and SHALL exclude it from manual swipe-based page navigation.

#### Scenario: Entering thermal flight
- **WHEN** the thermaling state changes to active (circling in lift)
- **THEN** the Thermaling Screen becomes visible automatically
- **AND** the system records which normal page was active immediately before the switch

#### Scenario: Leaving thermal flight
- **WHEN** the thermaling state changes to inactive (straight/glide flight)
- **THEN** the system restores the last active normal page automatically
- **AND** manual swipe navigation continues from that restored page

#### Scenario: Pilot swipes pages during normal flight
- **WHEN** the pilot swipes left or right in normal flight
- **THEN** the system cycles only through normal pages (Landing Page and user-created pages)
- **AND** the Thermaling Screen is not shown by swipe

#### Scenario: Thermal state changes while Settings is visible
- **WHEN** thermaling state changes while Settings or Screen Configuration is the foreground route
- **THEN** the system does not dismiss or replace that route
- **AND** the effective Flight Deck page reflects the current thermaling state when the pilot returns

### Requirement: Global top navigation bar is accessible from all pages
The application shell SHALL provide a semi-transparent top navigation bar that can be revealed from every shell route by swiping top-to-down and dismissed by tapping outside the bar.

#### Scenario: Opening global navigation bar
- **WHEN** the pilot performs a top-to-down swipe gesture on any app page
- **THEN** a top-anchored semi-transparent navigation bar is shown
- **AND** it includes Flight Deck, Screen Configuration, and Settings actions

#### Scenario: Dismissing global navigation bar
- **WHEN** the navigation bar is visible and the pilot taps outside the bar
- **THEN** the navigation bar is hidden
- **AND** the underlying page remains active

#### Scenario: Configuring thermaling page from global navigation
- **WHEN** the pilot opens screen configuration from the navigation bar while not currently in thermal state
- **THEN** the system allows selecting and editing Thermaling Screen configuration
- **AND** the edited thermaling configuration is applied on the next automatic thermaling activation

### Requirement: Global settings control application-wide preferences
The Settings screen SHALL allow the pilot to configure appearance, language, and measurement system independently of flight-page layouts, SHALL persist those preferences locally, and SHALL apply them throughout the application shell.

#### Scenario: Pilot changes appearance
- **WHEN** the pilot selects system, light, or dark appearance
- **THEN** the selected appearance is applied throughout the application shell
- **AND** the preference remains active after restart

#### Scenario: Pilot changes language
- **WHEN** the pilot selects a supported language
- **THEN** application-shell, Settings, configuration, and built-in widget labels use that language
- **AND** missing translations fall back to the application's default language without displaying empty labels

#### Scenario: Pilot changes measurement system
- **WHEN** the pilot selects metric or imperial units
- **THEN** all built-in widgets and configuration previews format compatible measurements in that system
- **AND** stored source values remain unchanged

#### Scenario: Global settings are changed offline
- **WHEN** the pilot changes appearance, language, or units without network access
- **THEN** the change applies immediately and persists locally

### Requirement: Settings manages supported Bluetooth flight devices
The Settings screen SHALL expose Bluetooth discovery, connection, disconnection, reconnect, permission, and connection-status behavior only for devices and transports supported on the current platform, while keeping internal sensors as the visible fallback.

#### Scenario: Supported device connects
- **WHEN** the pilot selects a discovered supported Bluetooth flight device and grants required platform permission
- **THEN** Settings displays the connection as active
- **AND** the sensor-status widget identifies the active external source

#### Scenario: Bluetooth permission is denied
- **WHEN** required Bluetooth permission is denied
- **THEN** Settings displays an actionable permission-denied state
- **AND** internal sensors remain available without blocking the Flight Deck

#### Scenario: Device or transport is unsupported
- **WHEN** a device or transport has not passed support validation for the current platform
- **THEN** the system does not present it as connectable production support
- **AND** Settings explains that internal sensors remain the fallback

#### Scenario: Connected device becomes stale or disconnects
- **WHEN** an active Bluetooth device stops providing valid samples or disconnects
- **THEN** Settings and the sensor-status widget show the degraded connection state
- **AND** reconnect behavior does not block other application navigation

### Requirement: Simulated flight remains visibly distinct
Development-only simulated flight SHALL use the same application shell and page flow while preserving persistent simulation labeling, and production Settings MUST NOT expose controls that activate mock flight mode.

#### Scenario: Simulated flight pages are displayed
- **WHEN** a development build runs in simulated flight mode
- **THEN** every Flight Deck page remains visibly marked as simulated
- **AND** page navigation and configuration use synthetic providers without requiring physical sensors

#### Scenario: Production Settings is displayed
- **WHEN** Settings is opened in a production build
- **THEN** no mock-flight activation control is present
