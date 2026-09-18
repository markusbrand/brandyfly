## MODIFIED Requirements

### Requirement: Viewport and Safe Area Boundary Clamping
The simulation overlay SHALL constrain its movement to remain entirely visible within the display viewport and safe area margins, and collapse cleanly without content clipping.

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
