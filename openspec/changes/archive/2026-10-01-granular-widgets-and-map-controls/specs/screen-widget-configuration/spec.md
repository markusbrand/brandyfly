## MODIFIED Requirements

### Requirement: In-Place Edit Mode Widget Configuration
The application SHALL provide an in-place configuration interface within Edit Mode that enables pilots to adjust both placement bounds and widget-specific styling properties across the 16-column by 32-row grid without layout overflows across any supported widget dimensions. All editing paths (corner drag, steppers, nudge arrows, inspector, configuration sheet) SHALL apply the same bounds and per-widget-type minimum size rules.

#### Scenario: Opening widget tune dialog
- **WHEN** a pilot taps the configure/tune button on a widget frame in Edit Mode
- **THEN** the application SHALL present a configuration sheet containing style selectors, layer switches, and position/dimension controls specific to that widget type with bounds matching the 16-column by 32-row coordinate space.

#### Scenario: Applying widget configuration changes
- **WHEN** changes in the widget configuration dialog are applied
- **THEN** the updated properties SHALL be saved to local storage and immediately reflected in the active layout view.

#### Scenario: Granular stepper resize and nudge controls
- **WHEN** a pilot uses the position nudge or width/height stepper buttons in Edit Mode
- **THEN** the widget SHALL adjust position and size in single-unit increments on the 16x32 grid (`w` between the widget type's minimum width and 16, `h` between the widget type's minimum height and 32)
- **AND** enforce boundary limits preventing widgets from overflowing canvas bounds (`x + w <= 16`, `y + h <= 32`).

#### Scenario: Corner drag resize on high-density grid
- **WHEN** a pilot drags the corner resize handle in Edit Mode
- **THEN** the widget frame SHALL snap to grid units as accumulated drag deltas cross cell threshold distances
- **AND** SHALL stop shrinking at the widget type's minimum size.

#### Scenario: Compact widget edit frame rendering
- **WHEN** a widget is scaled down to its minimum size (e.g. 1x1 or 2x1 on the 16x32 grid)
- **THEN** the edit frame SHALL render its selection outline, resize handle and size tag outside or around the widget bounds without RenderFlex overflow or text clipping
- **AND** the widget content SHALL remain unobscured by edit controls.

#### Scenario: Rejected edit below minimum size
- **WHEN** any editing path requests a size smaller than the widget type's minimum
- **THEN** the application SHALL clamp the size to the minimum and leave the persisted placement valid.

### Requirement: Fullscreen Edge-to-Edge Flight Screen Canvas
The application SHALL render the active flight screen (including map, thermal view, and instrument widgets) across 100% of the canvas viewport edge-to-edge using a fixed 16-column by 32-row virtual grid whose cell width and height are derived from the canvas size, so that the full layout always fits the canvas without scrolling.

#### Scenario: Fullscreen flight rendering without static AppBars
- **WHEN** the pilot is in active flight, simulated flight, or replay mode
- **THEN** the flight layout canvas SHALL span the full display width and height
- **AND** no permanent top AppBar or static session card SHALL occupy screen space.

#### Scenario: Dynamic viewport scaling for layout strategies
- **WHEN** a flight screen is rendered in any layout strategy (Freeform HUD, Snap-to-Grid, or Sidebar Dashboard)
- **THEN** cell width SHALL equal canvas width / 16 and cell height SHALL equal canvas height / 32
- **AND** background map or thermal widgets placed at full dimensions (16x32) SHALL render edge-to-edge without gaps or borders.

#### Scenario: No scrolling in flight canvas
- **WHEN** any flight screen is rendered in flight, simulation, replay or edit mode
- **THEN** the flight canvas SHALL NOT be scrollable and every placed widget SHALL be fully visible within the canvas.

#### Scenario: Legacy 4-column coordinate migration
- **WHEN** an existing saved screen configuration utilizing the legacy 4-column coordinate space is loaded
- **THEN** the layout engine SHALL first upscale widget positions and dimensions by 2 into the 8-column space and then apply the 8-column migration.

#### Scenario: Legacy 8-column coordinate migration
- **WHEN** an existing saved screen configuration utilizing the 8-column coordinate space with `R` effective rows (`R = max(8, lowest widget bottom edge)`) is loaded
- **THEN** the layout engine SHALL map `x` and `w` by a factor of 2 and map vertical edges proportionally (`y' = round(y * 32 / R)`, `bottom' = round((y + h) * 32 / R)`, `h' = max(1, bottom' - y')`)
- **AND** clamp results to widget type minimums and grid bounds
- **AND** persist the migrated configuration with the current schema version.

#### Scenario: Migration failure fallback
- **WHEN** a saved configuration cannot be parsed or migrated
- **THEN** the application SHALL keep the original stored payload in a backup slot, load the default configuration, and remain operable without crashing.

### Requirement: High-Density Zero-Dead-Space Instrument Widgets
Instrument widgets SHALL minimize internal padding and margins and select one of three content tiers based on their rendered pixel size: **tiny** (shortest side < 40 dp: value only), **compact** (shortest side < 80 dp: value plus short label or unit), and **regular** (full label, value and unit). Digits SHALL scale to fill the tier's value area.

#### Scenario: Numeric instrument widget typography maximization
- **WHEN** a numeric instrument widget (Altitude, Speed, Glide, HAG) is placed on a screen
- **THEN** the widget SHALL minimize internal padding (<= 3px) and expand numerical digits to fill the value area with maximum legibility
- **AND** align the label and unit cleanly without leaving unused dead space across sizes from 1x1 up to full screen width.

