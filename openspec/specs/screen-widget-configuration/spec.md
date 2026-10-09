---
id: SPEC-SCREEN-WIDGET-CONFIGURATION
type: sub-spec
parent: EPIC-01-CORE
title: Screen Widget Configuration
issue_number: 62
status: closed
labels:
  - spec
  - openspec
---

# screen-widget-configuration Specification

## Purpose

Provides autonomous per-screen layout strategies, widget-specific styling and layer customizations, in-place edit mode configuration, and simplified global settings for flight instrumentation.

## Requirements

### Requirement: Screen-Level Layout Strategy and Management
Each flight screen SHALL encapsulate its own layout strategy, unique screen identifier, display title, auto-switching trigger rules, and ordered collection of placed widgets. The system SHALL preserve the active screen identifier and widget selection state when modifying or deleting inactive screens, only transitioning the active screen when the currently active screen is explicitly deleted.

#### Scenario: Screen-specific layout strategy rendering
- **WHEN** a flight screen is configured with a specific layout strategy (e.g. Freeform HUD, Snap-to-Grid, or Sidebar Dashboard)
- **THEN** the application SHALL render that screen using its defined strategy without affecting the layout strategy of other screens

#### Scenario: Auto-switching screen trigger execution
- **WHEN** flight telemetry indicates sustained circling lift and a screen is configured with the thermal circling trigger
- **THEN** the application SHALL automatically switch the active view to that thermaling screen

#### Scenario: Removing an inactive screen maintains active screen and widget selection
- **WHEN** the user or system removes a screen whose ID is not the active screen ID
- **THEN** the application SHALL remove the target screen from the configuration
- **AND** the active screen ID and selected widget ID SHALL remain unchanged

#### Scenario: Removing non-existent screen ID is a safe no-op
- **WHEN** a screen removal request is received for an ID that does not exist in the screen configuration
- **THEN** the application SHALL retain the existing screen configuration, active screen ID, and widget selection without broadcasting spurious change notifications

#### Scenario: Removing active screen transitions to next available screen
- **WHEN** the user removes the screen that is currently active and other screens remain
- **THEN** the application SHALL remove the screen, clear widget selection, and set the active screen ID to the first available remaining screen

### Requirement: Widget Instance Specific Configuration
Each widget placement on a screen SHALL encapsulate its own visual style, zoom level, and specialized presentation options, falling back to default built-in styles when unconfigured.

#### Scenario: Independent map widget configurations
- **WHEN** multiple map widgets exist across different flight screens
- **THEN** each map widget SHALL independently maintain its own terrain style, initial zoom level, orientation mode (e.g. Track Up vs North Up), and layer visibility toggles (airspaces, thermals, trail, contours)

#### Scenario: Per-widget zoom level configuration
- **WHEN** a pilot adjusts the zoom level in the map configuration dialog
- **THEN** the selected zoom level SHALL be persisted per widget and restored upon application restart

#### Scenario: Numeric widget style and label customization
- **WHEN** a pilot customizes a numeric instrument widget (such as Altitude or Speed)
- **THEN** the widget SHALL display using its selected visual style (Minimalist, High Contrast, Circular Gauge, or Retro Digital) and configured custom label/unit override

#### Scenario: Default style inheritance for new widgets
- **WHEN** a new widget is added to a screen from the widget picker
- **THEN** the widget SHALL instantiate with its built-in default style and configuration without requiring global fallback lookups

### Requirement: OpenStreetMap Tile Background and Offline Caching
The application SHALL render OpenStreetMap, OpenTopoMap, and custom raster tiles in `MapWidget` and cache downloaded tiles locally to enable seamless offline operation across all valid camera zoom levels.

#### Scenario: Online tile rendering and attribution
- **WHEN** network connectivity is available and the map is displayed
- **THEN** OpenStreetMap/OpenTopoMap raster tiles SHALL render centered on the pilot coordinates with valid attribution and compliant `User-Agent`.

#### Scenario: Offline tile serving and graceful fallback
- **WHEN** the device is offline during flight
- **THEN** cached map tiles SHALL be served from local disk without UI stalls or unhandled exceptions on cache misses.

#### Scenario: Continuous rendering at over-zoom levels
- **WHEN** the pilot zooms in beyond the tile server's native maximum zoom level (e.g. zoom 17.5 to 19.0)
- **THEN** the map tile layer SHALL remain visible and scale the available native zoom tiles without going blank or disappearing.

#### Scenario: Map style switching without stale tile state
- **WHEN** the pilot switches between different map visual styles (Alpine Topo, Vector HUD, Thermal Radar, Shaded Relief)
- **THEN** the map tile layer SHALL immediately recreate with the newly selected tile provider without retaining stale tiles or blank canvas states.

