## MODIFIED Requirements

### Requirement: Collapsible On-Demand Replay Control Overlay with speed multiplier cycling
The replay controller SHALL display a collapsible, free-floating overlay supporting play/pause, timeline scrubbing, timestamp display, exit action, discrete speed multipliers (1x, 2x, 5x, 10x) that cycle in a continuous loop back to 1x upon successive taps, swipe/tap minimization and expansion to minimize screen footprint during playback, and real-time drag repositioning across the screen constrained by viewport boundaries. The dragged position SHALL remain active only for the current replay session and SHALL reset to the default location upon initiating a new replay or restarting the app.

#### Scenario: Cycling replay playback speed
- **WHEN** the user taps the speed button on the Replay HUD while at 1x speed
- **THEN** the speed increments to 2x, then 5x, then 10x
- **AND WHEN** the user taps the speed button while at 10x speed
- **THEN** the playback speed cycles back to 1x original speed

#### Scenario: Collapsing and expanding replay controls on demand
- **WHEN** the user swipes down on the Replay HUD or taps the collapse toggle
- **THEN** the timeline scrubber and controls SHALL minimize into a compact handle and title bar
- **AND WHEN** the user swipes up or taps the expand handle
- **THEN** the full scrubber and playback buttons SHALL expand back into view without shifting the overlay anchor point unexpectedly

#### Scenario: Swiping between flight screens during replay
- **WHEN** the user swipes between custom instrument layouts and the thermaling screen while replay is active
- **THEN** the Replay HUD remains visible at its current floating coordinates and playback continues uninterrupted

#### Scenario: Dragging playback overlay across the screen
- **WHEN** the user drags or pans on non-interactive areas of the replay control overlay
- **THEN** the overlay tracks the drag gesture in real time and updates its on-screen floating position
- **AND** interactive child controls (slider thumb, play/pause, step buttons, speed chip, close button) retain touch precedence without initiating drag moves

#### Scenario: Viewport and safe area boundary clamping
- **WHEN** the user drags the replay overlay toward any screen boundary or changes viewport size
- **THEN** the overlay coordinates are clamped to ensure the entire card remains within visible viewport bounds and safe area insets

#### Scenario: Session-only position lifetime
- **WHEN** the user closes the active replay session and subsequently starts a replay for the same or another flight
- **THEN** the replay control overlay appears at its default initial position rather than retaining the previously dragged coordinates
