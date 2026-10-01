## ADDED Requirements

### Requirement: Field-Scoped Telemetry Rebuilds
Telemetry SHALL be delivered to the flight canvas as an immutable typed snapshot, and each instrument widget SHALL rebuild only when the snapshot fields it displays change. Layout containers, edit chrome and widgets whose displayed fields are unchanged SHALL NOT rebuild on a telemetry update.

#### Scenario: Altitude-only change
- **WHEN** a telemetry update changes altitude but leaves speed, glide, climb and wind unchanged
- **THEN** only widgets displaying altitude (altitude instrument, altitude chart, map legend) SHALL rebuild
- **AND** the layout canvas and speed, glide, vario and wind widgets SHALL NOT rebuild.

#### Scenario: Rebuild budget per tick
- **WHEN** a screen with 10 widgets receives 100 telemetry updates in which all displayed fields change
- **THEN** the layout canvas SHALL build at most once (initial build) and each instrument SHALL build at most 101 times.

#### Scenario: Stale or missing telemetry fields
- **WHEN** a snapshot field is missing or older than the stale threshold of the telemetry source
- **THEN** the instrument SHALL display its placeholder or stale indication without rebuilding unrelated widgets.

### Requirement: Edit Chrome Isolation
Edit Mode chrome (selection frames, handles, alignment guides, inspector, toolbar) SHALL rebuild only on layout, selection or edit-mode changes and SHALL NOT rebuild on telemetry updates.

#### Scenario: Telemetry during editing
- **WHEN** Edit Mode is active with a widget selected and 50 telemetry updates arrive
- **THEN** the inspector panel and edit frames SHALL NOT rebuild.

### Requirement: Single-Layer Grid Guide Painting
Edit Mode grid guides SHALL be painted by a single paint layer per canvas instead of one widget per guide line, and SHALL be repainted only when canvas size or grid geometry changes.

#### Scenario: Guide layer on 16x32 grid
- **WHEN** Edit Mode is shown on a 16x32 grid
- **THEN** grid guides SHALL be drawn by one painter and SHALL NOT repaint on telemetry updates or selection changes.
