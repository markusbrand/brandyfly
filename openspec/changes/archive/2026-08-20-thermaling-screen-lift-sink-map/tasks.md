## 1. UI Model & Configuration Extensions

- [x] 1.1 Add `WidgetType.thermalMap` and `ThermalMapStyle` enum (`xctrackBubbles`, `burnairCore`, `navigatorRibbon`) in `ui_config.dart`.
- [x] 1.2 Extend `WidgetPlacementModel` with `thermalMapStyle`, `thermalMapShowCore`, and `thermalMapHistorySeconds` properties, updating `copyWith`, `toJson`, and `fromJson`.
- [x] 1.3 Update `UIConfig.defaultConfig()` to include the full-screen `thermalMap` widget in the default `thermaling` screen layout behind the instrument overlays.
- [x] 1.4 Add unit tests in `test/models/ui_config_test.dart` for serialization and default configuration.

## 2. Layout Strategy & Widget Layer Ordering

- [x] 2.1 Update `_getOrderedWidgets` in `layout_strategy_container.dart` to enforce 3-tier layering: base map (0), thermal map (1), and instrument widgets (2).
- [x] 2.2 Add `WidgetType.thermalMap` rendering entry in `_renderWidgetContent`.
- [x] 2.3 Add `WidgetType.thermalMap` option to `widget_picker_sheet.dart` with descriptive icon and label.
- [x] 2.4 Add thermal map settings inspector controls in `layout_strategy_container.dart` (style selector, core marker toggle, history window).

## 3. Thermal Map Widget & Painter Implementation

- [x] 3.1 Create `lib/widgets/flight/thermal_map_widget.dart` with `StatefulWidget` supporting zoom, pan, and centering controls.
- [x] 3.2 Implement `ThermalMapPainter` to render lift (green) and sink (red) circular markers with dynamic opacity scaling and radius interpolation based on climb rate.
- [x] 3.3 Implement glider heading indicator, turn circle path line, and recenter/zoom overlay buttons.
- [x] 3.4 Implement visual presets for XCtrack bubbles, Burnair core assist with centroid calculation, and Navigator ribbon.

## 4. Telemetry Integration & Mock Flight Mode

- [x] 4.1 Update telemetry data pipeline in `layout_strategy_container.dart` and `screen_manager_service.dart` to supply thermal circling track points and climb history.
- [x] 4.2 Add mock circling flight path generator with dynamic thermal lift/sink variation in mock flight mode.

## 5. Verification & Tests

- [x] 5.1 Add widget tests in `test/widgets_test.dart` verifying thermal map rendering, lift/sink circle colors, and opacity calculations.
- [x] 5.2 Add integration tests verifying widget layering and layout editing operations with thermal map.
- [x] 5.3 Run static analysis (`dart analyze`) and automated test suite (`flutter test`).
