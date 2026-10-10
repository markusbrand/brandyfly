# map-motion-smoothing Specification

## Purpose
Presents the pilot position, camera and track-up orientation on the flight map fluidly at display frame rate between telemetry fixes, without jumps or heading wobble, while never altering recorded or logged flight data.

## Requirements

### Requirement: Display-rate camera follow
While center-locked, the map SHALL move its camera continuously at the display frame rate (not only when a telemetry fix arrives), so the visible map position changes by small per-frame increments between fixes delivered at 1 Hz to 10 Hz.

#### Scenario: 1 Hz fixes produce continuous motion
- **WHEN** the pilot flies straight at 40 km/h with fixes arriving at 1 Hz and the map is center-locked
- **THEN** the camera center changes on every rendered frame between two fixes
- **AND** no single frame moves the camera by more than 25 % of the distance between the two consecutive fixes

#### Scenario: One camera update per frame
- **WHEN** a fix updates both position and heading
- **THEN** the map issues at most one combined camera update (center, bearing, zoom) per rendered frame

### Requirement: Bounded position prediction between fixes
The displayed pilot position SHALL be extrapolated from the observed motion of the most recent fixes, measured against wall-clock arrival time, and SHALL NOT be extrapolated beyond 1.5 observed fix intervals after the last fix, and never beyond 2.0 seconds.

#### Scenario: Prediction follows observed motion
- **WHEN** consecutive fixes show the pilot moving north-east at a steady rate
- **THEN** between fixes the displayed position advances north-east at that rate

#### Scenario: Replay speed multiplier
- **WHEN** replay runs at a speed multiplier of 4x
- **THEN** the displayed position moves continuously at the replay's effective on-screen speed without stepping

#### Scenario: Prediction horizon reached
- **WHEN** fixes arrive at 1 Hz and then stop
- **THEN** the displayed position stops advancing 1.5 seconds after the last fix and holds at the last predicted position

#### Scenario: Paused high-rate stream
- **WHEN** replay at 4x (fixes every 0.25 s) is paused
- **THEN** the display stops within 0.375 seconds of travel past the last fix, so resuming does not visibly pull the map back

### Requirement: Smooth convergence onto new fixes
When a new fix arrives, the displayed position SHALL converge onto the new fix trajectory within 0.5 seconds without a visible jump, unless the new fix is more than 300 m from the displayed position, in which case the display SHALL snap to the fix immediately.

#### Scenario: Normal correction
- **WHEN** a new fix is 15 m away from the predicted displayed position
- **THEN** the displayed position blends onto the new trajectory over no more than 0.5 seconds

#### Scenario: Large jump or replay seek
- **WHEN** the next fix is more than 300 m from the displayed position (e.g. replay seek, GNSS re-acquisition, flight reload)
- **THEN** the camera and marker snap directly to the new fix in the same frame without animating across the gap

### Requirement: Filtered heading for track-up rotation
In track-up orientation, the map bearing and marker rotation SHALL follow a low-pass filtered heading that takes the shortest angular path across 0°/360° and removes fix-to-fix jitter.

#### Scenario: Circling in a thermal
- **WHEN** the heading advances by 18° per 1 Hz fix while circling
- **THEN** the map rotates continuously between fixes instead of in 18° steps

#### Scenario: Heading jitter while gliding straight
- **WHEN** consecutive 1 Hz fixes alternate the heading by ±3° around a constant course
- **THEN** the displayed bearing varies by less than 3° peak-to-peak (at least 50 % attenuation of the raw 6° jitter), while a steady 18°/s turn is tracked with less than 10° lag

#### Scenario: Wrap-around
- **WHEN** the heading changes from 355° to 5°
- **THEN** the map rotates by 10° through north, not by 350° the other way

### Requirement: Stale and missing telemetry handling
The motion presentation SHALL NOT fabricate movement when telemetry is stale, invalid or absent.

#### Scenario: Stale telemetry
- **WHEN** the telemetry is flagged stale or invalid
- **THEN** prediction stops and the camera and marker hold the last displayed state until a valid fix arrives

#### Scenario: Telemetry source detached
- **WHEN** the telemetry source is detached and no pilot position is available
- **THEN** the frame loop stops and the map shows the last known or default position without motion

### Requirement: Frame loop lifecycle
The per-frame motion loop SHALL run only while there is motion to present and SHALL stop when the presented state has converged and no prediction is active, to avoid unnecessary battery use.

#### Scenario: Idle on the ground
- **WHEN** the displayed state has converged and no new fix has arrived within the prediction horizon
- **THEN** no further camera updates are issued until the next fix or user interaction

#### Scenario: Manual pan suspends follow
- **WHEN** the pilot pans the map and center-lock is released
- **THEN** the motion loop stops moving the camera until recenter (manual or inactivity timer)
- **AND** the recenter smoothly animates back to the current displayed pilot position

### Requirement: Presentation-only smoothing
Smoothing and prediction SHALL only affect what the map displays; telemetry values, recorded track points, IGC export, logbook statistics, and replay telemetry output SHALL be identical to an unsmoothed run.

#### Scenario: Deterministic replay unaffected
- **WHEN** the same IGC flight is replayed twice, once with the smoothed map visible and once without the map
- **THEN** the emitted telemetry sequence and recorded flight points are identical

#### Scenario: Track uses recorded fixes
- **WHEN** the flight track is drawn
- **THEN** its vertices are the recorded fixes, not predicted positions
