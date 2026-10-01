# responsive-flight-canvas Specification

## Purpose
Defines how flight screens adapt to the canvas they are rendered in: a fixed virtual grid, tall and wide layout variants, size-based content tiers, minimum touch targets, and freedom from layout errors on every supported canvas size.

## Requirements

### Requirement: Canvas Shape Layout Variants
Each flight screen SHALL store a required tall layout and an optional wide layout. The application SHALL classify the flight canvas as **wide** when its available width is greater than its available height and **tall** otherwise, based on the space allotted to the canvas rather than device orientation or device type.

#### Scenario: Tall canvas uses tall layout
- **WHEN** the flight canvas is rendered with width <= height
- **THEN** the tall layout of the active screen SHALL be rendered.

#### Scenario: Wide canvas with a wide variant
- **WHEN** the flight canvas is rendered with width > height and the active screen has a wide layout
- **THEN** the wide layout SHALL be rendered.

#### Scenario: Wide canvas without a wide variant
- **WHEN** the flight canvas is rendered with width > height and the active screen has no wide layout
- **THEN** the tall layout SHALL be rendered stretched across the 16x32 grid without scrolling or clipping.

#### Scenario: Canvas resize switches variant
- **WHEN** the canvas changes shape at runtime (rotation, split screen, window resize) across the width = height boundary
- **THEN** the application SHALL switch to the matching variant within one frame without losing map camera state or the edit selection where the selected widget exists in both variants.

#### Scenario: Migrated screens have tall layout only
- **WHEN** a legacy configuration is migrated
- **THEN** its existing widgets SHALL become the tall layout and no wide layout SHALL be created.

### Requirement: Editing Layout Variants
Edit Mode SHALL let the pilot choose which variant (Tall or Wide) is being edited, create a wide variant by copying the tall layout, and delete a wide variant.

#### Scenario: Creating a wide variant from tall
- **WHEN** the pilot selects "Wide" in Edit Mode on a screen without a wide variant and confirms "Copy from Tall"
- **THEN** a wide variant SHALL be created with the same widgets, positions, sizes, styles and stack order
- **AND** be persisted.

#### Scenario: Editing the variant not matching the canvas shape
- **WHEN** the pilot edits the Wide variant while the canvas is tall
- **THEN** the editor SHALL preview the wide variant in a letterboxed canvas matching a wide aspect ratio of 16:9
- **AND** the flight view SHALL return to the shape-matched variant upon leaving Edit Mode.

#### Scenario: Deleting the wide variant
- **WHEN** the pilot deletes the wide variant
- **THEN** wide canvases SHALL fall back to rendering the stretched tall layout.

#### Scenario: Variants are edited independently
- **WHEN** a widget is moved, resized, added or removed in one variant
- **THEN** the other variant SHALL remain unchanged.

### Requirement: Widget Catalog Size Rules
Every widget type SHALL declare a minimum size, a default size, and S/M/L/Full preset sizes in grid units. Adding, editing, migrating and loading placements SHALL clamp placements to these rules and to grid bounds.

#### Scenario: New widget uses catalog default size
- **WHEN** a widget is added from the widget picker
- **THEN** it SHALL be placed with its catalog default size at the first free position, or at (0,0) if none is free.

#### Scenario: Out-of-range stored placement
- **WHEN** a stored placement has a size below its type minimum or extends beyond the 16x32 grid
- **THEN** it SHALL be clamped into a valid placement on load without discarding the widget.

### Requirement: Minimum Interactive Touch Targets in Flight
Interactive flight widgets (map control widgets) SHALL render with a hit target of at least 48x48 dp on the canvas they are displayed on. Edit Mode SHALL prevent resizing an interactive widget below the number of grid cells needed to reach 48 dp on the variant's current canvas, and SHALL flag interactive widgets that fall below 48 dp on the current canvas.

#### Scenario: Shrinking a map control below 48 dp
- **WHEN** the pilot tries to shrink a map control widget so that either rendered side would fall below 48 dp on the current canvas
- **THEN** the editor SHALL stop at the smallest size that keeps both sides at or above 48 dp.

#### Scenario: Map control too small after canvas change
- **WHEN** a map control widget renders below 48 dp on a side because the canvas got smaller
- **THEN** in Edit Mode it SHALL be marked with a warning badge and the inspector SHALL offer "Fix size"
- **AND** in flight it SHALL remain functional.

### Requirement: Layout-Error-Free Rendering Across Canvas Sizes
Every widget type, in every visual style and every content tier, SHALL render without layout exceptions (RenderFlex overflow, unbounded constraints, misplaced parent data) on canvases of 390x844, 844x390 and 1280x800 logical pixels, both in flight and in Edit Mode with the widget selected.

#### Scenario: Overflow sweep on reference canvases
- **WHEN** each widget type and style is rendered at its catalog minimum, each preset size and full size on each reference canvas
- **THEN** no layout exception SHALL be reported.

#### Scenario: Edit chrome on wide windows
- **WHEN** the inspector panel, edit toolbar or widget configuration sheet is shown on a canvas wider than 840 dp
- **THEN** it SHALL be constrained to a maximum width of 560 dp rather than stretching edge-to-edge (the configuration sheet centered, the inspector and toolbar docked as a side panel away from the selected widget on wide canvases, or centered on tall canvases).

#### Scenario: Zero-size canvas
- **WHEN** the flight canvas momentarily receives zero or unbounded constraints (e.g. during startup or inside a scroll parent)
- **THEN** the canvas SHALL render nothing or a fallback size without throwing and recover on the next valid layout.
