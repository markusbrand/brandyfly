## 1. Dependencies and Model Updates

- [x] 1.1 Add `flutter_map` and `latlong2` dependencies to `apps/mobile/pubspec.yaml`
- [x] 1.2 Add `mapZoomLevel` field, getters, `copyWith`, and JSON serialization to `WidgetPlacementModel` in `ui_config.dart`
- [x] 1.3 Add and update unit tests in `apps/mobile/test/models/ui_config_test.dart` and `services/ui_persistence_service_test.dart`

## 2. Offline Tile Caching Layer

- [x] 2.1 Implement disk-backed tile caching provider with custom `User-Agent` (`BrandyFly/0.1.0`)
- [x] 2.2 Handle offline cache hits, misses, and graceful network timeouts without exceptions
- [x] 2.3 Add unit tests verifying tile cache persistence and offline fallback

## 3. MapWidget OpenStreetMap Integration

- [x] 3.1 Refactor `MapWidget` in `apps/mobile/lib/widgets/flight/map_widget.dart` to use `FlutterMap` and `MapController`
- [x] 3.2 Implement `TileLayer` supporting OpenStreetMap Standard, OpenTopoMap, Dark Vector HUD, and Relief styles
- [x] 3.3 Implement `PolylineLayer` for flight trail and `PolygonLayer` for airspace zones
- [x] 3.4 Implement `MarkerLayer` for pilot position marker with heading rotation and thermal hotspots
- [x] 3.5 Implement in-flight zoom in/out action buttons, center-pilot toggle, compass rose, and dynamic scale bar

## 4. Widget Configuration Dialog & UI Settings

- [x] 4.1 Update `_showConfigDialog` in `layout_strategy_container.dart` with Zoom Level slider, stepper (+/-), and presets (Overview, XC, Thermal, LZ)
- [x] 4.2 Update `UISettingsPanel` and `WidgetPickerSheet` with OpenStreetMap style selectors
- [x] 4.3 Add widget tests verifying zoom level configuration, persistence, and UI responsiveness

## 5. Verification & Test Suite

- [x] 5.1 Run full Flutter test suite (`flutter test`) to ensure regression-free execution
- [x] 5.2 Run `dart analyze` to verify clean static analysis
- [x] 5.3 Verify interactive map zooming and OpenStreetMap rendering in Linux mock flight mode
