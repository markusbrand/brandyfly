# flight-tracking-logbook-and-replay Specification

## Purpose

Provides automated flight recording, hybrid takeoff/landing detection heuristics, FAI IGC and multi-format flight storage, logbook management with search and sample flight bundling, interactive real-time flight replay into instrument screens, and post-flight summary with resilient offline XContest synchronization.

## Requirements

### Requirement: Automatic takeoff detection and track logging
The flight tracking system SHALL automatically detect takeoff transitions based on real-time groundspeed, vario climb rate, and height-above-ground (HAG) signals, prepending buffered pre-takeoff points and streaming track points to persistent storage.

#### Scenario: Pilot launches from launch site
- **WHEN** the aircraft achieves sustained groundspeed >= 12 km/h or vertical speed |vario| >= 0.8 m/s for at least 4 consecutive seconds (reinforced by HAG > 15m when terrain elevation data is present)
- **THEN** the system transitions from `GroundPreflight` to `Flying` state
- **AND** prepends the preceding 15 seconds of buffered pre-takeoff points into the flight track log
- **AND** begins streaming live flight track points to local persistent storage

#### Scenario: False trigger rejection on launch
- **WHEN** groundspeed briefly spikes above 12 km/h for less than 3 seconds while preparing or inflating the wing on ground without altitude gain
- **THEN** the system remains in `GroundPreflight` state and does not create a false flight log

### Requirement: Automatic landing detection and flight completion
The flight tracking system SHALL automatically detect landing when ground movement ceases and vertical displacement stops for a configured settling window, finalizing the flight record and computing summary metrics.

#### Scenario: Pilot lands and wing settles
- **WHEN** the aircraft maintains groundspeed <= 8 km/h and vertical speed |vario| <= 0.4 m/s for at least 20 consecutive seconds
- **THEN** the system transitions from `Flying` to `Landed` state
- **AND** writes the finalized flight log in FAI IGC format, JSON, and CSV formats to local storage
- **AND** calculates summary statistics including duration, max altitude, min altitude, max climb, max sink, distance, and glide ratio

### Requirement: Multi-format flight storage and open standard compatibility
The storage engine SHALL store all recorded flights in standard FAI IGC format compliant with XContest validation rules, as well as structured JSON and CSV formats.

#### Scenario: Flight log file export
- **WHEN** a flight is finalized or exported by the user
- **THEN** the system generates a valid FAI IGC file containing mandatory A, H, I, B, and G/L records
- **AND** allows exporting the corresponding JSON and CSV representations

### Requirement: Flights Screen and logbook navigation
The application SHALL provide a dedicated "Flights" view accessible from the top navigation bar, categorizing flights into "My Flights" and "Planned Flights" with full search and filtering capabilities.

#### Scenario: Navigating to Flights Screen
- **WHEN** the user opens the top navigation drawer and taps "Flights"
- **THEN** the application presents the Flights Screen showing the "My Flights" and "Planned Flights" tabs
- **AND** displays flight cards with title, date, duration, max altitude, site name, and action buttons

#### Scenario: Searching through flights
- **WHEN** the user enters a search query in the Flights Screen search bar
- **THEN** the list filters in real time matching flight title, pilot name, site, or date

### Requirement: Flight management operations and sample restoration
The Flights Screen SHALL allow users to view details, rename, delete, share/export, and replay any flight in their logbook, and provide a restore action for the bundled sample flight.

#### Scenario: Deleting a flight
- **WHEN** the user selects "Delete" on a flight card and confirms the prompt
- **THEN** the flight record and associated track files are permanently removed from local storage and the UI list updates immediately

#### Scenario: Restoring sample flight
- **WHEN** the user has deleted the sample flight and selects "Restore Sample Flight" from the Flights Screen overflow menu
- **THEN** the application re-seeds `Krippenstein-Aussee` into "My Flights" and updates the list

#### Scenario: Renaming a flight
- **WHEN** the user renames a flight title
- **THEN** the updated title is saved locally and reflected across all screens

### Requirement: Bundled sample flight initialization
The application SHALL bundle a verified sample flight (`Krippenstein-Aussee`) and initialize it into the user's logbook upon first startup, allowing the user to manage, replay, or delete it like any recorded flight.

#### Scenario: Fresh app installation launch
- **WHEN** the application starts for the first time with an empty logbook
- **THEN** the sample flight `Krippenstein-Aussee` is imported into "My Flights"
- **AND** becomes immediately available for viewing, replaying, or deletion

### Requirement: Manual flight import
The application SHALL allow pilots to manually upload/import existing IGC format or JSON flight files and choose whether to assign them to "My Flights" or "Planned Flights".

#### Scenario: Importing an external flight track
- **WHEN** the user selects "Import Flight" and picks an IGC format or JSON file
- **THEN** the app prompts the user to select destination category ("My Flights" or "Planned Flights")
- **AND** parses the flight points, generates metadata, and adds it to the chosen list

### Requirement: Real-time flight replay into instrument screens
The application SHALL provide an interactive replay mode that jumps back to the flight instrument screens (custom layout and thermaling screen) and streams the replayed flight's sensor readings into all widgets in real time.

