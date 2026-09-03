## 1. Auto-Recenter Timer & Gesture Management

- [ ] 1.1 Add inactivity auto-recenter timer (6s) to `MapWidget` in `map_widget.dart`
- [ ] 1.2 Add inactivity auto-recenter timer (6s) to `ThermalMapWidget` in `thermal_map_widget.dart`
- [ ] 1.3 Ensure proper timer cancellation on manual recenter, new gestures, and widget disposal

## 2. Orientation & Forward Viewport Bias in MapWidget

- [ ] 2.1 Implement North-Up 50%/50% true centering with heading-rotated glider arrow
- [ ] 2.2 Implement Track-Up forward-looking bias (40% bottom / 60% top) with UP-facing glider arrow
- [ ] 2.3 Ensure camera position updates accurately follow incoming telemetry updates in both orientation modes

## 3. Thermal Map Widget Precision Centering

- [ ] 3.1 Verify and enforce 50%/50% true centering in `ThermalMapWidget` for all 3 thermal styles
- [ ] 3.2 Implement auto-recenter reset of `_panOffset` in `ThermalMapWidget`

## 4. Verification & Automated Tests

- [ ] 4.1 Update and add unit/widget tests in `apps/mobile/test/map_widget_integration_test.dart` for auto-recenter and orientation anchoring
- [ ] 4.2 Add widget tests for `ThermalMapWidget` pan and auto-recenter timer behavior
- [ ] 4.3 Run `flutter test` and `dart analyze` to ensure zero regressions
- [ ] 4.4 Verify live map centering behavior in Linux local mock flight mode
