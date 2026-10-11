# Spec Delta

## ADDED Requirements

### Requirement: Placeable Thermal Stats Widget
The application SHALL include the `thermalStats` instrument widget in the 16x32 grid widget catalog, allowing pilots to place, position, resize, and configure the thermal session statistics widget on customizable flight screens.

#### Scenario: Thermal stats widget minimum size enforcement
- **WHEN** the pilot places or resizes a `thermalStats` widget on a flight screen
- **THEN** the layout engine SHALL enforce minimum dimensions of 3 columns by 2 rows on the 16x32 grid.

#### Scenario: Preset dimensions for thermal stats widget
- **WHEN** a pilot applies size presets to the `thermalStats` widget in the inspector panel
- **THEN** the application SHALL provide presets: S (4x3), M (6x4), L (8x5), and Full (16x8).

### Requirement: Vario Lift/Sink Bar Averager Configuration
The layout editor and widget configuration sheet SHALL allow pilots to configure the rolling average integration window (10s, 15s, 20s, or 30s) and toggle the secondary averager needle on `varioBar` placements.

#### Scenario: Selecting averager integration window
- **WHEN** the pilot configures a `varioBar` widget in Edit Mode
- **THEN** the configuration sheet SHALL provide a selector for the averager window duration (default 20 seconds).

#### Scenario: Toggling secondary averager marker visibility
- **WHEN** the pilot toggles the averager marker option in the `varioBar` configuration sheet
- **THEN** the widget SHALL display or hide the secondary averager needle accordingly while preserving instant climb bar display.
