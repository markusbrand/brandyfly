## 1. Data Models & Serialization

- [x] 1.1 Update `WidgetPlacementModel` with widget-specific configuration properties (numeric style, map style/orientation/layers, vario style/scale, wind style, sparkline style) and backward-compatible JSON serialization.
- [x] 1.2 Update `FlightScreenModel` to include `autoSwitchTrigger` and preserve screen-level `layoutStrategy`.
- [x] 1.3 Clean up `UIConfig` by removing redundant global widget styling fields while preserving defaults and screen lists.
- [x] 1.4 Write unit tests in `apps/mobile/test/models/ui_config_test.dart` verifying JSON serialization, deserialization, and fallback defaults.

## 2. Widget Rendering & Screen Manager Integration

- [x] 2.1 Update `LayoutStrategyContainer` to render widgets using their individual `WidgetPlacementModel` configuration rather than global `UIConfig` values.
- [x] 2.2 Update `LayoutStrategyContainer` to read the layout strategy directly from `activeScreen.layoutStrategy`.
- [x] 2.3 Update `ScreenManagerService` with methods to update individual widget configurations and screen properties.
- [x] 2.4 Add widget tests verifying that widgets on the same or different screens render with independent styles and configurations.

## 3. In-Place Edit Mode Configuration UI

- [x] 3.1 Upgrade `_showConfigDialog` in `_WidgetEditFrame` (`LayoutStrategyContainer`) into a full-featured widget configuration sheet with style selectors, layer toggles, and coordinate steppers.
- [x] 3.2 Add widget tests for the Edit Mode configuration modal to verify applying changes updates the widget live on screen.

## 4. Settings Panel Cleanup & End-to-End Validation

- [x] 4.1 Refactor `UISettingsPanel` to focus strictly on global flight computer settings, audio, screen management, XContest credentials, and nav bar preferences.
- [x] 4.2 Run full static analysis (`flutter analyze` / `dart analyze`) and test suite (`flutter test`) across the mobile workspace to confirm zero regressions.
