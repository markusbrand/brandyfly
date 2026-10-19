# Spec Delta

## ADDED Requirements

### Requirement: Placeable Flight Time Instrument Widget
The application SHALL include the `flightTime` instrument widget in the 16x32 virtual grid widget catalog and layout editor, allowing pilots to place, position, and resize the flight clock and duration instrument on customizable flight screens.

#### Scenario: Catalog registration and default dimensions
- **WHEN** the pilot opens the layout editor widget picker
- **THEN** `flightTime` SHALL appear in the catalog under flight instruments with a default grid size of 4 columns by 4 rows and minimum size of 3 columns by 2 rows.

#### Scenario: Size presets and minimum bounds
- **WHEN** the pilot resizes or selects presets for `flightTime` in the inspector
- **THEN** the system SHALL offer standard presets (S: 3x2, M: 4x4, L: 8x5, Full: 16x8) and enforce minimum bounds preventing layout overflow or negative dimensions.

#### Scenario: Layout editor placement and inspector configuration
- **WHEN** the pilot places `flightTime` on the flight canvas
- **THEN** the widget SHALL render live in the layout slot, respond to edit frame selection, and support layer reordering and nudging.

### Requirement: Placeable Return to Launch Instrument Widget
The application SHALL include the `returnGlide` instrument widget in the 16x32 virtual grid widget catalog and layout editor, allowing pilots to place, position, and resize the return glide instrument on customizable flight screens.

#### Scenario: Catalog registration and default dimensions
- **WHEN** the pilot opens the layout editor widget picker
- **THEN** `returnGlide` SHALL appear in the catalog under navigation/instruments with a default grid size of 6 columns by 4 rows and minimum size of 4 columns by 3 rows.

#### Scenario: Size presets and minimum bounds
- **WHEN** the pilot resizes or selects presets for `returnGlide` in the inspector
- **THEN** the system SHALL offer standard presets (S: 4x3, M: 6x4, L: 8x5, Full: 16x8) and enforce minimum bounds.

#### Scenario: Layout editor placement and inspector configuration
- **WHEN** the pilot places `returnGlide` on the flight canvas
- **THEN** the widget SHALL render live in the layout slot, participate in alignment snapping and collision highlighting, and persist its bounds in screen configuration.
