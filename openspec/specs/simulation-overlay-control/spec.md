## Purpose

Provides free-floating drag-and-drop repositioning and boundary clamping for the flight simulation controller overlay during local mock flight testing.

## Requirements

### Requirement: Free-Floating Overlay Repositioning
The simulation overlay SHALL allow the user to drag and drop the controller anywhere across the flight screen by panning on the overlay container.

#### Scenario: User drags simulation overlay
- **WHEN** the user pans across the background or non-button areas of the simulation overlay
- **THEN** the overlay tracks the drag gesture in real time and updates its on-screen position accordingly

#### Scenario: Overlay position preserved across flight ticks
- **WHEN** periodic telemetry ticks or manual scenario advances trigger screen updates
- **THEN** the simulation overlay retains its last dragged position on screen without resetting to the default coordinate

### Requirement: Viewport and Safe Area Boundary Clamping
The simulation overlay SHALL constrain its movement to remain entirely visible within the display viewport and safe area margins.

#### Scenario: Dragging toward screen boundaries
- **WHEN** the user drags the simulation overlay toward any screen edge
- **THEN** the overlay is clamped such that no portion of the container is pushed outside the visible screen viewport or under system safe area insets

#### Scenario: Clamping on size toggle near screen edge
- **WHEN** the simulation overlay is positioned near the bottom or right screen edge and toggled between minimized and expanded states
- **THEN** the position is re-clamped immediately so the expanded content does not overflow the display boundary

### Requirement: Interaction Precedence for Child Controls
The simulation overlay SHALL preserve discrete tap interactions for all interactive child buttons without triggering a drag repositioning event.

#### Scenario: Tapping scenario navigation and control buttons
- **WHEN** the user taps the advance scenario button, reset replay button, or minimize/expand toggle button
- **THEN** the respective button action triggers immediately without displacing the overlay position
