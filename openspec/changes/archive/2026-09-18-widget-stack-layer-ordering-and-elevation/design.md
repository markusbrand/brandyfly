## Context

Currently, `LayoutStrategyContainer._getOrderedWidgets` applies a hardcoded sort based on `WidgetType` (`map` -> 0, `thermalMap` -> 1, others -> 2). Within layer 2, instrument widgets render strictly based on their list order in `FlightScreenModel.widgets`. When in Edit Mode, widgets remain at their default stack positions even when selected. This causes overlapping widgets to intercept touches and obscure the selected widget's resize handles, nudge steppers, and drag headers. See `proposal.md` for motivation.

## Goals / Non-Goals

**Goals:**
- Provide clear z-order control over all flight widgets directly on the floating inspector bar.
- Automatically elevate any active/selected widget to the topmost foreground layer while in Edit Mode.
- Automatically restore selected widgets to their persistent z-depth upon deselection.
- Default new map widgets (`map`, `thermalMap`) to the background (index 0) and instrument widgets to the foreground (end of list).

**Non-Goals:**
- Introducing arbitrary floating-point z-index fields in the data model.
- Implementing drag-to-reorder layer panels in this change.

## Decisions

### Decision 1: List Sequence in `FlightScreenModel.widgets` as Z-Order Source of Truth
- **Choice**: The index of each widget in `FlightScreenModel.widgets` defines its persistent stack order (index 0 = background/rendered first, index `widgets.length - 1` = foreground/rendered last).
- **Rationale**:
  - Eliminates the need for new schema properties or migrations on `WidgetPlacementModel`.
  - JSON serialization of arrays naturally preserves order across application restarts.
  - Operations like "Bring to Front" or "Send to Back" map cleanly to standard list movements.
- **Alternatives Considered**:
  - *Explicit `int zIndex` on `WidgetPlacementModel`*: Requires maintaining integer normalization, potential collisions, and schema upgrades.
  - *`StackLayer` enum (`background`, `middle`, `foreground`)*: Rigid groupings that still require secondary ordering within tiers.

### Decision 2: Purely In-Memory Elevation During Edit Mode
- **Choice**: In `LayoutStrategyContainer`, `_getOrderedWidgets` accepts `isEditMode` and `selectedWidgetId`. If active, the selected widget is removed from its index and appended to the end of the returned list for rendering:
  ```dart
  List<WidgetPlacementModel> _getOrderedWidgets(
    List<WidgetPlacementModel> widgets, {
    bool isEditMode = false,
    String? selectedWidgetId,
  }) {
    final list = List<WidgetPlacementModel>.from(widgets);
    if (isEditMode && selectedWidgetId != null) {
      final index = list.indexWhere((w) => w.id == selectedWidgetId);
      if (index != -1) {
        final selected = list.removeAt(index);
        list.add(selected);
      }
    }
    return list;
  }
  ```
- **Rationale**:
  - Completely non-destructive: does not mutate the persistent screen configuration while selecting or deselecting widgets.
  - Guarantees that Flutter's `Stack` places the selected widget on top of all siblings and dispatches pointer hits to it first.
- **Alternatives Considered**:
  - *Reordering `screen.widgets` on selection*: Would corrupt persistent user z-ordering whenever a widget is selected.
  - *Floating overlay portal*: Unnecessarily complex and breaks grid-aligned position updates.

### Decision 3: Inspector Panel Stack Reorder Buttons & Indicator
- **Choice**: Add a dedicated `Stack` section to `_buildInspectorPanel` containing:
  - `Send to Back` button (`Icons.vertical_align_bottom`, tooltip 'Send to Back', disabled if already index 0).
  - `Send Backward` button (`Icons.arrow_downward`, tooltip 'Send Backward', disabled if already index 0).
  - `Layer Depth Badge` (`Layer X/Y`, e.g. `Layer 3/4` where 1 is bottom and Y is top).
  - `Bring Forward` button (`Icons.arrow_upward`, tooltip 'Bring Forward', disabled if already at top).
  - `Bring to Front` button (`Icons.vertical_align_top`, tooltip 'Bring to Front', disabled if already at top).
- **Rationale**: Direct touch access in the inspector bar gives immediate tactile control while viewing the canvas.

### Decision 4: New Widget Placement Policy
- **Choice**: In `ScreenManagerService.addWidget(WidgetType type)`:
  - If `type == WidgetType.map || type == WidgetType.thermalMap`: insert at `index 0` (`[newPlacement, ...currentActive.widgets]`).
  - Otherwise: append to the end (`[...currentActive.widgets, newPlacement]`).
- **Rationale**: Prevents full-screen maps from covering existing instruments when added, and ensures new gauges appear visibly on top.

## Risks / Trade-offs

- **[Risk]** Touches on background areas of an elevated widget intercepting lower widgets.
  - → **Mitigation**: Widgets in Edit Mode only occupy their defined grid bounding box (`x, y, w, h`). The bounding box receives taps for selection and moves, which is the intended behavior for the active widget.
- **[Risk]** Index out-of-bounds or invalid swap during rapid reordering.
  - → **Mitigation**: Reordering methods in `ScreenManagerService` check current index boundaries (`index > 0` for backwards, `index < widgets.length - 1` for forwards) and return early if a move is invalid.
- **[Risk]** Default screens with hardcoded widgets might assume type-based sorting.
  - → **Mitigation**: `UIConfig.defaultConfig()` already places `w_map` at index 0 and instruments afterwards. Removing the type-based sort in `_getOrderedWidgets` ensures consistent list-driven rendering.

## Migration Plan

No database or file schema migrations needed. Existing configurations load their widget lists in the exact order saved.