#### Scenario: Geographic telemetry tracking and replay
- **WHEN** live or replayed GPS telemetry coordinates update
- **THEN** the map SHALL synchronize the pilot marker position, heading orientation, and active flight breadcrumb polyline.

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

### Requirement: Scoped Global Settings Panel
The primary application Settings panel SHALL be scoped strictly to global concerns (Flight Computer sensor thresholds, Vario audio, Screen management, Cloud sync, and Shell preferences) and SHALL NOT expose widget-specific styling controls.

#### Scenario: Accessing global settings
- **WHEN** the pilot opens the main application Settings screen
- **THEN** only global system, sensor, screen-list, and integration settings SHALL be presented

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

### Requirement: On-Demand Gesture-Driven Top Navigation Overlay
The main navigation drawer and application controls SHALL remain hidden during flight and SHALL slide down on demand as a temporary overlay when triggered by a swipe-down gesture or top edge grab handle. All buttons, screen selector chips, and dialog triggers within the navigation drawer SHALL reliably register discrete click/tap events without interference or cancellation from enclosing scroll containers or underlying map view gesture recognizers.

#### Scenario: Swipe down from top screen edge reveals navigation overlay
- **WHEN** the pilot swipes down from the top edge of the screen (or taps the top grab handle)
- **THEN** the top navigation overlay SHALL slide smoothly into view over the flight canvas
- **AND** provide access to screen switching, edit mode, flights logbook, and settings.

#### Scenario: Dismissing top navigation overlay
- **WHEN** the pilot swipes up on the open navigation overlay or taps the backdrop area outside the drawer
- **THEN** the navigation overlay SHALL slide back up and hide, returning 100% of the screen to the flight instruments.

#### Scenario: Clicking screen selector chips in navigation drawer
- **WHEN** the pilot clicks any screen selector chip (whether switching to an inactive screen or re-clicking the currently active screen)
- **THEN** the application SHALL activate the selected screen (or confirm the active screen)
- **AND** automatically dismiss the navigation drawer.

#### Scenario: Clicking action buttons in navigation drawer
- **WHEN** the pilot clicks the Flights, Edit Mode, or Settings action button in the open drawer
- **THEN** the application SHALL immediately trigger the corresponding screen or panel transition
- **AND** dismiss the navigation drawer without requiring multiple clicks.

### Requirement: High-Density Zero-Dead-Space Instrument Widgets
Instrument widgets SHALL minimize internal padding and margins and select one of three content tiers based on their rendered pixel size: **tiny** (shortest side < 40 dp: value only), **compact** (shortest side < 80 dp: value plus short label or unit), and **regular** (full label, value and unit). Digits SHALL scale to fill the tier's value area. The vario lift/sink bar widget SHALL preserve its vertical edge bar graphic indicator even when assigned to tiny tier slots.

#### Scenario: Responsive vario bar expansion within allocated bounds
- **WHEN** the vario lift/sink bar widget is rendered on a screen
- **THEN** the indicator bar and numerical climb/sink text SHALL dynamically scale to fill the full height and width of the widget cell across varying aspect ratios
- **AND** the vertical edge bar style SHALL remain visible as a graphical bar indicator in tiny tier slots instead of hiding the bar graphic.

#### Scenario: Numeric instrument widget typography maximization
- **WHEN** a numeric instrument widget (Altitude, Speed, Glide, HAG) is placed on a screen
- **THEN** the widget SHALL minimize internal padding (<= 3px) and expand numerical digits to fill the value area with maximum legibility
- **AND** align the label and unit cleanly without leaving unused dead space across sizes from 1x1 up to full screen width.

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

### Requirement: Map track visualization settings
The UI configuration model and map settings interface SHALL allow pilots to configure the track history duration, older tail visibility, and vario color gradient thresholds.

#### Scenario: Configuring track history window
- **WHEN** the pilot accesses the Map Widget settings or UI settings panel
- **THEN** the system SHALL provide a history window selector offering options (e.g., 2, 5, 10, 15, 30 minutes, or Full Flight)
- **AND** updates to this setting SHALL immediately re-filter the rendered track polylines.

#### Scenario: Persisting map track preferences
- **WHEN** the user modifies map track history or threshold settings
- **THEN** the configuration SHALL be persisted in `UIConfig` and restored across application restarts.

### Requirement: Edit Mode Widget Selection and Active Highlighting
The application SHALL track an active selected widget in Edit Mode, support selection via direct tap or a dedicated toolbar selector, render an active highlight frame around the selected widget, and temporarily elevate the selected widget to the topmost foreground layer of the layout Stack during editing.

