# Tasks

## 1. GeoJSON Serialization

- [x] 1.1 In `TrackGeoJson`, add a method `airspaceCollection` that serializes a `List<AirspaceModel>` into a GeoJSON `FeatureCollection` of Polygons, including `color` and `label` properties. Verify by writing a unit test that outputs valid GeoJSON for a mock airspace list.
- [x] 1.2 In `TrackGeoJson.airspaceCollection`, implement dynamic property injection for the active proximity alert: if an airspace name matches `highlightedName` or `activeAlertLevel` $\ge 2$, override its `color` property to red. Verify by unit test.

## 2. MapLibre Native Layer Setup

- [x] 2.1 In `MapFlightLayers`, remove `defaultMockAirspacePolygon` and update the `attach` method to add the `bf-airspace-symbol` layer (using `['get', 'label']` for `text-field`) alongside the fill and line layers. Verify by instantiating `MapFlightLayers` in a unit test and checking layer creation without errors.
- [x] 2.2 In `MapFlightLayers`, update the fill and line layers to use data-driven paint properties (e.g. `['get', 'color']` instead of hardcoded `#ef4444`). Verify layer style definitions in a widget/unit test.
- [x] 2.3 Add a new method `updateAirspaces(List<AirspaceModel> airspaces, String? highlightedName)` in `MapFlightLayers` that calls `updateGeoJsonSource(airspaceSourceId)` with the new GeoJSON string. Verify by mocking the style controller and ensuring `updateGeoJsonSource` is called with correctly serialized data.

## 3. UI and Service Integration

- [x] 3.1 In `MapWidget`, consume `AirspaceService` updates (either via Provider/ListenableBuilder or directly if already injected) to capture `loadedAirspaces` and `latestProximity`. Verify by writing a widget test that checks `MapWidget` rebuilds when `AirspaceService` notifies.
- [x] 3.2 In `MapWidget`, pass the current airspaces and active alert name to `MapFlightLayers.updateAirspaces` whenever they change. Verify by tracking calls to `updateAirspaces` in the map test mock.
- [x] 3.3 Completely delete `AirspaceMapLayer` and `AirspaceMapPainter` from `apps/mobile/lib/widgets/flight/airspace_map_layer.dart` and remove its usage from `MapWidget`'s `Stack`. Verify by running `flutter analyze` and ensuring the UI compiles cleanly.

## 4. End-to-End Verification

- [x] 4.1 Run the full mobile widget and unit test suite (`flutter test`) and verify all tests pass.
- [x] 4.2 Run the local emulator map preview to visually confirm airspace polygons and labels render natively and do not swim during camera follow/pan.
