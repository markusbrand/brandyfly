## 1. Data Model Updates

- [ ] 1.1 Update `WidgetPlacementModel` to include a `style` field (or generic `config` map) to store widget-specific settings. Ensure `fromJson` handles older configurations gracefully.
- [ ] 1.2 Update `ScreenManagerService` to support updating a single widget's properties.
- [ ] 1.3 Create a settings dialog overlay for individual widgets in edit mode (accessible by tapping the widget).

## 2. Grid Interaction Implementation

- [ ] 2.1 Update `LayoutStrategyContainer`'s `_buildSnapToGrid` (or freeform) to use a `Stack` where widgets are wrapped in a `Positioned`.
- [ ] 2.2 Add `GestureDetector` to `_buildWidgetWrapper` (when in edit mode) to support `onPanUpdate` and `onPanEnd` for dragging widgets to update their `x, y` positions. Snap logic to columns/rows.
- [ ] 2.3 Add a resize handle to the bottom right of widgets in edit mode. Handle pan events to update `w, h` dimensions.

## 3. Screen Navigation Implementation

- [ ] 3.1 Replace the single screen view in `_LiveFlightView` and `_MockFlightView` with a `PageView.builder`.
- [ ] 3.2 Configure the `PageView` to iterate over screens in `ScreenManagerService.config.screens`, skipping screens not meant for manual swiping (e.g. `thermaling`).
- [ ] 3.3 Ensure `NeverScrollableScrollPhysics` is applied to the `PageView` when `ScreenManagerService.isEditMode` is true to prevent conflicts with widget dragging.

## 4. UI Refinement and Testing

- [ ] 4.1 Remove the global widget settings from `UISettingsPanel` that have been moved to individual widgets.
- [ ] 4.2 Verify drag-and-drop and resizing functionality in the Flutter app.
- [ ] 4.3 Verify screen swiping works correctly.
