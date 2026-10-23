# Tasks

## 1. Single Telemetry Emission per Sensor Tick

- [x] 1.1 Update `FlightTrackingService._handleFlyingPoint` (`apps/mobile/lib/services/flight_tracking_service.dart`) so `notifyListeners()` is only invoked during `FlightState.flying` when the whole-second elapsed recording duration changes (or when landing finalizes the flight), avoiding redundant sub-second `ChangeNotifier` broadcasts on 10–50 Hz feeds, and verify with `flutter test test/flight_tracking_service_test.dart test/widgets/flight/recording_status_overlay_test.dart`.
- [x] 1.2 Update `TelemetryRepository` (`apps/mobile/lib/data/repositories/telemetry_repository.dart`) to track the last observed `FlightState` and `takeoffPoint` from `FlightTrackingService` so `_onTrackingChanged()` only re-emits when `FlightState` or `takeoffPoint` transitions outside an active `onSnapshot` tick, and add a unit test in `apps/mobile/test/data/repositories/telemetry_repository_test.dart` verifying that attaching both `FlightTrackingService` and `TelemetryRepository` to the same `ITelemetrySource` during `FlightState.flying` produces exactly 1 notification per sensor tick.

## 2. Live Rolling Glide Ratio (`L/D`) Calculation

- [x] 2.1 Implement `GlideAverager` in `apps/mobile/lib/domain/thermal_assistant/glide_averager.dart` with a 15-second rolling window, 5-second gap reset, descending sink threshold (`< -0.05 m/s` and speed `>= 5.0 km/h`), `[0.5, 50.0]` clamping, and last-valid/fallback retention when climbing, and verify with unit tests in `apps/mobile/test/domain/thermal_assistant/glide_averager_test.dart`.
- [x] 2.2 Integrate `GlideAverager` into `TelemetryRepository.onSnapshot` and `detachSource` (`apps/mobile/lib/data/repositories/telemetry_repository.dart`) so live telemetry populates `CockpitTelemetry.glide` with the smoothed rolling glide ratio, and verify with unit tests in `apps/mobile/test/data/repositories/telemetry_repository_test.dart`.

## 3. `AirspaceSideCutWidget` Rebuild Scoping, `RepaintBoundary`, and Spatial Query Caching

- [x] 3.1 Add spatial/state-delta caching to `AirspaceService.getForwardAirspaces` (`apps/mobile/lib/services/airspace_service.dart`) that returns the cached `List<ForwardAirspaceBlock>` when position moves `< 25 m`, heading changes `< 2°`, altitude changes `< 10 m`, glide ratio changes `< 0.5`, and loaded airspaces have not changed (invalidating cache on `loadOpenAirText`, `loadDachFixture`, and `clearAirspaces`), and verify with unit tests in `apps/mobile/test/services/airspace_service_test.dart`.
- [x] 3.2 Wrap `WidgetType.airspaceSideCut` in `FlightWidgetContent` (`apps/mobile/lib/ui/features/flight_canvas/views/widget_slot.dart`) with a `ValueSelector` selecting quantized position, altitude, speed, heading, glide ratio, and HAG, and wrap `AirspaceSideCutWidget`'s `CustomPaint` (`apps/mobile/lib/widgets/flight/airspace_side_cut_widget.dart`) in a `RepaintBoundary` with reusable `Paint` / `TextPainter` fields on `AirspaceSideCutPainter`, verifying with `flutter test test/widgets/airspace_widgets_test.dart test/perf/rebuild_budget_test.dart`.

## 4. Blur-Free High-Contrast Cockpit Overlays

- [x] 4.1 Remove `BackdropFilter` (`ImageFilter.blur`) from `ReplayControlOverlay` (`apps/mobile/lib/widgets/flight/replay_control_overlay.dart`) and `TopNavBarOverlay._buildTranslucentDrawer` (`apps/mobile/lib/widgets/navigation/top_nav_bar.dart`), replacing with high-opacity dark cockpit bezel surfaces, and verify with widget tests asserting zero `BackdropFilter` widgets in both overlays.

## 5. End-to-End Validation

- [x] 5.1 Run `flutter analyze` and the full performance/telemetry/widget test suite in `apps/mobile` (`flutter test test/telemetry_latency_and_perf_test.dart test/perf/rebuild_budget_test.dart test/data/repositories/telemetry_repository_test.dart test/services/airspace_service_test.dart test/widgets/airspace_widgets_test.dart`), plus `npx openspec validate --all --strict`, verifying zero warnings or test failures.
