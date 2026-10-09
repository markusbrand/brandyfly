import 'package:brandyfly/domain/map_motion/motion_smoother.dart';
import 'package:brandyfly/domain/models/cockpit_telemetry.dart';
import 'package:brandyfly/domain/models/ui_config.dart';
import 'package:brandyfly/domain/thermal/thermal_layer_spec.dart';
import 'package:brandyfly/models/lat_lng.dart';
import 'package:brandyfly/services/maplibre_map_service.dart';
import 'package:brandyfly/ui/features/map/layers/map_flight_layers.dart';
import 'package:brandyfly/ui/features/map/view_models/map_motion_controller.dart';
import 'package:brandyfly/ui/features/map/views/map_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre/maplibre.dart' hide Marker;

import '../../support/recording_style_controller.dart';

class _Move {
  _Move(this.position, this.zoom, this.bearing, this.padding);
  final LatLng position;
  final double? zoom;
  final double? bearing;
  final EdgeInsets padding;
}

class _RecordingMapService extends MapLibreMapService {
  final List<_Move> moves = [];
  int animateCalls = 0;

  @override
  Future<String> buildStyleJson({
    String? regionId,
    String? baseTemplateJson,
    ThermalLayerSpec? thermal,
  }) async => '{"version": 8, "sources": {}, "layers": []}';

  @override
  Future<void> moveCamera({
    required LatLng position,
    double? zoom,
    double? bearing,
    double? pitch,
    EdgeInsets padding = EdgeInsets.zero,
  }) async => moves.add(_Move(position, zoom, bearing, padding));

  @override
  Future<void> animateCamera({
    required LatLng position,
    double? zoom,
    double? bearing,
    double? pitch,
    Duration nativeDuration = const Duration(seconds: 1),
  }) async => animateCalls++;
}

const _base = LatLng(47.5, 13.6);
const _mPerDegLat = 111320.0;

CockpitTelemetry _fix(
  double northM, {
  double heading = 0,
  double speed = 36,
  bool stale = false,
}) => CockpitTelemetry(
  latitude: _base.latitude + northM / _mPerDegLat,
  longitude: _base.longitude,
  heading: heading,
  speed: speed,
  isStale: stale,
  hasSource: true,
);

