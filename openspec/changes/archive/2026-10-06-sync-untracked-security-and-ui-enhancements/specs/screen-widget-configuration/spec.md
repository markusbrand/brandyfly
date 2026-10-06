## MODIFIED Requirements

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
- **THEN** it SHALL show only its primary value (or primary graphic) with no label or unit, without clipping or overflow
- **AND** for edge-style vario indicators (`LiftSinkBarStyle.verticalEdgeBar`), the widget SHALL preserve and render its dedicated continuous vertical edge bar graphic across the slot rather than collapsing into the tiny numeric pill.

#### Scenario: Tier selection follows rendered size, not grid units
- **WHEN** the same widget placement renders on canvases of different sizes
- **THEN** the content tier SHALL be chosen from the rendered pixel size on each canvas.
