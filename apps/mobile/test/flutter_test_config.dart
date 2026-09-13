import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:maplibre_platform_interface/maplibre_platform_interface.dart';

class _HeadlessMapLibrePlatform extends MapLibrePlatform {
  @override
  MapLibreMapState createWidgetState() => _HeadlessMapLibreMapState();
}

class _HeadlessMapLibreMapState extends MapLibreMapState {
  @override
  Widget buildPlatformWidget(BuildContext context) => const SizedBox.expand();

  @override
  Offset toScreenLocation(Geographic lngLat) => Offset.zero;

  @override
  Geographic toLngLat(Offset screenLocation) =>
      const Geographic(lon: 0, lat: 0);

  @override
  List<Offset> toScreenLocations(List<Geographic> lngLats) =>
      lngLats.map((_) => Offset.zero).toList();

  @override
  List<Geographic> toLngLats(List<Offset> screenLocations) =>
      screenLocations.map((_) => const Geographic(lon: 0, lat: 0)).toList();

  @override
  Future<void> moveCamera({
    Geographic? center,
    double? zoom,
    double? bearing,
    double? pitch,
    EdgeInsets padding = EdgeInsets.zero,
  }) async {}

  @override
  Future<void> animateCamera({
    Geographic? center,
    double? zoom,
    double? bearing,
    double? pitch,
    Duration nativeDuration = const Duration(seconds: 2),
    double webSpeed = 1.2,
    Duration? webMaxDuration,
    EdgeInsets padding = EdgeInsets.zero,
  }) async {}

  @override
  Future<void> fitBounds({
    required LngLatBounds bounds,
    double? bearing,
    double? pitch,
    Duration nativeDuration = const Duration(seconds: 2),
    double webSpeed = 1.2,
    Duration? webMaxDuration,
    Offset offset = Offset.zero,
    double webMaxZoom = double.maxFinite,
    bool webLinear = false,
    EdgeInsets padding = EdgeInsets.zero,
  }) async {}

  @override
  MapCamera getCamera() => MapCamera(
        center: const Geographic(lon: 13.685, lat: 47.525),
        zoom: 13.5,
        bearing: 0.0,
        pitch: 0.0,
      );

  @override
  double getMetersPerPixelAtLatitude(double latitude) => 1.0;

  @override
  LngLatBounds getVisibleRegion() => LngLatBounds(
        longitudeWest: 13.0,
        latitudeSouth: 47.0,
        longitudeEast: 14.0,
        latitudeNorth: 48.0,
      );

  @override
  List<QueriedLayer> queryLayers(Offset screenLocation) => const [];

  @override
  List<RenderedFeature> featuresAtPoint(
    Offset point, {
    List<String>? layerIds,
  }) =>
      const [];

  @override
  List<RenderedFeature> featuresInRect(
    Rect rect, {
    List<String>? layerIds,
  }) =>
      const [];

  @override
  Future<void> enableLocation({
    Duration fastestInterval = const Duration(milliseconds: 750),
    Duration maxWaitTime = const Duration(seconds: 1),
    bool pulseFade = true,
    bool accuracyAnimation = true,
    bool compassAnimation = true,
    bool pulse = true,
    BearingRenderMode bearingRenderMode = BearingRenderMode.gps,
  }) async {}

  @override
  Future<void> trackLocation({
    bool trackLocation = true,
    BearingTrackMode trackBearing = BearingTrackMode.gps,
  }) async {}

  @override
  void setStyle(String style) {}

  @override
  StyleController? get style => null;
}

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  MapLibrePlatform.instance = _HeadlessMapLibrePlatform();
  await testMain();
}
