## Purpose

Detects thermaling episodes from live flight track patterns and provides visual feedback of uplift and sink zones via circle overlays, enabling pilots to quickly assess whether circling is producing net climb or loss of height.

## ADDED Requirements

### Requirement: Thermaling Episode Detection
The system SHALL detect thermaling episodes by analyzing flight patterns in real time. A thermaling episode is recognized when the aircraft maintains a circling pattern for a minimum duration with cumulative net vertical movement (positive or negative).

#### Scenario: Detect thermaling from circular flight pattern
- **WHEN** aircraft enters a circular flight pattern with cumulative altitude gain or loss over a configured minimum duration (default: 5 seconds)
- **THEN** the system marks the entry point as a thermaling episode and begins tracking circle markers for that episode

#### Scenario: Exit thermaling detection when straight flight resumes
- **WHEN** aircraft exits the circular pattern and transitions to straight-line flight
- **THEN** the system closes the current thermaling episode and stops appending new circle markers to it

#### Scenario: Handle interrupted or short circles
- **WHEN** the aircraft completes a very brief circle (less than the minimum duration threshold)
- **THEN** the system MAY ignore the pattern or apply increased hysteresis before classifying it as thermaling

### Requirement: Circle Marker Generation
The system SHALL generate circle markers for thermaling episodes, with visual properties encoding climb or sink magnitude.

#### Scenario: Generate green circle for uplift
- **WHEN** a portion of the thermaling episode has net altitude gain (positive vertical movement)
- **THEN** the system generates a circle marker centered at the position where that net climb occurred, colored green, with radius proportional to the magnitude of climb

#### Scenario: Generate red circle for sink
- **WHEN** a portion of the thermaling episode has net altitude loss (negative vertical movement)
- **THEN** the system generates a circle marker centered at the position where that sink occurred, colored red, with radius proportional to the magnitude of sink

#### Scenario: Scale circle size by vertical rate magnitude
- **WHEN** creating a circle marker
- **THEN** the circle radius SHALL be proportional to the vertical speed magnitude (e.g., 3 knots climb → medium circle; 6 knots climb → larger circle; 2 knots sink → small red circle)

#### Scenario: Handle boundary conditions for circle sizing
- **WHEN** vertical speed is very small (e.g., < 0.5 knots)
- **THEN** the system SHALL render a minimum-size circle to remain visible on the map

### Requirement: Offline Operation
The thermaling detection and circle marker generation SHALL function without network connectivity.

#### Scenario: Detect thermaling with no internet
- **WHEN** the device has no network connection and is in-flight
- **THEN** thermaling detection and marker generation SHALL proceed normally using only local flight data

#### Scenario: Handle stale or partial telemetry
- **WHEN** GPS or altitude data updates are delayed or interrupted during thermaling detection
- **THEN** the system SHALL either buffer the incomplete data and resume detection once telemetry resumes, or gracefully degrade by rendering markers with the data available

### Requirement: Thermaling State Export
The system SHALL expose the current thermaling episode state and circle markers to the UI layer via well-defined data structures.

#### Scenario: Provide thermaling episode data to UI
- **WHEN** the UI requests the current thermaling state
- **THEN** the system returns a structured object containing: episode ID, start/end timestamps, list of circle markers (position, radius, color, vertical speed), and active status

#### Scenario: Notify UI of thermaling episode changes
- **WHEN** a new thermaling episode is detected or an existing episode is closed
- **THEN** the system emits an event or update notification that the UI can observe

### Requirement: Configurable Thermaling Thresholds
The system SHALL support configuration of thermaling detection parameters to adapt to different flying styles and conditions.

#### Scenario: Configure minimum circle duration
- **WHEN** a configuration parameter is set for minimum thermaling episode duration
- **THEN** the system uses that threshold (in seconds) to determine whether a circular pattern qualifies as thermaling

#### Scenario: Configure minimum vertical movement
- **WHEN** a configuration parameter is set for minimum cumulative altitude change
- **THEN** the system requires that threshold (in meters or feet) to be met before classifying a circle as a thermaling episode

#### Scenario: Configure circle radius scaling factor
- **WHEN** a configuration parameter is set for circle size scaling
- **THEN** the system applies that factor to all circle radius calculations
