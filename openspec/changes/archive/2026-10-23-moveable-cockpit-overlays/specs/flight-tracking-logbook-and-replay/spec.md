## ADDED Requirements

### Requirement: Moveable Live Flight Recording Status Overlay with Manual Recording Controls
The live flight screen SHALL provide a free-floating, draggable, and collapsible recording status overlay bound to the flight tracking state that displays current recording status (`STANDBY`, `REC` with elapsed flight duration, or `LANDED`), operational mode badge (`LIVE` or `REPLAY`), platform status details when expanded, and a manual start/stop recording action.

#### Scenario: Displaying standby state and starting recording manually
- **WHEN** the application is in live flight mode and the flight tracking state is `GroundPreflight`
- **THEN** the recording status overlay SHALL display a `STANDBY` indicator, the `LIVE` mode badge, and a manual start recording button
- **AND WHEN** the pilot taps the manual start recording button
- **THEN** the flight tracking service SHALL immediately transition to `Flying` state, prepend any buffered pre-takeoff points, and begin recording live flight points with an elapsed duration timer (`REC mm:ss` or `REC hh:mm:ss`).

#### Scenario: Displaying active recording timer and stopping recording manually
- **WHEN** the flight tracking state is `Flying` (triggered either automatically on takeoff or manually by the pilot)
- **THEN** the recording status overlay SHALL display a `REC` indicator with the elapsed flight duration and a manual stop recording button
- **AND WHEN** the pilot taps the manual stop recording button
- **THEN** the flight tracking service SHALL finalize the active flight log, transition to `Landed` state, and trigger the post-flight completion flow.

#### Scenario: Dragging and clamping the recording status overlay
- **WHEN** the pilot pans across the recording status overlay card
- **THEN** the overlay SHALL follow the 2D drag gesture in real time and remain clamped within the viewport safe area bounds without intercepting touches outside its card bounds.

#### Scenario: Collapsing and expanding platform metadata on the recording overlay
- **WHEN** the pilot toggles the collapse/expand control on the recording status overlay
- **THEN** the secondary platform status text (`Running on: ...`) SHALL collapse or expand cleanly while preserving the dragged screen position within safe area boundaries.

## MODIFIED Requirements

### Requirement: Collapsible On-Demand Replay Control Overlay with speed multiplier cycling
The replay controller SHALL display a free-floating, draggable, and collapsible overlay supporting 2D pan repositioning within the safe area, play/pause, timeline scrubbing, timestamp display, exit action, discrete speed multipliers (1x, 2x, 5x, 10x) that cycle in a continuous loop back to 1x upon successive taps, and on-demand minimization/expansion to minimize screen footprint and uncover any underlying instrument widget during playback.

#### Scenario: Cycling replay playback speed
- **WHEN** the user taps the speed button on the Replay HUD while at 1x speed
- **THEN** the speed increments to 2x, then 5x, then 10x
- **AND WHEN** the user taps the speed button while at 10x speed
- **THEN** the playback speed cycles back to 1x original speed

#### Scenario: Collapsing and expanding replay controls on demand
- **WHEN** the user taps the collapse toggle or grab handle on the Replay HUD
- **THEN** the timeline scrubber and playback button row SHALL minimize into a compact floating bar showing the flight title, elapsed/total time, expand button, and close button
- **AND WHEN** the user taps the expand toggle or grab handle while minimized
- **THEN** the full scrubber and playback buttons SHALL expand back into view and re-clamp within the viewport safe area if near an edge.

#### Scenario: Dragging the replay control overlay across the screen
- **WHEN** the user pans on the Replay HUD background or header area in either expanded or minimized state
- **THEN** the Replay HUD SHALL move freely across the horizontal and vertical axes to the dragged position
- **AND** SHALL clamp its position so the overlay card remains fully inside the viewport safe area margins
- **AND** SHALL preserve its dragged position across replay telemetry ticks and screen switches.

#### Scenario: Swiping between flight screens during replay
- **WHEN** the user switches between custom instrument layouts and the thermaling screen while replay is active
- **THEN** the Replay HUD remains visible at its current position and playback continues uninterrupted
