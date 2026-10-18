# Tasks

## 1. Domain Models and Telemetry Pipeline

- [x] 1.1 Extend `CockpitTelemetry` with flight timing (`takeoffTime`, `flightDuration`) and RTL navigation fields (`takeoffLocation`, `takeoffAltitude`, `rtlDistanceMeters`, `rtlBearingDegrees`, `rtlRequiredGlide`, `rtlAltitudeMarginMeters`) and verify with unit tests in `test/domain/models/cockpit_telemetry_test.dart`.
- [x] 1.2 Implement geodesic distance, bearing, and return glide calculation logic in `TelemetryRepository` bridging `FlightTrackingService` takeoff state and `FlightReplayService` playback, and verify with unit tests in `test/data/repositories/telemetry_repository_test.dart`.

## 2. Widget Catalog and Layout Editor Integration

- [x] 2.1 Register `WidgetType.flightTime` and `WidgetType.returnGlide` in `widget_type.dart`, `widget_catalog.dart` (defining presets and minimum size constraints), and `layout_migrator.dart`, and verify with unit tests in `test/domain/models/widget_catalog_test.dart`.
- [x] 2.2 Add `flightTime` and `returnGlide` entries to `WidgetPickerSheet` and inspector panel configuration, and verify with `test/ui/features/layout_editor/widget_picker_sheet_test.dart`.

## 3. Flight Time Instrument Widget

- [x] 3.1 Implement `FlightTimeWidget` in `apps/mobile/lib/ui/features/instruments/views/flight_time_widget.dart` supporting regular, compact, and tiny size tiers, clock display, and pre-takeoff standby mode, and verify with widget tests in `test/ui/features/instruments/flight_time_widget_test.dart`.
- [x] 3.2 Wire `WidgetType.flightTime` in `WidgetSlot` (`FlightWidgetContent`) using granular `ValueSelector` subscriptions to avoid unnecessary UI rebuilds, and verify with slot tests in `test/ui/features/flight_canvas/widget_slot_test.dart`.

## 4. Return to Launch Instrument Widget

- [x] 4.1 Implement `ReturnGlideWidget` in `apps/mobile/lib/ui/features/instruments/views/return_glide_widget.dart` displaying required glide ratio, launch distance, altitude margin, and bearing indicator, with graceful `---` fallback when below takeoff elevation, and verify with widget tests in `test/ui/features/instruments/return_glide_widget_test.dart`.
- [x] 4.2 Wire `WidgetType.returnGlide` in `WidgetSlot` (`FlightWidgetContent`) using granular `ValueSelector` subscriptions, and verify with slot tests in `test/ui/features/flight_canvas/widget_slot_test.dart`.

## 5. Integration and End-to-End Replay Verification

- [x] 5.1 Create an integration test verifying that both `flightTime` and `returnGlide` widgets render accurately during active IGC flight replay without layout overflow or memory leaks (`flutter test test/widgets/flight_time_and_rtl_integration_test.dart`).
- [x] 5.2 Validate all OpenSpec schemas and specifications strictly across the repository (`npx openspec validate --all --strict`).
