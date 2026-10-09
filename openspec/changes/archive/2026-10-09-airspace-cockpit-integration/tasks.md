## 1. Widget Catalog & Slot Registration

- [x] 1.1 Add `airspaceSideCut` to `WidgetType` enum and `widgetCatalog` in `apps/mobile/lib/domain/models/widget_catalog.dart` with minimum bounds (8x4) and default presets
- [x] 1.2 Wire `WidgetType.airspaceSideCut` into `apps/mobile/lib/ui/features/flight_canvas/views/widget_slot.dart` to instantiate `AirspaceSideCutWidget`
- [x] 1.3 Add unit test in `apps/mobile/test/domain/widget_catalog_test.dart` verifying `airspaceSideCut` sizing specifications and clamping

## 2. Service Lifecycle & Runtime Telemetry Coupling

- [x] 2.1 Instantiate `AirspaceService` in `apps/mobile/lib/main.dart` and provide it via `ChangeNotifierProvider<AirspaceService>`
- [x] 2.2 Wire automatic DACH fixture loading in `main.dart` when running in mock flight mode (`BRANDYFLY_LOCAL_MOCK_FLIGHT_MODE=true`)
- [x] 2.3 Subscribe to `FlightTrackingService` telemetry stream and `ElevationService` in `main.dart` to trigger periodic proximity evaluations (1 Hz)
- [x] 2.4 Verify telemetry feed and proximity evaluation with unit test in `apps/mobile/test/services/airspace_service_test.dart`

## 3. Cockpit Warning Banner HUD & Audio Alerts

- [x] 3.1 Mount `AirspaceWarningBannerHud` in `apps/mobile/lib/ui/features/flight_canvas/views/layout_canvas.dart` above widget slots
- [x] 3.2 Add `playAirspaceAlert` method in `AudioVarioService` to emit audible warning tones on level escalation
- [x] 3.3 Connect `AirspaceService` alert transitions to `AudioVarioService.playAirspaceAlert`
- [x] 3.4 Add widget test in `apps/mobile/test/widgets/airspace_widgets_test.dart` verifying warning banner appearance and dismissal on proximity transitions

## 4. Map Layer Integration

- [x] 4.1 Mount `AirspaceMapLayer` into `MapWidget` stack to render nearby airspace boundaries over the vector map
- [x] 4.2 Add widget test verifying `AirspaceMapLayer` visibility toggle in `apps/mobile/test/widgets/airspace_widgets_test.dart`

## 5. Verification & OpenSpec Strict Validation

- [x] 5.1 Run all mobile tests: `flutter test`
- [x] 5.2 Validate OpenSpec delta and specs: `npx openspec validate --all --strict`
- [x] 5.3 Verify in the Android emulator that mock flight mode loads DACH airspaces and renders the side-cut profile
