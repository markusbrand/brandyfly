# center-glider-map-with-auto-recenter Specification

## Purpose

Keeps the paraglider position marker continuously anchored on the flight map and thermal radar screen, with orientation-aware viewport positioning and automatic re-centering after temporary manual inspection.

## Requirements

### Requirement: Continuous Glider Centering
The application SHALL keep the paraglider position marker anchored at the target screen position as flight telemetry coordinates update.

#### Scenario: Telemetry coordinate stream update
- **WHEN** incoming GPS coordinates or mock flight steps advance
- **AND** the map is in center-locked state (`_centerOnPilot == true`)
- **THEN** `MapWidget` moves its camera so that the glider marker remains anchored at the designated screen coordinates.

#### Scenario: In-flight zoom adjustments
- **WHEN** the pilot zooms in or out using the HUD buttons or pinch gestures while centered
- **THEN** the map zooms relative to the glider anchor position rather than drifting away.

### Requirement: Orientation-Specific Viewport Anchoring
The application SHALL adjust the glider anchor position based on the active map orientation mode.

#### Scenario: North-Up orientation positioning
- **WHEN** `widget.orientation == MapOrientation.northUp`
- **THEN** the glider position marker is rendered at exact 50% width and 50% height (true center) of the viewport.
- **AND** the glider arrow rotates to match the pilot's heading in degrees.

#### Scenario: Track-Up forward-looking bias positioning
- **WHEN** `widget.orientation == MapOrientation.trackUp`
- **THEN** the glider position marker is rendered pointing straight UP at 50% width and 40% from the bottom (60% from the top) of the viewport.
- **AND** the map tile camera rotates by `-headingDeg` under the anchored glider position.

### Requirement: Thermal Map True Centering
The application SHALL render the glider in `ThermalMapWidget` at exact 50% X / 50% Y true center.

#### Scenario: Thermal radar rendering
- **WHEN** `ThermalMapWidget` is rendered in any thermal style (XCtrack bubbles, Burnair core assist, Navigator ribbon)
- **THEN** the glider icon is positioned at exact 50% X / 50% Y of the canvas with equal 360-degree radial visibility.

### Requirement: Temporary Pan and Inactivity Auto-Recenter Timer
The application SHALL permit temporary manual panning of the map and automatically restore center-lock after 6 seconds of user inactivity.

#### Scenario: User pans the map
- **WHEN** the pilot drags/pans either `MapWidget` or `ThermalMapWidget`
- **THEN** center-lock is temporarily disengaged, the map camera moves across geographic coordinates following the drag gesture, and an inactivity timer of 6 seconds is started/reset.
- **AND** the pilot position marker, flight track breadcrumbs, airspace polygons, and thermal overlays in `MapWidget` stay anchored to their respective earth coordinates rather than translating across a static base map.

#### Scenario: Inactivity timeout triggers auto-recenter
- **WHEN** 6 seconds elapse without any further pan/drag touch events
- **THEN** the map automatically recenters on the pilot's current position and restores center-locked tracking.

#### Scenario: Manual recenter button tap
- **WHEN** the pilot taps the HUD "Recenter" button before the timer expires
- **THEN** the inactivity timer is cancelled, and the map immediately snaps back to center-locked tracking.

### Requirement: Recenter and Zoom from External Controls
The map SHALL accept zoom-in, zoom-out and recenter commands from map control widgets placed elsewhere on the screen, applying the same anchoring, center-lock and inactivity-timer rules as its built-in HUD buttons, and SHALL publish its center-lock state and zoom limits so external controls can reflect them.

#### Scenario: External recenter restores anchoring
- **WHEN** the map is in a temporary pan state and an external recenter command is received
- **THEN** the inactivity timer SHALL be cancelled, center-lock SHALL be restored, and the glider SHALL return to its orientation anchor (true center for North-Up, 50% width / 60% from top for Track-Up).

#### Scenario: External zoom during temporary pan
- **WHEN** the map is in a temporary pan state and an external zoom command is received
- **THEN** the map SHALL zoom around the current camera center and the 6-second inactivity timer SHALL be restarted.

#### Scenario: Center-lock state published
- **WHEN** center-lock changes due to a pan gesture, timer expiry, built-in button or external command
- **THEN** the new state SHALL be observable by external controls within one frame.

#### Scenario: Map disposed while controls exist
- **WHEN** the map widget is removed or the screen changes
- **THEN** pending commands from external controls SHALL be dropped without error and the inactivity timer SHALL be cancelled.