#### Scenario: Replaying a selected flight
- **WHEN** the user taps "Replay" on any flight card
- **THEN** the app navigates to the active flight screen with a floating bottom Replay HUD
- **AND** streams real-time altitude, vario, groundspeed, glide ratio, heading, coordinates, and HAG values into all active widgets matching the original flight timestamps

### Requirement: Collapsible On-Demand Replay Control Overlay with speed multiplier cycling
The replay controller SHALL display a collapsible bottom overlay supporting play/pause, timeline scrubbing, timestamp display, exit action, discrete speed multipliers (1x, 2x, 5x, 10x) that cycle in a continuous loop back to 1x upon successive taps, and swipe-down minimization / swipe-up expansion to minimize screen footprint during playback.

#### Scenario: Cycling replay playback speed
- **WHEN** the user taps the speed button on the Replay HUD while at 1x speed
- **THEN** the speed increments to 2x, then 5x, then 10x
- **AND WHEN** the user taps the speed button while at 10x speed
- **THEN** the playback speed cycles back to 1x original speed

#### Scenario: Collapsing and expanding replay controls on demand
- **WHEN** the user swipes down on the Replay HUD or taps the collapse toggle
- **THEN** the timeline scrubber and controls SHALL minimize into a compact bottom pill/handle
- **AND WHEN** the user swipes up from the bottom edge or taps the expand handle
- **THEN** the full scrubber and playback buttons SHALL expand back into view.

#### Scenario: Swiping between flight screens during replay
- **WHEN** the user swipes between custom instrument layouts and the thermaling screen while replay is active
- **THEN** the Replay HUD remains docked and playback continues uninterrupted

### Requirement: Modular telemetry provider abstraction and hot switching
The telemetry subsystem SHALL define modular provider contracts in Dart (`ITelemetrySource`) and Rust (`TelemetrySource`) allowing dynamic registration, lifecycle management (initialize, start, pause, stop, dispose), and hot attachment/switching of physical BLE sensors, internal sensors, IGC replay streams, and procedural flight generators without loss of tracking state.

#### Scenario: Hot-switching telemetry source during active tracking
- **WHEN** a flight tracking session is active and a different telemetry source is attached
- **THEN** the pipeline detaches the previous source and attaches the new telemetry provider
- **AND** downstream KPIs and vario display widgets continue updating without pipeline resets

### Requirement: Procedural synthetic paragliding flight generation
The synthetic flight generator in `flight_core` and mobile layer SHALL generate deterministic sensor streams for standard paragliding flight phases including steady glide, 360-degree thermaling turn with +2.5 m/s climb rate, and sink recovery.

#### Scenario: Generating steady glide maneuver
- **WHEN** the generator runs the steady glide scenario with a configured seed
- **THEN** sensor events reflect constant bearing, steady forward speed between 35-42 km/h, and steady sink rate between 1.0-1.4 m/s

#### Scenario: Generating 360-degree thermal climb maneuver
- **WHEN** the generator runs the thermaling scenario
- **THEN** coordinates trace a continuous circular 360-degree arc with a positive climb rate averaging +2.5 m/s and corresponding barometric pressure decrease

#### Scenario: Generating sink recovery maneuver
- **WHEN** the generator runs the sink recovery scenario
- **THEN** the telemetry stream transitions through heavy sink (-3.0 m/s or greater) back to stabilized level glide with altitude loss accurately accumulated

### Requirement: Automated web and unsupported platform fallback
The application startup lifecycle SHALL automatically detect web execution environments (`kIsWeb`) or platforms lacking native FFI support and activate simulated telemetry or replay mode without raising missing plugin exceptions.

#### Scenario: App boots on Flutter Web or unsupported platform
- **WHEN** BrandyFly launches on Flutter Web or a platform where native sensor plugins are absent
- **THEN** the app initializes with the synthetic telemetry source or bundled sample flight replay
- **AND** renders flight instruments and dashboard cards interactively without startup errors

### Requirement: Modal post-flight summary sheet
The application SHALL display a modal post-flight summary bottom sheet immediately following landing detection, providing flight metrics, a route map preview, an upload button to XContest.org, and logbook navigation.

#### Scenario: Post-flight summary display
- **WHEN** automatic landing is detected and confirmed
- **THEN** a modal bottom sheet appears displaying flight duration, max altitude, max climb rate, total track distance, average speed, and a route map preview
- **AND** offers an "Upload to XContest" button and a "View in Logbook" button

### Requirement: Resilient XContest upload with offline queuing
The application SHALL support manual and automatic flight submission to XContest.org, queuing pending uploads when landing occurs offline and synchronizing automatically once network connectivity is restored.

#### Scenario: Automatic upload with network connectivity
- **WHEN** automatic landing is detected AND "Auto-upload to XContest.org" is enabled in General Settings AND internet connectivity is active
- **THEN** the system uploads the flight to XContest.org and updates the flight status to "Uploaded"

#### Scenario: Automatic upload while offline in landing field
- **WHEN** automatic landing is detected AND "Auto-upload to XContest.org" is enabled, but network connectivity is unavailable
- **THEN** the flight status is set to "Upload Queued"
- **AND** the app automatically syncs the flight when connectivity is restored
- **AND** a manual "Retry Upload" button is available in the Flights Screen
