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
Each flight screen SHALL encapsulate its own layout strategy, unique screen identifier, display title, auto-switching trigger rules, and ordered collection of placed widgets.

#### Scenario: Screen-specific layout strategy rendering
- **WHEN** a flight screen is configured with a specific layout strategy (e.g. Freeform HUD, Snap-to-Grid, or Sidebar Dashboard)
- **THEN** the application SHALL render that screen using its defined strategy without affecting the layout strategy of other screens

#### Scenario: Auto-switching screen trigger execution
- **WHEN** flight telemetry indicates sustained circling lift and a screen is configured with the thermal circling trigger
- **THEN** the application SHALL automatically switch the active view to that thermaling screen

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

### Requirement: Scoped Global Settings Panel
The primary application Settings panel SHALL be scoped strictly to global concerns (Flight Computer sensor thresholds, Vario audio, Screen management, Cloud sync, and Shell preferences) and SHALL NOT expose widget-specific styling controls.

#### Scenario: Accessing global settings
- **WHEN** the pilot opens the main application Settings screen
- **THEN** only global system, sensor, screen-list, and integration settings SHALL be presented

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

### Requirement: On-Demand Gesture-Driven Top Navigation Overlay
The main navigation drawer and application controls SHALL remain hidden during flight and SHALL slide down on demand as a temporary overlay when triggered by a swipe-down gesture or top edge grab handle.

#### Scenario: Swipe down from top screen edge reveals navigation overlay
- **WHEN** the pilot swipes down from the top edge of the screen (or taps the top grab handle)
- **THEN** the top navigation overlay SHALL slide smoothly into view over the flight canvas
- **AND** provide access to screen switching, edit mode, flights logbook, and settings.

#### Scenario: Dismissing top navigation overlay
- **WHEN** the pilot swipes up on the open navigation overlay or taps the backdrop area outside the drawer
- **THEN** the navigation overlay SHALL slide back up and hide, returning 100% of the screen to the flight instruments.

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
The application SHALL track an active selected widget in Edit Mode, support selection via direct tap or a dedicated toolbar selector, and render an active highlight frame around the selected widget without altering operative flight layering.

#### Scenario: Selecting a widget via direct canvas tap in Edit Mode
- **WHEN** the user is in Edit Mode and taps on a placed widget (including an exposed area of a background Map)
- **THEN** the application SHALL set that widget as the currently selected widget
- **AND** render an active selection border around its bounding box.

#### Scenario: Selecting an obscured background widget via the toolbar Layer Selector
- **WHEN** a background widget (such as a full-screen Map or Thermal Map) is partially or fully covered by other widgets in Edit Mode
- **AND** the pilot selects the widget from the Edit Mode bottom toolbar layer selector
- **THEN** the application SHALL set the background widget as the active selected widget
- **AND** highlight its boundaries without requiring physical tap coordinates on the canvas.

#### Scenario: Deselecting a widget
- **WHEN** a widget is selected in Edit Mode and the user taps outside all widgets or taps the "Deselect" button on the inspector panel
- **THEN** the selection SHALL be cleared (`selectedWidgetId = null`)
- **AND** the active highlight frame and inspector panel SHALL dismiss.

#### Scenario: Clearing selection upon exiting Edit Mode
- **WHEN** the user leaves Edit Mode (tapping "Done Editing" or toggling edit mode off)
- **THEN** the application SHALL automatically clear any active widget selection
- **AND** restore the standard operative flight interface with zero selection overlays.

### Requirement: Floating Docked Widget Inspector Panel
The application SHALL display an elevated floating or docked Inspector Panel in Edit Mode whenever a widget is selected, providing immediate access to widget configuration, stepper nudging, dimension adjustments, and removal.

#### Scenario: Displaying inspector panel upon widget selection
- **WHEN** any widget on the active screen is selected in Edit Mode
- **THEN** the application SHALL render the Inspector Panel docked above the bottom edit toolbar
- **AND** display the widget type title, coordinate position `[x, y]`, and grid dimensions `[w x h]`.

#### Scenario: Opening configuration tune dialog directly from inspector
- **WHEN** the pilot taps the "Configure" action button within the Inspector Panel
- **THEN** the application SHALL present the detailed widget configuration sheet for that widget
- **AND** allow modifying visual styles, layer toggles, and specialized settings regardless of whether the widget is at the background or foreground.

#### Scenario: Nudging and resizing via inspector controls
- **WHEN** the pilot uses the nudge directional arrows or dimension stepper buttons on the Inspector Panel
- **THEN** the selected widget SHALL adjust its grid position `(x, y)` or dimensions `(w, h)` in single-unit increments within valid screen bounds
- **AND** update the live layout immediately.

#### Scenario: Deleting widget from inspector
- **WHEN** the pilot taps the remove/delete action within the Inspector Panel
- **THEN** the selected widget SHALL be removed from the active screen configuration
- **AND** the inspector panel SHALL dismiss with selection cleared.
