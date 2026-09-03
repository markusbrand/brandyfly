## ADDED Requirements

## flight-tracking-logbook-and-replay

### Requirement: Discrete speed multiplier cycling and timeline scrubbing
The replay controller SHALL support discrete playback speed multipliers (1x, 2x, 5x, 10x) cycling sequentially on user interaction, alongside arbitrary timeline seeking.

#### Scenario: User cycles replay playback speed
- **WHEN** the user taps the speed button on the Replay HUD while at 1x speed
- **THEN** the playback speed advances through 2x, 5x, 10x, and wraps back to 1x upon subsequent taps
- **AND** the active telemetry streaming interval adjusts proportionally without dropped frames

#### Scenario: User seeks to specific point in timeline
- **WHEN** the user scrubs the timeline progress bar to a target position
- **THEN** the active flight index updates immediately
- **AND** all flight instruments reflect the telemetry snapshot corresponding to the selected timestamp

### Requirement: Time-synchronized IGC B-record stream injection into flight core
The IGC replay engine SHALL parse IGC B-records (timestamp, latitude, longitude, validity, pressure altitude, GPS altitude) and feed them sequentially into the `flight_core` pipeline at real-time paced intervals.

#### Scenario: Valid IGC track replay
- **WHEN** an IGC flight track is loaded into the replay engine and playback is initiated
- **THEN** B-records are parsed into structured sensor events
- **AND** streamed into `flight_core` with monotonic timestamps scaled by the active playback speed

#### Scenario: Malformed or corrupted B-record in IGC stream
- **WHEN** a replayed IGC stream contains an unparseable or invalid B-record
- **THEN** the record is rejected with an incremented error counter
- **AND** playback proceeds to subsequent valid records without interrupting the session

## native-flight-pipeline-validation

### Requirement: Telemetry provider abstraction across physical and virtual sources
The telemetry pipeline SHALL accept stream inputs adhering to a standardized `ITelemetrySource` abstraction across physical Bluetooth Low Energy peripherals, onboard device sensors, recorded IGC streams, and synthetic generators.

#### Scenario: Switching active telemetry source
- **WHEN** the application switches from live BLE reception to synthetic or IGC replay mode
- **THEN** the pipeline detaches the previous source and attaches the new telemetry provider
- **AND** downstream KPIs and vario display widgets continue updating without pipeline resets

### Requirement: Procedural synthetic paragliding flight generation
The synthetic flight generator in `flight_core` SHALL generate deterministic sensor streams for standard paragliding flight phases including steady glide, 360-degree thermaling turn with +2.5 m/s climb rate, and sink recovery.

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
