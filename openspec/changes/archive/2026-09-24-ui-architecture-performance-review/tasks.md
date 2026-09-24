## 1. Layout Container Decomposition

- [x] 1.1 Extract `_WidgetEditFrame` and `_WidgetEditFrameState` from `layout_strategy_container.dart` into new file `widgets/layout/widget_edit_frame.dart`. Make the class public as `WidgetEditFrame`. Update imports in `layout_strategy_container.dart`. Verify: `flutter analyze` passes with no errors.
- [x] 1.2 Extract the `_showConfigDialog` static method and its helpers (`_buildSectionTitle`, `_styleChip`, `_durationChip`) into new file `widgets/layout/widget_config_dialog.dart` as a top-level `showWidgetConfigDialog()` function. Update call sites in `widget_edit_frame.dart` and `layout_strategy_container.dart`. Verify: `flutter analyze` passes.
- [x] 1.3 Extract `_buildInspectorPanel` and its helpers (`_inspectorButton`, `_inspectorTextButton`) from `layout_strategy_container.dart` into new file `widgets/layout/widget_inspector_panel.dart` as `WidgetInspectorPanel`. Update the import and call site in `layout_strategy_container.dart`. Verify: `flutter analyze` passes.
- [x] 1.4 Verify the decomposed layout container builds and renders correctly by running `flutter run -d android --dart-define=BRANDYFLY_LOCAL_MOCK_FLIGHT_MODE=true` and confirming: layout strategies render, edit mode opens, inspector panel displays on widget selection, and config dialog opens from inspector.

## 2. Scoped Widget Rebuilds

- [x] 2.1 In `_BrandyFlyAppState.build()`, move the `AnimatedBuilder(animation: _screenManager, ...)` from wrapping `MaterialApp` to wrapping the `home:` page content. `MaterialApp` with its theme, title, and debug banner SHALL be constructed once. Verify: `flutter analyze` passes and the app still renders correctly with theme intact.
- [ ] 2.2 Verify that toggling the nav bar, settings panel, flights screen, and edit mode does not reconstruct the `MaterialApp` widget. Observable: add a temporary `print('MaterialApp built')` inside the MaterialApp builder to confirm it fires only once on startup.

## 3. Simulation Overlay Hit-Test Fix

- [x] 3.1 In `_BrandyFlyAppState.build()`, replace the `Positioned.fill(child: _SimulationControlOverlay(...))` with `Positioned(left:, top:, right:, child: ...)` using the overlay's computed position. Remove `Positioned.fill` so the overlay card no longer intercepts touches across the entire screen. Verify: tapping on the map widget beneath the overlay registers map interaction (e.g., zoom buttons respond).
- [ ] 3.2 Ensure the simulation overlay card remains draggable and repositionable after the fix. Verify: drag the overlay card to different screen positions and confirm it snaps correctly within safe area bounds.

## 4. Garbage-Free Hot Paths

- [x] 4.1 In `SyntheticTelemetrySource._generateSnapshot()`, replace all `double.parse(value.toStringAsFixed(N))` calls with mathematical rounding: `(value * factor).roundToDouble() / factor` where factor = 10^N. Verify: `flutter analyze` passes; run app in simulation mode and confirm telemetry values display correctly.
- [x] 4.2 In `FlightReplayService`, add a `List<LatLng> _trackCache` field and a `List<FlightPoint> _flightPointsCache` field. On `loadFlight()`, initialize both caches from the first point. On `advance()`, append the current point to both caches. On `seekTo()` and `seekToRatio()`, rebuild caches by slicing up to the target index. Update `currentTelemetry` getter to return cached lists instead of re-slicing. Verify: replay playback renders the track polyline correctly and seeking resets the track to the correct position.
- [x] 4.3 In `_renderWidgetContent()` in `layout_strategy_container.dart`, cache the parsed `history` list as a field on the container or pass it pre-parsed from the parent. Avoid re-mapping `rawHistory as List<dynamic>` to `List<double>` on every telemetry tick. Verify: `flutter analyze` passes.

## 5. Zero-Dimension Safety Guards

- [x] 5.1 In `AltitudeSparklineChart`'s `_SparklinePainter.paint()`, add `if (size.width <= 0 || size.height <= 0) return;` at the start of the method, before the grid-drawing loops. Verify: rendering a sparkline with zero-size constraints does not freeze the UI thread. Add a unit test that creates a `_SparklinePainter` and calls `paint()` with `Size.zero` canvas — it SHALL return without error.
- [x] 5.2 In `LayoutStrategyContainer._buildLayout()`, guard against `constraints.maxHeight == double.infinity` by using a fallback: `final effectiveMaxHeight = constraints.maxHeight.isFinite ? constraints.maxHeight : 600.0;`. Use `effectiveMaxHeight` for cell height computation. Verify: `flutter analyze` passes.
- [x] 5.3 In `MiniTrackPainter.paint()`, add a guard `if (size.width < 40 || size.height < 40) return;` to prevent negative canvas coordinate math. Verify: rendering with tiny canvas does not produce visual artifacts.

## 6. Const Constructors and RepaintBoundary

- [x] 6.1 Add `RepaintBoundary` wrappers to any remaining `CustomPaint` widgets in flight instrument widgets that lack them (check `VarioLiftSinkBar`, `WindDirectionWidget`, `AltitudeSparklineChart`). Note: `_renderWidgetContent` already wraps each widget in `RepaintBoundary`; verify this covers all paths and add any missing ones. Verify: `flutter analyze` passes.
- [x] 6.2 Audit `_ModeChip`, `_LoadingView`, `_StartupErrorView` in `main.dart` and ensure they use `const` constructors where possible. Convert `TextStyle`, `EdgeInsets`, `BoxDecoration` instances to `const` where values are compile-time constants. Verify: `flutter analyze` passes.
- [x] 6.3 In `_SimulationControlOverlay`, convert repeated `TextStyle` instances with identical values to `static const` class-level fields. Verify: `flutter analyze` passes.

## 7. Additional Bug Fixes

- [x] 7.1 In `ReplayControlOverlay`, guard the `Slider` value against NaN by clamping: `final safeProgress = progress.isNaN ? 0.0 : progress.clamp(0.0, 1.0);`. Use `safeProgress` as the slider value. Verify: loading a flight with zero duration does not crash the slider.
- [x] 7.2 In `FlightsScreen`, add `key: ValueKey(flight.id)` to each flight card in `ListView.builder` to prevent element reuse bugs during filtering and deletion. Verify: `flutter analyze` passes.
- [x] 7.3 In `_SparklinePainter.shouldRepaint()`, compare list contents using `listEquals` from `package:flutter/foundation.dart` instead of reference equality (`!=`). Verify: in-place list mutations trigger repaints.

## 8. Validation

- [ ] 8.1 Run `flutter analyze` across the entire `apps/mobile` directory and confirm zero errors and zero warnings. Verify: command output shows "No issues found!".
- [ ] 8.2 Run the existing test suite (`flutter test` in `apps/mobile`) and confirm all tests pass. Verify: all tests pass with zero failures.
- [ ] 8.3 Run `npx openspec validate --all --strict` from the project root and confirm all changes and specs pass validation. Verify: validation output shows no errors.
