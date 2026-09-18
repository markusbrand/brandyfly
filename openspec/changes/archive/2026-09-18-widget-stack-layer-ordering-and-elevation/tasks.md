## 1. Screen Manager Service Layer Controls

- [x] 1.1 Implement `bringToFront`, `bringForward`, `sendBackward`, and `sendToBack` reorder methods in `ScreenManagerService` and verify with unit tests in `test/screen_manager_test.dart`.
- [x] 1.2 Update `ScreenManagerService.addWidget` to insert map widgets (`map`, `thermalMap`) at index 0 and append other widgets to the end, verifying with unit tests in `test/screen_manager_test.dart`.

## 2. Layout Strategy Dynamic Stack Rendering

- [x] 2.1 Update `LayoutStrategyContainer._getOrderedWidgets` to use list-based z-ordering and temporarily elevate the active selected widget to the foreground in Edit Mode.
- [x] 2.2 Wire `_getOrderedWidgets` across all layout builders (`_buildFreeformHud`, `_buildSnapToGrid`, `_buildSidebarDashboard`) with `isEditMode` and `selectedWidgetId`, verifying rendering order.

## 3. Floating Inspector Bar Stack Reorder UI

- [x] 3.1 Add stack reorder button group (`Send to Back`, `Send Backward`, `Bring Forward`, `Bring to Front`) and `Layer X/Y` depth indicator to `_buildInspectorPanel` with proper boundary disabled states.
- [x] 3.2 Add widget tests in `test/widgets_test.dart` verifying that selecting a widget elevates it in the stack and inspector reorder buttons update its persistent stack order.

## 4. Verification & Validation

- [x] 4.1 Run Flutter unit and widget test suite (`flutter test test/widgets_test.dart test/screen_manager_test.dart`) and ensure all tests pass.
- [x] 4.2 Run `npx openspec validate --all --strict --json` to verify that all change artifacts and specs pass validation.
