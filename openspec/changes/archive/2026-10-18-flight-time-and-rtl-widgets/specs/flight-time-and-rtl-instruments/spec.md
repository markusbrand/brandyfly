# Spec Delta

## Purpose

Computes real-time flight duration and return-to-launch navigation telemetry (distance, bearing, required glide ratio, and launch altitude margin), providing pilots with dedicated cockpit flight clock and return glide instruments.

## ADDED Requirements

### Requirement: Flight Duration and Takeoff Time Tracking
The telemetry subsystem SHALL calculate elapsed airborne flight duration from the confirmed takeoff timestamp to the current telemetry timestamp, updating at least once per second, and preserve the initial takeoff timestamp throughout active tracking and replay.

#### Scenario: Elapsed duration during active flight
- **WHEN** flight tracking detects a confirmed takeoff or replay progresses past takeoff
- **THEN** the system SHALL compute elapsed flight duration as `current_time - takeoff_time` formatted as `hh:mm:ss` or `mm:ss` with zero drift.

#### Scenario: Pre-takeoff standby state
- **WHEN** the flight state is in pre-takeoff ground standby
- **THEN** elapsed flight duration SHALL indicate `00:00` or `--:--` and takeoff time SHALL be represented as standby.

#### Scenario: Flight replay duration synchronization
- **WHEN** an IGC flight recording is replayed
- **THEN** the telemetry system SHALL derive takeoff time from the initial flight point and synchronize elapsed duration to the active playback index timestamp.

#### Scenario: Stale telemetry or gap handling
- **WHEN** incoming GPS or telemetry packets are flagged as stale or cease for more than 5 seconds
- **THEN** the flight clock SHALL freeze elapsed duration progression and display a visual stale indicator until fresh telemetry arrives.

### Requirement: Return to Launch Navigation Calculation
The telemetry subsystem SHALL continuously compute the geodesic distance, true bearing, altitude difference, and required glide ratio (L/D) between the aircraft's current GPS position and the confirmed launch location.

#### Scenario: In-flight return glide calculation
- **WHEN** the aircraft is airborne at an altitude higher than the takeoff point and at a non-zero distance from launch
- **THEN** required glide ratio SHALL be computed as `horizontal_distance / (current_altitude - takeoff_altitude)` and bearing SHALL reflect the true heading from the pilot to launch.

#### Scenario: Below launch altitude safety fallback
- **WHEN** the aircraft sinks below the takeoff elevation
- **THEN** required glide ratio SHALL display `---` (or negative margin indicator) without throwing a divide-by-zero error, and altitude delta SHALL display the negative margin (e.g., `-120 m`).

#### Scenario: At or adjacent to launch position
- **WHEN** the aircraft is within 15 meters horizontal distance of launch
- **THEN** required glide ratio SHALL display `---` and distance SHALL indicate `0 m`.

#### Scenario: Pre-takeoff or uninitialized launch location
- **WHEN** no confirmed takeoff position has been recorded
- **THEN** all return-to-launch fields SHALL render as unavailable (`---`) until takeoff is confirmed.

### Requirement: Flight Time Cockpit Instrument Widget
The application SHALL provide a placeable `flightTime` instrument widget displaying elapsed flight duration, current local clock time, and takeoff timestamp across responsive size tiers on the 16x32 virtual grid.

#### Scenario: Regular tier presentation
- **WHEN** `flightTime` is rendered in regular size tier
- **THEN** it SHALL display the elapsed flight duration prominently with primary emphasis, alongside secondary readouts for local clock time and takeoff timestamp.

#### Scenario: Compact tier presentation
- **WHEN** `flightTime` is rendered in compact size tier
- **THEN** it SHALL display the elapsed flight duration alongside a `FLIGHT TIME` label or current time.

#### Scenario: Tiny tier presentation
- **WHEN** `flightTime` is rendered in tiny size tier
- **THEN** it SHALL render the elapsed duration digits scaled to fit the slot without labels or secondary clocks.

#### Scenario: Pre-takeoff visual indication
- **WHEN** the aircraft is awaiting takeoff on the ground
- **THEN** the widget SHALL display `00:00` with a subtle standby badge while showing the current local clock time.

### Requirement: Return to Launch Cockpit Instrument Widget
The application SHALL provide a placeable `returnGlide` instrument widget displaying distance to launch, required glide ratio, altitude margin above launch, and directional bearing back to launch across responsive size tiers.

#### Scenario: Standard return glide presentation in regular tier
- **WHEN** `returnGlide` renders in regular size tier while airborne above launch
- **THEN** it SHALL display the required glide ratio (e.g. `L/D 6.2`), distance to launch (e.g. `4.8 km`), altitude margin above takeoff (e.g. `+450 m`), and a directional bearing indicator pointing toward launch.

#### Scenario: Sinking below launch presentation
- **WHEN** `returnGlide` renders while the aircraft is below launch elevation
- **THEN** it SHALL display the negative altitude deficit in prominent warning styling and replace required glide ratio with `---`.

#### Scenario: Compact and tiny tier scaling
- **WHEN** `returnGlide` renders in compact or tiny tier
- **THEN** it SHALL prioritize required glide ratio and distance to launch, omitting secondary margin and bearing details in tiny tier.

#### Scenario: Standby mode before takeoff
- **WHEN** `returnGlide` renders prior to takeoff confirmation
- **THEN** it SHALL display `RTL` with `---` indicators indicating launch position will be set on takeoff.
