## MODIFIED Requirements

### Requirement: Continuous Glider Centering
The application SHALL keep the paraglider position marker anchored at the target screen position as flight telemetry coordinates update, moving the camera continuously at display frame rate between fixes rather than in one step per fix.

#### Scenario: Telemetry coordinate stream update
- **WHEN** incoming GPS coordinates or mock flight steps advance
- **AND** the map is in center-locked state (`_centerOnPilot == true`)
- **THEN** `MapWidget` moves its camera so that the glider marker remains anchored at the designated screen coordinates.
- **AND** the camera follows the smoothed pilot position on every rendered frame, without a visible step when a fix arrives.

#### Scenario: In-flight zoom adjustments
- **WHEN** the pilot zooms in or out using the HUD buttons or pinch gestures while centered
- **THEN** the map zooms relative to the glider anchor position rather than drifting away.

### Requirement: Orientation-Specific Viewport Anchoring
The application SHALL adjust the glider anchor position based on the active map orientation mode.

#### Scenario: North-Up orientation positioning
- **WHEN** `widget.orientation == MapOrientation.northUp`
- **THEN** the glider position marker is rendered at exact 50% width and 50% height (true center) of the viewport.
- **AND** the glider arrow rotates to match the pilot's filtered heading in degrees.

#### Scenario: Track-Up forward-looking bias positioning
- **WHEN** `widget.orientation == MapOrientation.trackUp`
- **THEN** the glider position marker is rendered pointing straight UP at 50% width and 40% from the bottom (60% from the top) of the viewport.
- **AND** the map tile camera rotates by `-headingDeg` under the anchored glider position, using the low-pass filtered heading so that rotation is continuous and free of fix-to-fix jitter.

#### Scenario: Orientation switch
- **WHEN** the orientation changes between north-up and track-up
- **THEN** the anchor point and bearing transition smoothly to the new mode without the glider leaving the viewport.
