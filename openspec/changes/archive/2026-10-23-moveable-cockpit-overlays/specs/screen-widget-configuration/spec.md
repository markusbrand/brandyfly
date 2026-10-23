## MODIFIED Requirements

### Requirement: Floating Docked Widget Inspector Panel
The application SHALL display an elevated unified Edit Mode Dock combining the `WidgetInspectorPanel` (when selected) and `EditToolbar` in Edit Mode. The dock SHALL automatically dodge selected widgets by default, support free 2D dragging with safe-area clamping, reset to auto-dodge, minimize into a compact pill, and reflow controls to available width without scaling.

#### Scenario: Displaying inspector panel upon widget selection
- **WHEN** any widget on the active screen is selected in Edit Mode and the dock is in automatic dodge mode
- **THEN** the application SHALL render the unified Edit Mode Dock (Inspector Panel above the Edit Toolbar) on the side of the canvas away from the selected widget: at the bottom edge when the selected widget's center lies in the upper half of a tall canvas, at the top edge when the selected widget's center lies in the lower half of a tall canvas, and in a side panel on wide canvases at least 600 dp wide (on the side opposite the selected widget's center)
- **AND** display the widget type title, coordinate position `[x, y]`, grid dimensions `[w x h]`, current content tier, and current stack layer indicator `Layer X/Y`.

#### Scenario: Inspector does not cover the selected widget in portrait
- **WHEN** a widget whose center lies in the lower half of a tall canvas is selected while the Edit Mode Dock is in automatic dodge mode
- **THEN** both the Inspector Panel and the Edit Toolbar SHALL move together as a unified dock to the top edge and SHALL NOT overlap the selected widget's bounds in the lower half.

#### Scenario: Free-dragging the unified edit dock overrides automatic dodge
- **WHEN** the pilot drags the Edit Mode Dock header or drag handle in Edit Mode
- **THEN** the unified dock (Inspector Panel and Edit Toolbar together) SHALL track the 2D pan gesture in real time and remain clamped within the viewport safe area bounds
- **AND** SHALL retain that manual floating position across subsequent widget selections or edits until the user taps the reset-to-auto-dodge control or exits Edit Mode.

#### Scenario: Resetting manual edit dock position to auto-dodge
- **WHEN** the Edit Mode Dock has been manually dragged to a custom position and the pilot taps the auto-dodge reset button on the dock
- **THEN** the dock SHALL clear its manual offset and immediately return to automatic selected-widget dodging.

#### Scenario: Minimizing and expanding the unified edit dock
- **WHEN** the pilot taps the minimize button on the Edit Mode Dock
- **THEN** the Inspector Panel and full Edit Toolbar SHALL collapse into a compact floating pill showing the active edit status, expand toggle, and quick Done action so the underlying 16x32 grid is unobstructed
- **AND WHEN** the pilot taps the expand button on the minimized edit pill
- **THEN** the full unified Edit Mode Dock SHALL restore at its clamped position.

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
