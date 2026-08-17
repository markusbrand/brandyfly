## Context

The current `FlightScreenModel` holds a list of `WidgetPlacementModel` with `x, y, w, h` attributes representing a grid layout. The current layout renderer, `LayoutStrategyContainer`, uses these values for the "Freeform HUD" and mostly ignores them for "Sidebar Dashboard". We need to implement a fully functional drag-and-drop and resize grid, likely using an existing or new grid package/approach in Flutter, and adapt `LayoutStrategyContainer` (or replace the snap to grid option) to make use of it. Furthermore, settings are currently global to `UIConfig`. We need to move widget-specific styles (like `NumericWidgetStyle`) into `WidgetPlacementModel`.

## Goals / Non-Goals

**Goals:**
- Update `WidgetPlacementModel` to store individual widget configuration (e.g. `Map<String, dynamic> settings`).
- Update `ScreenManagerService` and `UISettingsPanel` to reflect this localized configuration approach.
- Implement an interactive grid that supports dragging widgets to reposition them (update `x, y`).
- Implement resize handles on widgets in edit mode to change dimensions (update `w, h`).
- Implement a `PageView` or similar mechanism for horizontal swiping between screens.

**Non-Goals:**
- Completely rewriting the flight simulation data pipeline.
- Creating a separate screen editor outside of the app.

## Decisions

1.  **Widget Configuration Storage**:
    - *Decision*: Add a `style` or `settings` attribute (e.g., `String styleName`) to `WidgetPlacementModel` to hold the enum value string for its style (since styles are currently enums like `NumericWidgetStyle`). We can add a generic `Map<String, String> config` for flexibility.
    - *Alternative*: Keep global settings. *Rejected*: Doesn't meet user requirement of individual customization.

2.  **Grid Layout Implementation**:
    - *Decision*: Build a custom `GestureDetector`-based grid for `_buildSnapToGrid` (or modify `_buildFreeformHud` to act as a grid). We can use `PanUpdate` events to calculate the delta and update `x, y` of the widget, snapping to a virtual grid (e.g., screen width / 4 columns). For resizing, we'll add a small drag handle in the bottom right corner of the widget in edit mode.
    - *Alternative*: Use a third-party grid package. *Rejected*: A simple custom implementation avoids dependency bloat for a basic grid.

3.  **Screen Navigation**:
    - *Decision*: Wrap the main view (where `LayoutStrategyContainer` is) in a `PageView`. The `PageView` will iterate over `config.screens`. We will filter out the `thermaling` screen (or screens with a specific flag) from the manual swipe list.
    - *Alternative*: Use buttons to switch screens. *Rejected*: Swipe is more intuitive on mobile.

## Risks / Trade-offs

- **Risk: Gesture Conflicts**: Swiping to change screens might conflict with dragging widgets in edit mode.
  - **Mitigation**: Disable the `PageView`'s swiping capability (`NeverScrollableScrollPhysics()`) when `isEditMode` is true.

- **Risk: Settings Migration**: Existing configurations might break if `WidgetPlacementModel` requires new fields.
  - **Mitigation**: Ensure `fromJson` has sensible defaults for new fields so older saved states don't crash the app.
