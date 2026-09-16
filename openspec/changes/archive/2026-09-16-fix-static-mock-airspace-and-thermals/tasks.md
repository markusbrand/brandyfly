## 1. Mock Overlay Static Anchoring

- [x] 1.1 Define static geographic boundary coordinates for mock airspace restriction polygon in `map_widget.dart` and verify the polygon renders at fixed Earth coordinates
- [x] 1.2 Define static geographic coordinates for mock thermal hotspots in `map_widget.dart` and verify hotspots remain stationary on the terrain
- [x] 1.3 Add automated unit and widget tests in `map_widget_integration_test.dart` verifying that moving `pilotPosition` does not alter airspace polygon or thermal screen coordinates when camera center remains fixed

## 2. Validation & Live Verification

- [x] 2.1 Run `flutter test` on map widget test suites to ensure zero regressions
- [x] 2.2 Verify on running Android emulator that flying through the mock session leaves the red airspace polygon and thermal markers stationary on the terrain
