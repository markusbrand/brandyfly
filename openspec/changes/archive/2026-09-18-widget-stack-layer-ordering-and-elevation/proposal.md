# Proposal: Widget Stack Layer Ordering and Edit Mode Elevation

## Why

In Edit Mode, overlapping flight widgets and background map views can obscure a selected widget's bounding frame, drag handles, and corner resize controls, making layout customization difficult and error-prone. Furthermore, pilots currently have no way to define or adjust the z-order (stack depth) of individual widgets, resulting in a fixed hardcoded rendering order where instrument widgets cannot be brought forward or pushed behind other widgets.

## What Changes

- **Edit Mode Temporary Foreground Elevation**: When any widget is selected in Edit Mode, it temporarily elevates to the topmost position in the layout `Stack`, ensuring all resize handles, nudge steppers, and drag headers remain completely unobstructed. Upon deselection or exiting Edit Mode, the widget returns immediately to its configured stack position.
- **Stack Layer Reordering Controls on Floating Inspector Bar**: Provide direct stack reorder actions (`Send to Back`, `Send Backward`, `Bring Forward`, `Bring to Front`) and a visual layer depth indicator (`Layer X/Y`) on the floating inspector panel docked above the bottom toolbar.
- **Default Layer Placement Policy**: Newly placed instrument widgets default to the foreground (top of the stack), while map widgets (`WidgetType.map` and `WidgetType.thermalMap`) default to the background (bottom of the stack at index 0).
- **Persistent Stack Depth Hierarchy**: The screen layout engine uses the screen's widget collection order as the persistent source of truth for z-order, naturally persisting and restoring stack order across app launches without data migrations.

### Non-Goals
- Introducing continuous floating-point z-indexes or 3D elevation transforms.
- Allowing background map widgets to obscure critical system alerts or safety warnings.
- Changing operative flight mode telemetry rendering pipelines.

## Capabilities

### New Capabilities
None.

### Modified Capabilities
- `screen-widget-configuration`: Modifies widget configuration and layout strategy requirements to support persistent widget z-ordering, reorder actions on the docked inspector panel, default background/foreground placement rules, and temporary foreground elevation for active widgets in Edit Mode.

## Impact

- **Affected Code**:
  - `apps/mobile/lib/widgets/layout/layout_strategy_container.dart`: Dynamic ordering logic (`_getOrderedWidgets`), temporary selected widget elevation, and inspector panel stack reorder buttons.
  - `apps/mobile/lib/services/screen_manager_service.dart`: Reorder methods (`bringToFront`, `bringForward`, `sendBackward`, `sendToBack`) and default layer insertion logic in `addWidget`.
- **Offline & Safety Impact**: None. All stack operations are local, in-memory, and deterministic without remote network calls.
- **Breaking Changes**: None. Existing screen configurations preserve their saved order without schema migrations.
