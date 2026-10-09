# live-thermal-assistant Specification

## Purpose
Runs the thermal assistant (circling detection, wind drift estimation, thermal core calculation) on-device against live and replayed telemetry, and publishes honest, validity-tagged thermal and wind state to the cockpit display.

## Requirements

### Requirement: On-device thermal assistant processing of telemetry
The application SHALL process every valid live and replay telemetry sample through an on-device thermal assistant performing circling detection, wind drift estimation, and thermal core calculation with the thresholds of the `dynamic-thermal-assistant-wind-drift` capability. Processing SHALL run without network access.

#### Scenario: Entering a thermal during live flight
- **WHEN** the pilot turns continuously at 18°/s while climbing
- **THEN** the published flight mode SHALL change from gliding to circling no later than the first sample at which cumulative heading change reaches 270°
- **AND** the published turn direction SHALL match the turn direction (left or right)

#### Scenario: Leaving a thermal
- **WHEN** the pilot is circling and then holds a heading within ±15° for 8 s
- **THEN** the published flight mode SHALL change to gliding
- **AND** the circling track window and thermal core estimate SHALL be cleared

#### Scenario: Operating fully offline
- **WHEN** the device has no network connectivity during flight
- **THEN** circling detection, wind estimation, and thermal core calculation SHALL continue to produce results without degradation

### Requirement: Cross-runtime parity with the Rust reference implementation
The on-device thermal assistant results SHALL match the `flight_core` Rust reference implementation on shared golden replay fixtures: identical flight-mode and turn-direction transitions at the same sample index, wind speed within 0.5 km/h, wind direction within 2°, and thermal core position within 2 m. The fixtures SHALL include at least a no-wind thermal, a drifting thermal with 10 m/s wind, a straight glide, erratic heading reversals, and a telemetry gap.

#### Scenario: Golden fixture parity check
- **WHEN** the automated test suite replays each golden fixture through the on-device thermal assistant
- **THEN** every per-sample output SHALL be within the tolerances above of the Rust-generated expected output
- **AND** any divergence SHALL fail the test suite

#### Scenario: Fixture regeneration
- **WHEN** the Rust reference algorithms change
- **THEN** regenerating the fixtures from the Rust reference and re-running the parity check SHALL detect any on-device implementation that was not updated

### Requirement: Honest wind publication
The cockpit SHALL display only wind derived from the thermal assistant estimate (or a future explicitly declared wind source). The application MUST NOT fabricate wind direction or speed from heading or constant defaults. Each published wind value SHALL carry a validity flag and the age of its last refinement.

#### Scenario: No wind estimate yet
- **WHEN** fewer than 2 complete 360° turns have been flown since app start
- **THEN** wind displays SHALL show an explicit "no estimate" state instead of a numeric direction or speed

#### Scenario: Wind estimate available
- **WHEN** the pilot completes 2 or more full turns in a thermal drifting at 10 m/s from the west
- **THEN** the displayed wind SHALL show a direction within ±10° of 270° and a speed within ±4 km/h of 36 km/h

#### Scenario: Wind retained after leaving a thermal
- **WHEN** the pilot leaves the thermal and glides
- **THEN** the last valid wind estimate SHALL remain displayed with its age

#### Scenario: Stale wind estimate
- **WHEN** the last wind refinement is older than 15 minutes
- **THEN** wind displays SHALL mark the value as stale with a visually distinct indicator

### Requirement: Live thermal map data feed
The thermal map widget SHALL render the circling track window, thermal core estimate, and wind vector produced by the thermal assistant for the current flight, limited to the widget's configured history duration. Placeholder or demo track data SHALL appear only when no live or replay telemetry source is active (for example, in layout edit preview), and SHALL then be labelled as a preview.

#### Scenario: Rendering a live thermal
- **WHEN** the pilot is circling and the thermal map widget is visible
- **THEN** the widget SHALL render the actual recorded track points with their measured climb rates
- **AND** SHALL render the core marker at the estimated core position relative to the pilot
- **AND** SHALL orient the display using the pilot's track heading, not the wind direction

#### Scenario: Gliding with no circling data
- **WHEN** a live source is active and the pilot is gliding with an empty circling track window
- **THEN** the widget SHALL render no bubbles and no core marker, and SHALL NOT render demo data

#### Scenario: Preview without telemetry
- **WHEN** no live or replay telemetry source is active
- **THEN** the widget SHALL render the demo track together with a visible "preview" label

### Requirement: Telemetry interruption and stale data handling
The thermal assistant SHALL exclude samples flagged stale or invalid, and SHALL treat a gap of more than 5 s between consecutive valid samples as an interruption that resets circling detection and the in-progress turn accumulation, without discarding the last valid wind estimate.

#### Scenario: GPS dropout during circling
- **WHEN** valid samples stop arriving for more than 5 s while circling
- **THEN** the published flight mode SHALL fall back to gliding
- **AND** no turn completion SHALL be counted across the gap
- **AND** the last valid wind estimate SHALL remain available with its age

#### Scenario: Stale samples are ignored
- **WHEN** a sample is flagged stale or invalid
- **THEN** it SHALL NOT contribute to heading accumulation, wind drift, or core weighting

### Requirement: Deterministic replay of thermal assistant state
Thermal assistant output during flight replay SHALL be derived solely from recorded track points and SHALL be identical across repeated replays of the same flight, including after seeking.

#### Scenario: Repeated replay
- **WHEN** the same recorded flight is replayed twice from the start
- **THEN** the sequence of published flight modes, wind estimates, and core estimates SHALL be identical

#### Scenario: Seeking within a replay
- **WHEN** the user seeks to a new replay position
- **THEN** the published flight mode, wind estimate, thermal core, and track window SHALL equal those of a continuous replay from the start of the flight to that position

#### Scenario: Bounded cost of seeking back
- **WHEN** the user seeks backwards to a position already replayed
- **THEN** the thermal assistant SHALL reprocess at most 60 s of recorded flight time to reach the new position

### Requirement: Bounded processing cost off the hot paths
Thermal assistant processing SHALL NOT block the sensor acquisition or audio vario paths, SHALL complete in under 1 ms per sample on average at 10 Hz input in the automated benchmark, and SHALL retain bounded memory (at most 60 s of core-calculation samples and at most the configured history duration, capped at 300 s, of track-window samples).

#### Scenario: Sustained 10 Hz input
- **WHEN** a one-hour synthetic flight at 10 Hz is processed in the benchmark test
- **THEN** mean per-sample processing time SHALL be under 1 ms
- **AND** retained sample counts SHALL never exceed the configured bounds

#### Scenario: Audio vario unaffected
- **WHEN** the thermal assistant is processing samples
- **THEN** audio vario tone updates SHALL continue to be driven independently of thermal assistant processing

### Requirement: Simulated wind drift in synthetic telemetry
The synthetic telemetry source SHALL apply a configurable wind vector (default 0 km/h) to its ground track so simulated thermals drift with the wind, and SHALL NOT emit fabricated wind fields in its telemetry samples.

#### Scenario: Mock thermal with wind
- **WHEN** the synthetic source flies the thermal-climb manoeuvre with a configured wind of 20 km/h from 270°
- **THEN** the ground track SHALL drift east by approximately 5.6 m/s
- **AND** after 2 complete turns the thermal assistant SHALL estimate the wind within ±10° and ±4 km/h of the configured value
