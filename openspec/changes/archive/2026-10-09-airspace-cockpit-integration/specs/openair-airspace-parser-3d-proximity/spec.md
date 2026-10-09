## ADDED Requirements

### Requirement: Runtime Telemetry Stream Binding & Proximity Evaluation
The airspace evaluation subsystem SHALL bind directly to the active flight telemetry stream, evaluating 3D proximity and projected glide slope intersections at a rate between 1 Hz and 2 Hz while maintaining zero UI thread frame drops.

#### Scenario: Periodic proximity evaluation from live telemetry
- **WHEN** flight telemetry updates are received during active flight or replay
- **THEN** the system evaluates horizontal and vertical distance to nearby airspaces using active position, barometric altitude, and ground elevation
- **AND** updates proximity state without blocking the UI isolate.

#### Scenario: Automatic DACH fixture loading in mock flight mode
- **WHEN** the application starts with `BRANDYFLY_LOCAL_MOCK_FLIGHT_MODE=true`
- **THEN** the system automatically loads the bundled DACH OpenAir airspace fixture into the spatial index
- **AND** begins proximity checks along the simulated flight path.

### Requirement: Audible Airspace Proximity Alerts
The audio vario subsystem SHALL generate distinct audible alert patterns upon airspace proximity escalation to Level 2 Warning or Level 3 Violation.

#### Scenario: Warning transition audio cue
- **WHEN** airspace proximity escalates to Level 2 Warning
- **THEN** the audio service emits a distinct, non-overlapping warning tone sequence.

#### Scenario: Violation transition audio cue
- **WHEN** airspace proximity enters Level 3 Violation
- **THEN** the audio service emits an urgent, high-priority violation alert tone.