Future<(_RecordingMapService, ValueNotifier<CockpitTelemetry>)> _pumpMap(
  WidgetTester tester, {
  MapOrientation orientation = MapOrientation.northUp,
  CockpitTelemetry? initial,
  double height = 500,
}) async {
  final service = _RecordingMapService();
  addTearDown(service.dispose);
  final telemetry = ValueNotifier(initial ?? _fix(0));
  addTearDown(telemetry.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 400,
            height: height,
            child: MapWidget(
              mapService: service,
              orientation: orientation,
              telemetry: telemetry,
              showThermals: false,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (service, telemetry);
}

MapWidgetState _state(WidgetTester tester) =>
    tester.state<MapWidgetState>(find.byType(MapWidget));

void main() {
  group('MapMotionController', () {
    testWidgets('1 Hz fixes produce a frame on every vsync and stop at the '
        'horizon', (tester) async {
      final frames = <MotionFrame>[];
      final c = MapMotionController(vsync: tester, onFrame: frames.add);
      addTearDown(c.dispose);

      for (var k = 0; k < 4; k++) {
        c.pushFix(
          MotionFix(
            latitude: 47.5 + k * 10 / _mPerDegLat,
            longitude: 13.6,
            headingDeg: 0,
          ),
        );
        for (var f = 0; f < 60; f++) {
          await tester.pump(const Duration(milliseconds: 1000 ~/ 60));
        }
      }
      // The first fix has no velocity yet (one frame); afterwards ~60
      // frames per fix interval, each one moving the camera.
      expect(frames.length, greaterThan(170));
      var still = 0;
      for (var i = 61; i < frames.length; i++) {
        if (frames[i].cameraCenter == frames[i - 1].cameraCenter) still++;
      }
      expect(still, lessThan(3));

      // No more fixes: prediction ends after 2 s and the ticker stops.
      await tester.pump(const Duration(milliseconds: 2100));
      await tester.pump(const Duration(milliseconds: 20));
      expect(c.isTicking, isFalse);
      final count = frames.length;
      await tester.pump(const Duration(seconds: 1));
      expect(frames.length, count);
    });

    testWidgets('identical consecutive fixes are ignored', (tester) async {
      final frames = <MotionFrame>[];
      final c = MapMotionController(vsync: tester, onFrame: frames.add);
      addTearDown(c.dispose);
      const fix = MotionFix(latitude: 47.5, longitude: 13.6, headingDeg: 0);
      c.pushFix(fix);
      await tester.pump();
      expect(c.isTicking, isFalse);
      c.pushFix(fix);
      expect(c.isTicking, isFalse);
    });

    testWidgets('zoom and orientation changes are eased', (tester) async {
      final frames = <MotionFrame>[];
      final c = MapMotionController(
        vsync: tester,
        onFrame: frames.add,
        initialZoom: 13,
      );
      addTearDown(c.dispose);
      c.pushFix(
        const MotionFix(latitude: 47.5, longitude: 13.6, headingDeg: 90),
      );
      await tester.pump();
      expect(frames.last.bearing, 0);
      c.setZoom(14);
      c.setTrackUp(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final mid = frames.last;
      expect(mid.zoom, inExclusiveRange(13, 14));
      expect(mid.bearing, inExclusiveRange(0, 90));
      expect(
        mid.topPaddingFraction,
        inExclusiveRange(0, MapMotionController.trackUpTopPadding),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(frames.last.zoom, 14);
      expect(frames.last.bearing, closeTo(90, 1e-9));
      expect(
        frames.last.topPaddingFraction,
        MapMotionController.trackUpTopPadding,
      );
      expect(frames.last.markerRotationDeg, closeTo(0, 1e-9));
    });
  });

  group('MapWidget smoothed follow', () {
    testWidgets('camera moves continuously between 1 Hz telemetry fixes with '
        'one combined write per frame', (tester) async {
      final (service, telemetry) = await _pumpMap(tester);
      for (var k = 1; k <= 3; k++) {
        telemetry.value = _fix(10.0 * k);
        for (var f = 0; f < 30; f++) {
          await tester.pump(const Duration(milliseconds: 33));
        }
      }
      // ~30 frames per fix, each a single move carrying center, zoom,
      // bearing and padding.
      expect(service.moves.length, greaterThan(60));
      expect(
        service.moves.every((m) => m.zoom != null && m.bearing != null),
        isTrue,
      );
      final lats = service.moves.map((m) => m.position.latitude).toList();
      for (var i = 1; i < lats.length; i++) {
        expect(lats[i], greaterThanOrEqualTo(lats[i - 1] - 1e-9));
      }
      expect(service.animateCalls, 0);
    });

    testWidgets('track-up padding puts the pilot 60 % from the top; '
        'north-up is centered', (tester) async {
      final (service, _) = await _pumpMap(
        tester,
        orientation: MapOrientation.trackUp,
        height: 500,
      );
      expect(service.moves.last.padding.top, closeTo(100, 1e-6)); // 0.2 * 500
      final painter =
          tester
                  .widget<CustomPaint>(
                    find.byKey(const Key('map_pilot_marker')),
                  )
                  .painter!
              as PilotMarkerPainter;
      expect(painter.anchorFor(const Size(400, 500)).dy, closeTo(300, 1e-6));

      final (northService, _) = await _pumpMap(tester);
      expect(northService.moves.last.padding.top, 0);
      final northPainter =
          tester
                  .widget<CustomPaint>(
                    find.byKey(const Key('map_pilot_marker')),
                  )
                  .painter!
              as PilotMarkerPainter;
      expect(northPainter.anchorFor(const Size(400, 500)).dy, 250);
    });

    testWidgets('track-up bearing follows the filtered heading', (
      tester,
    ) async {
      final (service, telemetry) = await _pumpMap(
        tester,
        orientation: MapOrientation.trackUp,
        initial: _fix(0, heading: 0),
      );
      for (var k = 1; k <= 6; k++) {
        telemetry.value = _fix(0, heading: 18.0 * k);
        for (var f = 0; f < 30; f++) {
          await tester.pump(const Duration(milliseconds: 33));
        }
      }
      final bearings = service.moves.map((m) => m.bearing!).toList();
      var maxStep = 0.0;
      for (var i = 1; i < bearings.length; i++) {
        final d = MotionSmoother.shortestDelta(bearings[i - 1], bearings[i]);
        if (d.abs() > maxStep) maxStep = d.abs();
      }
      expect(maxStep, lessThan(5), reason: 'no 18 deg steps');
      expect(bearings.last, greaterThan(60));
    });

    testWidgets('stale telemetry freezes the camera', (tester) async {
      final (service, telemetry) = await _pumpMap(tester);
      telemetry.value = _fix(10);
      await tester.pump(const Duration(milliseconds: 500));
      telemetry.value = _fix(500, stale: true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      final frozen = service.moves.last.position;
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(
        service.moves.last.position.latitude,
        closeTo(frozen.latitude, 1e-9),
      );
    });

    testWidgets('panning hides the screen marker and shows the native pilot '
        'symbol; recenter reverses it', (tester) async {
      final (_, telemetry) = await _pumpMap(tester);
      final style = RecordingStyleController();
      tester.widget<MapLibreMap>(find.byType(MapLibreMap)).onStyleLoaded!(
        style,
      );
      await tester.pumpAndSettle();
      PilotMarkerPainter painter() =>
          tester
                  .widget<CustomPaint>(
                    find.byKey(const Key('map_pilot_marker')),
                  )
                  .painter!
              as PilotMarkerPainter;
      expect(painter().visible, isTrue);

      await tester.drag(
        find.byKey(const Key('map_gesture_detector')),
        const Offset(80, 40),
      );
      telemetry.value = _fix(20);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(painter().visible, isFalse);
      expect(
        style.sourceData[MapFlightLayers.pilotSourceId],
        contains('Point'),
      );

      await tester.tap(find.byKey(const Key('btn_map_recenter')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(painter().visible, isTrue);
      expect(
        style.sourceData[MapFlightLayers.pilotSourceId],
        isNot(contains('Point')),
      );
      await tester.pumpAndSettle();
    });

    testWidgets('style load attaches native track layers and thermal swaps go '
        'below them', (tester) async {
      final (service, _) = await _pumpMap(tester);
      final style = RecordingStyleController();
      tester.widget<MapLibreMap>(find.byType(MapLibreMap)).onStyleLoaded!(
        style,
      );
      await tester.pumpAndSettle();
      expect(_state(tester).flightLayers.isAttached, isTrue);
      expect(style.layerIds, contains(MapFlightLayers.windowSourceId));
      expect(service.overlayBottomLayerId, MapFlightLayers.bottomLayerId);
    });

    testWidgets('without a native renderer the HUD and marker still render', (
      tester,
    ) async {
      final (service, telemetry) = await _pumpMap(tester);
      // Headless: no controller, no style - layers stay detached.
      expect(service.controller, isNull);
      expect(_state(tester).flightLayers.isAttached, isFalse);
      telemetry.value = _fix(10).copyWith(altitude: 1777);
      await tester.pump();
      expect(find.textContaining('ALT: 1777m'), findsOneWidget);
      expect(find.byKey(const Key('map_pilot_marker')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
    });
  });
}
