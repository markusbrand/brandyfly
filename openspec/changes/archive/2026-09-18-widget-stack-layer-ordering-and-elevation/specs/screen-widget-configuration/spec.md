## MODIFIED Requirements

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
The application SHALL display an elevated floating or docked Inspector Panel in Edit Mode whenever a widget is selected, providing immediate access to widget configuration, stepper nudging, dimension adjustments, stack layer reordering controls, and removal.

#### Scenario: Displaying inspector panel upon widget selection
- **WHEN** any widget on the active screen is selected in Edit Mode
- **THEN** the application SHALL render the Inspector Panel docked above the bottom edit toolbar
- **AND** display the widget type title, coordinate position `[x, y]`, grid dimensions `[w x h]`, and current stack layer indicator `Layer X/Y`.

#### Scenario: Opening configuration tune dialog directly from inspector
- **WHEN** the pilot taps the "Configure" action button within the Inspector Panel
- **THEN** the application SHALL present the detailed widget configuration sheet for that widget
- **AND** allow modifying visual styles, layer toggles, and specialized settings regardless of whether the widget is at the background or foreground.

#### Scenario: Nudging and resizing via inspector controls
- **WHEN** the pilot uses the nudge directional arrows or dimension stepper buttons on the Inspector Panel
- **THEN** the selected widget SHALL adjust its grid position `(x, y)` or dimensions `(w, h)` in single-unit increments within valid screen bounds
- **AND** update the live layout immediately.

#### Scenario: Reordering widget stack position via inspector controls
- **WHEN** the pilot taps any of the stack reorder buttons on the Inspector Panel (`Send to Back`, `Send Backward`, `Bring Forward`, `Bring to Front`)
- **THEN** the application SHALL adjust the widget's persistent stack order accordingly
- **AND** update the `Layer X/Y` depth indicator
- **AND** disable buttons when the widget is already at the extreme bottom or top boundary of the stack.

#### Scenario: Deleting widget from inspector
- **WHEN** the pilot taps the remove/delete action within the Inspector Panel
- **THEN** the selected widget SHALL be removed from the active screen configuration
- **AND** the inspector panel SHALL dismiss with selection cleared.

## ADDED Requirements

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
