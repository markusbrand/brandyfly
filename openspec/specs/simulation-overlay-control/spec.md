## Purpose

Provides free-floating drag-and-drop repositioning and boundary clamping for the flight simulation controller overlay during local mock flight testing.

## Requirements

### Requirement: Free-Floating Overlay Repositioning
The simulation overlay and shared draggable cockpit overlays SHALL allow the user to drag and drop the controller anywhere across the flight screen by panning on the overlay container or drag handle.

#### Scenario: User drags simulation overlay
- **WHEN** the user pans across the background or non-button areas of the simulation overlay
- **THEN** the overlay tracks the drag gesture in real time and updates its on-screen position accordingly

#### Scenario: Overlay position preserved across flight ticks
- **WHEN** periodic telemetry ticks or manual scenario advances trigger screen updates
- **THEN** the simulation overlay retains its last dragged position on screen without resetting to the default coordinate

#### Scenario: Re-clamping on viewport resize or orientation change
- **WHEN** the display viewport dimensions or system safe-area insets change after an overlay has been dragged
- **THEN** the overlay position SHALL automatically re-clamp so the entire overlay card remains within the visible safe area

### Requirement: Viewport and Safe Area Boundary Clamping
The simulation overlay and shared draggable cockpit overlays SHALL constrain their movement to remain entirely visible within the display viewport and safe area margins, and collapse cleanly without content clipping.

#### Scenario: Dragging toward screen boundaries
- **WHEN** the user drags the simulation overlay toward any screen edge
- **THEN** the overlay is clamped such that no portion of the container is pushed outside the visible screen viewport or under system safe area insets

#### Scenario: Clamping on size toggle near screen edge
- **WHEN** the simulation overlay is positioned near the bottom or right screen edge and toggled between minimized and expanded states
- **THEN** the position is re-clamped immediately so the expanded content does not overflow the display boundary

#### Scenario: Clean minimized state presentation
- **WHEN** the simulation overlay is toggled to minimized mode
- **THEN** secondary session metadata details SHALL be completely omitted from the layout without partial text clipping or awkward container padding.

### Requirement: Interaction Precedence for Child Controls
The simulation overlay SHALL preserve discrete tap interactions for all interactive child buttons without triggering a drag repositioning event, and allow background touches outside its bounds to pass through freely.

#### Scenario: Tapping scenario navigation and control buttons
- **WHEN** the user taps the advance scenario button, reset replay button, or minimize/expand toggle button
- **THEN** the respective button action triggers immediately without displacing the overlay position

#### Scenario: Pass-through touches outside overlay bounds
- **WHEN** the user interacts with the map or instrument widgets outside the simulation overlay card bounds
- **THEN** gestures and taps SHALL pass through directly to underlying flight widgets and the top navigation grab handle.
