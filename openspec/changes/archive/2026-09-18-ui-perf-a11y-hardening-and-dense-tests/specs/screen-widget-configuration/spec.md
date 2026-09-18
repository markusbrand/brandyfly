## MODIFIED Requirements

### Requirement: In-Place Edit Mode Widget Configuration
The application SHALL provide an in-place configuration interface within Edit Mode that enables pilots to adjust both placement bounds and widget-specific styling properties across the high-density grid without layout overflows across any supported widget dimensions.

#### Scenario: Opening widget tune dialog
- **WHEN** a pilot taps the configure/tune button on a widget frame in Edit Mode
- **THEN** the application SHALL present a configuration sheet containing style selectors, layer switches, and position/dimension controls specific to that widget type with bounds matching the 8-column coordinate space.

#### Scenario: Applying widget configuration changes
- **WHEN** changes in the widget configuration dialog are applied
- **THEN** the updated properties SHALL be saved to local storage and immediately reflected in the active layout view.

#### Scenario: Granular stepper resize and nudge controls
- **WHEN** a pilot uses the position nudge or width/height stepper buttons in Edit Mode
- **THEN** the widget SHALL adjust position and size in single-unit increments on the 8-column grid (`w` between 1 and 8, `h` between 1 and 16)
- **AND** enforce boundary limits preventing widgets from overflowing canvas bounds.

#### Scenario: Corner drag resize on high-density grid
- **WHEN** a pilot drags the corner resize handle in Edit Mode
- **THEN** the widget frame SHALL snap to 8-column grid units smoothly as accumulated drag deltas cross cell threshold distances.

#### Scenario: Compact widget edit frame rendering
- **WHEN** a widget is scaled down to a compact size (e.g. 1x1, 2x1, or 2x2)
- **THEN** the edit frame header and controls SHALL scale down using fitted containers and priority icon visibility to prevent any RenderFlex overflow or text clipping.

## ADDED Requirements

### Requirement: Accessible Navigation Overlay and Safe Area Anchoring
The top navigation bar grab handle and status badges SHALL anchor below platform safe area insets and provide minimum 48x48dp interactive touch boundaries and semantic descriptions.

#### Scenario: Status bar safe area separation
- **WHEN** the application is rendered on a device or emulator with a status bar notch or camera cutout
- **THEN** the navigation grab handle and top badges SHALL render strictly below system safe area insets without visual overlap or touch collision with system gestures.

#### Scenario: Accessible grab handle tap target
- **WHEN** an assistive technology or flight pilot taps the top navigation trigger
- **THEN** the interactive hit target SHALL be at least 48dp in height and width and emit an accessible semantic action label.
