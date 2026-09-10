## MODIFIED Requirements

### Requirement: Fullscreen Edge-to-Edge Flight Screen Canvas
The application SHALL render the active flight screen (including map, thermal view, and instrument widgets) across 100% of the display viewport edge-to-edge using a high-density 8-column layout grid coordinate system with adaptive row scaling and lowered minimum height constraints.

#### Scenario: Fullscreen flight rendering without static AppBars
- **WHEN** the pilot is in active flight, simulated flight, or replay mode
- **THEN** the flight layout canvas SHALL span the full display width and height
- **AND** no permanent top AppBar or static session card SHALL occupy screen space.

#### Scenario: Dynamic viewport scaling for layout strategies
- **WHEN** a flight screen is rendered in any layout strategy (Freeform HUD, Snap-to-Grid, or Sidebar Dashboard)
- **THEN** the grid layout SHALL dynamically scale across 8 granular columns to fill the entire available display viewport
- **AND** calculate cell heights with a lowered minimum height floor (<= 40px)
- **AND** background map or thermal widgets placed at full dimensions (8xN) SHALL render edge-to-edge without gaps or borders.

#### Scenario: Legacy 4-column coordinate migration
- **WHEN** an existing saved screen configuration utilizing the legacy 4-column coordinate space is loaded
- **THEN** the layout engine SHALL automatically upscale widget positions and dimensions (multiplying x, y, w, h by 2) to preserve identical relative screen proportions on the 8-column grid.

### Requirement: In-Place Edit Mode Widget Configuration
The application SHALL provide an in-place configuration interface within Edit Mode that enables pilots to adjust both placement bounds and widget-specific styling properties across the high-density grid.

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
- **THEN** the edit frame header and controls SHALL scale or adapt to prevent overlapping or obscuring the inner telemetry contents.

### Requirement: High-Density Zero-Dead-Space Instrument Widgets
Instrument widgets SHALL minimize internal padding and margins and dynamically scale typography and graphic indicators to maximize data density and readability within their allocated grid bounding box across both large and compact sizes.

#### Scenario: Numeric instrument widget typography maximization
- **WHEN** a numeric instrument widget (Altitude, Speed, Glide, HAG) is placed on a screen
- **THEN** the widget SHALL minimize internal padding (<= 3px) and expand numerical digits to fill the bounding box with maximum legibility
- **AND** align the label and unit cleanly without leaving unused dead space across sizes from 1x1 up to full screen width.

#### Scenario: Responsive vario bar expansion within allocated bounds
- **WHEN** the vario lift/sink bar widget is rendered on a screen
- **THEN** the indicator bar and numerical climb/sink text SHALL dynamically scale to fill the full height and width of the widget cell across varying aspect ratios.

#### Scenario: Responsive sparkline and wind widget rendering
- **WHEN** altitude sparkline charts or wind direction indicators are rendered
- **THEN** graph canvases, compass roses, and wind vector arrows SHALL utilize the maximum available bounding area with minimal label padding.

#### Scenario: Compact numeric widget rendering
- **WHEN** a numeric widget is sized to a single compact cell (e.g. 2x1 or 1x1)
- **THEN** the value, label, and unit SHALL scale gracefully and remain legible without clipping or text overflow.