#### Scenario: Selecting a widget via direct canvas tap in Edit Mode
- **WHEN** the user is in Edit Mode and taps on a placed widget (including an exposed area of a background Map)
- **THEN** the application SHALL set that widget as the currently selected widget
- **AND** render an active selection border around its bounding box
- **AND** temporarily elevate the widget to the topmost foreground layer of the layout Stack so all edit headers, resize handles, and boundary indicators render above all other widgets.

#### Scenario: Selecting an obscured background widget via the toolbar Layer Selector
- **WHEN** a background widget (such as a full-screen Map or Thermal Map) is partially or fully covered by other widgets in Edit Mode
- **AND** the pilot selects the widget from the Edit Mode bottom toolbar layer selector
- **THEN** the application SHALL set the background widget as the active selected widget
- **AND** highlight its boundaries without requiring physical tap coordinates on the canvas
- **AND** temporarily elevate the widget to the topmost foreground layer so its edit handles and configuration options are fully accessible.

#### Scenario: Deselecting a widget
- **WHEN** a widget is selected in Edit Mode and the user taps outside all widgets or taps the "Deselect" button on the inspector panel
- **THEN** the selection SHALL be cleared (`selectedWidgetId = null`)
- **AND** the active highlight frame and inspector panel SHALL dismiss
- **AND** the widget SHALL immediately return to its original configured stack depth position.

#### Scenario: Clearing selection upon exiting Edit Mode
- **WHEN** the user leaves Edit Mode (tapping "Done Editing" or toggling edit mode off)
- **THEN** the application SHALL automatically clear any active widget selection
- **AND** restore the standard operative flight interface with all widgets rendered in their configured persistent stack depth order with zero selection overlays.

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

### Requirement: Persistent Widget Stack Depth and Layer Placement Policy
The application SHALL maintain widget rendering order based on each widget's position within the active screen widget collection, persisting this order across sessions, and applying default placement policies when adding new widgets.

#### Scenario: Default placement for map-type widgets
- **WHEN** a new Map or Thermal Map widget (`WidgetType.map` or `WidgetType.thermalMap`) is added to the active screen
- **THEN** the application SHALL place the new widget at the background (index 0) of the widget stack.

#### Scenario: Default placement for instrument widgets
- **WHEN** any standard instrument widget (Altitude, Speed, Vario, Wind, HAG, etc.) is added to the active screen
- **THEN** the application SHALL place the new widget at the foreground (end of the widget list) of the widget stack.

#### Scenario: Preserving stack order in flight mode
- **WHEN** the screen is rendered during operative flight, simulation, or replay mode
- **THEN** widgets SHALL render strictly according to their stored stack list sequence without hardcoded type overrides.

### Requirement: Simulation overlay touch passthrough
The simulation control overlay SHALL NOT intercept touch events on the flight instrument widgets beneath it. The overlay SHALL only capture gestures within its own visible card bounds, allowing pilots to interact with map widgets, instrument panels, and other flight controls while the simulation overlay is visible.

#### Scenario: Tapping a map widget beneath the simulation overlay
- **WHEN** the simulation control overlay is visible and the pilot taps on a visible area of a map widget that is not obscured by the overlay card
- **THEN** the tap SHALL be received by the map widget and the simulation overlay SHALL NOT consume the gesture event

#### Scenario: Dragging the simulation overlay card
- **WHEN** the pilot drags within the visible bounds of the simulation overlay card
- **THEN** the overlay card SHALL reposition according to the drag gesture and the underlying flight instruments SHALL NOT receive the drag event

### Requirement: Modular layout container architecture
The layout strategy container implementation SHALL be decomposed into focused architectural units: a layout engine responsible for grid computation and strategy selection, an edit-mode inspector panel, a widget configuration dialog, and a widget content renderer. Each unit SHALL be maintainable and testable independently.

#### Scenario: Layout engine computes grid without UI concerns
- **WHEN** the layout container renders a flight screen with any layout strategy
- **THEN** the grid cell dimensions, content height, and widget positioning SHALL be computed by a dedicated layout engine that does not contain edit-mode inspector UI, configuration dialog code, or widget content rendering logic

#### Scenario: Widget configuration dialog is independently importable
- **WHEN** a developer needs to modify the widget configuration dialog
- **THEN** the dialog SHALL reside in its own Dart file and SHALL be importable and testable without importing the entire layout container

### Requirement: Safe unbounded constraint handling in layout container
The layout container SHALL handle unbounded vertical constraints (e.g., when embedded inside a scrollable parent) by falling back to a reasonable default cell height rather than computing `infinity / N` which causes a fatal layout crash.

#### Scenario: Layout container inside unbounded vertical parent
- **WHEN** the `LayoutStrategyContainer` receives `constraints.maxHeight == double.infinity`
- **THEN** the container SHALL use a fallback cell height value and SHALL NOT crash or produce infinite layout dimensions

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
