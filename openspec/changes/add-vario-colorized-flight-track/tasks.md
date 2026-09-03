## 1. UI Configuration Model & Persistence

- [ ] 1.1 Add `mapTrackHistoryMinutes` and `mapTrackShowOlderTail` properties to `WidgetPlacementModel` in `ui_config.dart`.
- [ ] 1.2 Update `copyWith`, `toJson`, `fromJson`, and default values for `WidgetPlacementModel`.
- [ ] 1.3 Update `UIConfig.defaultConfig()` to configure default 10-minute track history.
- [ ] 1.4 Add unit tests in `test/models/ui_config_test.dart` for serialization of map track settings.

## 2. Telemetry Pipeline & Data Mapping

- [ ] 2.1 Update `layout_strategy_container.dart` to pass `activeFlightPoints` from `FlightTrackingService` into `MapWidget`.
- [ ] 2.2 Ensure `FlightReplayService` emits full `FlightPoint` telemetry including vario and timestamps to instrument map views.
- [ ] 2.3 Update mock flight generator in local mock flight mode to produce continuous vario variation along simulated track coordinates.

## 3. MapWidget Segmented Gradient Track Renderer

- [ ] 3.1 Implement continuous piecewise color gradient calculation (`getVarioTrackColor`) with configured color stops.
- [ ] 3.2 Implement track segmentation and time-window filtering logic in `MapWidget` (`_buildGradientPolylines`).
- [ ] 3.3 Implement batching/merging for consecutive track points sharing similar gradient values to optimize `PolylineLayer` performance.
- [ ] 3.4 Implement muted/faint baseline rendering for historical track points older than the configured history window.
- [ ] 3.5 Ensure high-contrast dark border stroke around all colored track segments for visibility over topo and satellite tiles.

## 4. UI Settings & Inspector Controls

- [ ] 4.1 Add track history duration (slider/options: 2m, 5m, 10m, 15m, 30m, All) to `MapWidget` settings inspector in `layout_strategy_container.dart`.
- [ ] 4.2 Add track history and older tail toggle controls to `UISettingsPanel`.

## 5. Verification & Tests

- [ ] 5.1 Add unit tests for `getVarioTrackColor` and segment batching algorithm covering lift, neutral glide, sink, and edge values.
- [ ] 5.2 Add widget tests in `test/map_widget_integration_test.dart` verifying colored polyline generation and time window filtering.
- [ ] 5.3 Run static analysis (`dart analyze`) and automated test suite (`flutter test`).
