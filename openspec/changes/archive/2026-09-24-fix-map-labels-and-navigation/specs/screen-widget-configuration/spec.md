## MODIFIED Requirements

### Requirement: Accessible Navigation Overlay and Safe Area Anchoring
The top navigation bar grab handle and status badges SHALL anchor below platform safe area insets and provide minimum 48x48dp interactive touch boundaries and semantic descriptions. The overlay layer MUST NOT swallow touch events or gestures intended for UI elements (such as `ChoiceChip` selectors) that reside on layers beneath it in the widget tree.

#### Scenario: Status bar safe area separation
- **WHEN** the application is rendered on a device or emulator with a status bar notch or camera cutout
- **THEN** the navigation grab handle and top badges SHALL render strictly below system safe area insets without visual overlap or touch collision with system gestures.

#### Scenario: Accessible grab handle tap target
- **WHEN** an assistive technology or flight pilot taps the top navigation trigger
- **THEN** the interactive hit target SHALL be at least 48dp in height and width and emit an accessible semantic action label.

#### Scenario: Overlay touch passthrough to ChoiceChips
- **WHEN** the top navigation overlay is expanded and the user taps on a `ChoiceChip` (e.g. Normal Flight Screen, Alpine Map Screen)
- **THEN** the tap event SHALL correctly pass through the parent gesture arena of the `TopNavBarOverlay` and trigger the selection of the underlying chip.
