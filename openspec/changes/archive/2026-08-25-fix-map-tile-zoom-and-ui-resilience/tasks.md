## 1. Fix TileLayer Zoom Boundaries & Style Keying

- [x] 1.1 Update `MapWidget` in `apps/mobile/lib/widgets/flight/map_widget.dart` to configure `maxNativeZoom` and `minNativeZoom` while setting `maxZoom: 22.0` and `minZoom: 1.0`.
- [x] 1.2 Add explicit `ValueKey` to `TileLayer` incorporating `widget.style` and URL template to ensure clean recreation on style switches.
- [x] 1.3 Update zoom handling in `MapWidget` to allow fluid zooming up to 19.0+ without tile layer disappearance.

## 2. Telemetry Synchronization & UI Edge Case Hardening

- [x] 2.1 Refine `didUpdateWidget` in `MapWidget` to guard against resetting camera zoom on telemetry updates when the pilot is actively panning or zooming.
- [x] 2.2 Wire `showContours` setting properly to style/layer logic.

## 3. Autonomous Testing & Regression Validation

- [x] 3.1 Add integration test in `apps/mobile/test/map_widget_integration_test.dart` verifying tiles remain visible and scale smoothly at over-zoom levels (zoom 17.5, 18.0, 19.0).
- [x] 3.2 Add test validating dynamic style switching without stale tile state or visual glitches.
- [x] 3.3 Run full Flutter test suite across all mobile widgets and instruments to ensure zero regressions.
