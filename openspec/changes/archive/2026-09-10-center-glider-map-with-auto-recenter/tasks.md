## 1. Auto-Recenter Timer & Gesture Management

- [x] 1.1 Add inactivity auto-recenter timer (6s) to `MapWidget` in `map_widget.dart`
- [x] 1.2 Add inactivity auto-recenter timer (6s) to `ThermalMapWidget` in `thermal_map_widget.dart`
- [x] 1.3 Ensure proper timer cancellation on manual recenter, new gestures, and widget disposal

## 2. Orientation & Forward Viewport Bias in MapWidget

- [x] 2.1 Implement North-Up 50%/50% true centering with heading-rotated glider arrow
- [x] 2.2 Implement Track-Up forward-looking bias (40% bottom / 60% top) with UP-facing glider arrow
- [x] 2.3 Ensure camera position updates accurately follow incoming telemetry updates in both orientation modes

## 3. Thermal Map Widget Precision Centering

- [x] 3.1 Verify and enforce 50%/50% true centering in `ThermalMapWidget` for all 3 thermal styles
- [x] 3.2 Implement auto-recenter reset of `_panOffset` in `ThermalMapWidget`

## 4. Verification & Automated Tests

- [x] 4.1 Update and add unit/widget tests in `apps/mobile/test/map_widget_integration_test.dart` for auto-recenter and orientation anchoring
- [x] 4.2 Add widget tests for `ThermalMapWidget` pan and auto-recenter timer behavior
- [x] 4.3 Run `flutter test` and `dart analyze` to ensure zero regressions
- [x] 4.4 Verify live map centering behavior in Linux local mock flight mode
