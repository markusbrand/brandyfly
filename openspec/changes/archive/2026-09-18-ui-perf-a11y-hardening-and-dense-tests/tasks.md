## 1. UI Accessibility & Ergonomics Hardening

- [x] 1.1 Fix `RenderFlex` overflow in `LayoutStrategyContainer` compact widget headers and toolbars using `FittedBox` and adaptive title display, and verify with `flutter test test/widgets_test.dart`
- [x] 1.2 Fix status bar collision and safe-area positioning in `TopNavBarOverlay` grab handle and badges, ensuring >=48x48dp touch targets and semantic labels, and verify with widget test
- [x] 1.3 Polish `_SimulationControlOverlay` collapsed state presentation, boundary clamping, and pass-through hit testing, and verify with widget test
- [x] 1.4 Enhance high-contrast styling and semantic accessibility labels across telemetry instruments and settings, and verify with `flutter test`

## 2. Telemetry and Rendering Performance Optimization

- [x] 2.1 Add `RepaintBoundary` wrappers to high-frequency telemetry widgets (`VarioLiftSinkBar`, `AltitudeSparklineChart`, `NumericTextWidget`, `MiniTrackPainter`) to prevent full-screen canvas repaints, and verify with widget test
- [x] 2.2 Optimize `MapWidget` and `ThermalMapWidget` polyline rendering and marker transforms, avoiding redundant allocations on telemetry ticks, and verify with `flutter test test/map_widget_integration_test.dart`
- [x] 2.3 Streamline `FlightTrackingService` telemetry dispatching and history buffering for minimal latency, and verify with `flutter test test/flight_tracking_service_test.dart`

## 3. Architecture Refactoring & Code Cleanup

- [x] 3.1 Audit and prune unused helpers, dead code, and redundant imports across mobile app codebase, and verify clean analysis with `flutter analyze`

## 4. Dense Test-Driven Unit & Widget Test Suite

- [x] 4.1 Implement dense test suite in `test/layout_resilience_and_a11y_test.dart` covering 1x1 to 8x16 grid constraints and zero-overflow guarantees, and verify all tests pass
- [x] 4.2 Implement dense test suite in `test/telemetry_latency_and_perf_test.dart` verifying high-frequency streaming and RepaintBoundary isolation, and verify all tests pass
- [x] 4.3 Run full mobile test suite and verify 100% pass rate with `flutter test`
- [x] 4.4 Validate OpenSpec changes with `npx openspec validate --all --strict`
