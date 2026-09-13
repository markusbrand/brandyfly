## ADDED Requirements

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