#### Scenario: Responsive vario bar expansion within allocated bounds
- **WHEN** the vario lift/sink bar widget is rendered on a screen
- **THEN** the indicator bar and numerical climb/sink text SHALL dynamically scale to fill the full height and width of the widget cell across varying aspect ratios.

#### Scenario: Responsive sparkline and wind widget rendering
- **WHEN** altitude sparkline charts or wind direction indicators are rendered
- **THEN** graph canvases, compass roses, and wind vector arrows SHALL utilize the maximum available bounding area with minimal label padding.

#### Scenario: Compact numeric widget rendering
- **WHEN** a numeric widget is sized to a single compact cell (e.g. 2x1 or 1x1 on the 16x32 grid)
- **THEN** the value, label, and unit SHALL scale gracefully according to the content tier and remain legible without clipping or text overflow.

#### Scenario: Tiny tier rendering
- **WHEN** an instrument widget renders with a shortest side below 40 dp
- **THEN** it SHALL show only its primary value (or primary graphic) with no label or unit, without clipping or overflow.

#### Scenario: Tier selection follows rendered size, not grid units
- **WHEN** the same widget placement renders on canvases of different sizes
- **THEN** the content tier SHALL be chosen from the rendered pixel size on each canvas.

### Requirement: Floating Docked Widget Inspector Panel
The application SHALL display an elevated floating or docked Inspector Panel in Edit Mode whenever a widget is selected, providing immediate access to widget configuration, stepper nudging, dimension adjustments, size presets, stack layer reordering controls, and removal. The panel SHALL reflow its controls to the available width instead of scaling them down.

#### Scenario: Displaying inspector panel upon widget selection
- **WHEN** any widget on the active screen is selected in Edit Mode
- **THEN** the application SHALL render the Inspector Panel docked next to the edit toolbar on the side of the canvas away from the selected widget: above the bottom toolbar on tall canvases (or at the top edge when the selected widget's center lies in the lower half), and in a side panel on wide canvases at least 600 dp wide (on the side opposite the selected widget's center)
- **AND** display the widget type title, coordinate position `[x, y]`, grid dimensions `[w x h]`, current content tier, and current stack layer indicator `Layer X/Y`.

#### Scenario: Inspector does not cover the selected widget in portrait
- **WHEN** a widget whose center lies in the lower half of a tall canvas is selected
- **THEN** the Inspector Panel SHALL be docked at the top edge and SHALL NOT overlap the selected widget's bounds

#### Scenario: Opening configuration tune dialog directly from inspector
- **WHEN** the pilot taps the "Configure" action button within the Inspector Panel
- **THEN** the application SHALL present the detailed widget configuration sheet for that widget
- **AND** allow modifying visual styles, layer toggles, and specialized settings regardless of whether the widget is at the background or foreground.

#### Scenario: Nudging and resizing via inspector controls
- **WHEN** the pilot uses the nudge directional arrows or dimension stepper buttons on the Inspector Panel
- **THEN** the selected widget SHALL adjust its grid position `(x, y)` or dimensions `(w, h)` in single-unit increments within valid screen bounds and type minimums
- **AND** update the live layout immediately.

#### Scenario: Applying a size preset
- **WHEN** the pilot taps a size preset (S, M, L or Full) on the Inspector Panel
- **THEN** the widget SHALL resize to the preset dimensions defined for its widget type, keeping its top-left position where possible and shifting inward only as needed to stay within bounds.

#### Scenario: Reordering widget stack position via inspector controls
- **WHEN** the pilot taps any of the stack reorder buttons on the Inspector Panel (`Send to Back`, `Send Backward`, `Bring Forward`, `Bring to Front`)
- **THEN** the application SHALL adjust the widget's persistent stack order accordingly
- **AND** update the `Layer X/Y` depth indicator
- **AND** disable buttons when the widget is already at the extreme bottom or top boundary of the stack.

#### Scenario: Deleting widget from inspector
- **WHEN** the pilot taps the remove/delete action within the Inspector Panel
- **THEN** the selected widget SHALL be removed from the active screen configuration
- **AND** the inspector panel SHALL dismiss with selection cleared.

#### Scenario: Inspector reflow on narrow canvas
- **WHEN** the Inspector Panel or edit toolbar is rendered narrower than its full single-row width
- **THEN** controls SHALL wrap to additional rows, collapse to icon-only buttons with tooltips, or (for an Inspector Panel narrower than 600 dp) show one control group at a time (Size, Resize, Move, Layer) selected through tabs
- **AND** every interactive control SHALL keep a hit target of at least 48x48 dp.

## ADDED Requirements

### Requirement: Edit Mode Alignment Guides and Overlap Feedback
While moving or resizing a widget in Edit Mode, the application SHALL display alignment guides when an edge or center of the edited widget aligns with an edge or center of another widget or the canvas, and SHALL highlight overlaps with other non-background widgets.

#### Scenario: Alignment guide appears on edge alignment
- **WHEN** a dragged widget's left edge reaches the same grid column as another widget's left or right edge
- **THEN** a vertical alignment guide SHALL be drawn along that column for as long as the alignment holds.

#### Scenario: Overlap highlight
- **WHEN** an edited widget's bounds intersect another widget that is not a full-canvas background map
- **THEN** the intersecting area SHALL be highlighted in a warning color
- **AND** the edit SHALL still be allowed (overlap is permitted, only flagged).

#### Scenario: Guides hidden outside edit mode
- **WHEN** the application is not in Edit Mode
- **THEN** no alignment guides, overlap highlights or grid guides SHALL be rendered.
