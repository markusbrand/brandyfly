## ADDED Requirements

### Requirement: Placeable Airspace Side-Cut Profile Widget
The application SHALL include the airspace side-cut profile widget in the 16x32 grid widget catalog, allowing pilots to place, position, and resize the vertical cross-section instrument on customizable flight screens.

#### Scenario: Airspace side-cut widget minimum bounds enforcement
- **WHEN** the pilot places or resizes an Airspace Side-Cut widget on a flight screen
- **THEN** the layout engine SHALL enforce minimum dimensions of 8 columns by 4 rows on the 16x32 grid.

#### Scenario: Airspace side-cut widget rendering with live telemetry
- **WHEN** the Airspace Side-Cut widget is displayed on an active screen
- **THEN** it renders the glider icon, projected glide slope, terrain elevation cross-section, and nearby airspace blocks within the forward lookahead distance.

### Requirement: Flight Canvas Airspace Alert HUD Overlay
The flight canvas SHALL render a top-anchored Airspace Warning Banner HUD whenever one or more candidate airspaces enter an Advisory, Warning, or Violation state.

#### Scenario: Visual alert presentation on proximity state change
- **WHEN** an airspace enters Advisory, Warning, or Violation status
- **THEN** the canvas displays a floating, semi-transparent status pill or banner with color-coded severity (yellow, orange, or red) showing airspace name, class, and separation distance.

#### Scenario: Banner auto-dismissal upon clearance
- **WHEN** all candidate airspaces clear proximity thresholds and return to safe separation
- **THEN** the warning banner HUD automatically dismisses from the flight canvas.
