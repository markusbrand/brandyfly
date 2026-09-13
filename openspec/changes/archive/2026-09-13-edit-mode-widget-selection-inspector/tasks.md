## 1. ScreenManagerService Selection State

- [x] 1.1 Add `selectedWidgetId` getter, `selectWidget(String? id)` method, and auto-clearing logic in `toggleEditMode` in `apps/mobile/lib/services/screen_manager_service.dart`, verifying with new unit tests in `apps/mobile/test/screen_manager_test.dart`.
- [x] 1.2 Verify that removing a widget automatically resets `selectedWidgetId` if the removed widget was currently selected, verified by `flutter test test/screen_manager_test.dart`.

## 2. Edit Mode Canvas Tap Selection and Visual Highlighting

- [x] 2.1 Update `_WidgetEditFrame` in `apps/mobile/lib/widgets/layout/layout_strategy_container.dart` to support tapping anywhere on the frame/widget to trigger `screenManager.selectWidget(model.id)`.
- [x] 2.2 Enhance `_WidgetEditFrame` styling so the selected widget renders an active accent border (cyan glow / bright border) distinct from unselected widgets.
- [x] 2.3 Verify canvas selection interaction and visual highlight via widget tests in `apps/mobile/test/widgets_test.dart`.

## 3. Toolbar Widget Layer Selector

- [x] 3.1 Add a "Select Widget" layer dropdown/picker button in the Edit Mode overlay controls within `LayoutStrategyContainer`, listing all placed widgets on the screen with their type and grid bounds.
- [x] 3.2 Ensure selecting any widget (such as background Map or Thermal Map) from the layer selector sets `selectedWidgetId` and brings up its inspector, verified by widget tests in `apps/mobile/test/widgets_test.dart`.

## 4. Docked Widget Inspector Panel

- [x] 4.1 Implement `_WidgetInspectorPanel` docked above the Edit Mode bottom toolbar in `LayoutStrategyContainer`, displaying the selected widget's title, coordinates `[x,y]`, dimensions `[w,h]`, and quick actions (Configure, Move Left/Right/Up/Down, Width/Height +/- , Delete, and Deselect).
- [x] 4.2 Connect the Inspector Panel's "Configure" button directly to the existing widget tune dialog (`_showConfigDialog`), ensuring pilots can configure background map settings without touching the map canvas header.
- [x] 4.3 Verify the inspector panel opens upon selecting a map widget, correctly adjusts dimensions/position, launches the tune dialog, and dismisses on Deselect, verified by `flutter test test/widgets_test.dart`.

## 5. End-to-End Validation & OpenSpec Verification

- [x] 5.1 Run all mobile unit and widget tests (`flutter test`) to ensure zero regressions across existing screens, layouts, and services.
- [x] 5.2 Validate OpenSpec compliance using `npx openspec validate --all --strict --json`.
