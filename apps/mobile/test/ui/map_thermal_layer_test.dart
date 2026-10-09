import 'package:brandyfly/domain/thermal/kk7_provider.dart';
import 'package:brandyfly/domain/thermal/thermal_layer_spec.dart';
import 'package:brandyfly/domain/thermal/thermal_variant.dart';
import 'package:brandyfly/models/lat_lng.dart';
import 'package:brandyfly/services/maplibre_map_service.dart';
import 'package:brandyfly/ui/features/map/views/map_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeMapService extends MapLibreMapService {
  int buildStyleCalls = 0;
  ThermalLayerSpec? builtWith;
  final thermalUpdates = <ThermalLayerSpec?>[];
  int cameraMoves = 0;

  @override
  Future<String> buildStyleJson({
    String? regionId,
    String? baseTemplateJson,
    ThermalLayerSpec? thermal,
  }) async {
    buildStyleCalls++;
    builtWith = thermal;
    return '{"version": 8, "sources": {}, "layers": []}';
  }

  @override
  Future<void> setThermalLayer(ThermalLayerSpec? spec) async {
    thermalUpdates.add(spec);
  }

  @override
  Future<void> moveCamera({
    required LatLng position,
    double? zoom,
    double? bearing,
    double? pitch,
    EdgeInsets padding = EdgeInsets.zero,
  }) async => cameraMoves++;

  @override
  Future<void> animateCamera({
    required LatLng position,
    double? zoom,
    double? bearing,
    double? pitch,
    Duration nativeDuration = const Duration(seconds: 1),
  }) async => cameraMoves++;
}

// Krippenstein, 20 March 2026: sunrise ~05:08:47 UTC.
const _krippenstein = LatLng(47.525, 13.685);

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: SizedBox(width: 480, height: 480, child: child)),
);

void main() {
  testWidgets(
    'Scenario: morning to midday transition in flight swaps the layer within '
    '60 s without style reload or camera change',
    (tester) async {
      var now = DateTime.utc(2026, 3, 20, 11, 0); // sunrise + 5.85 h
      final service = _FakeMapService();
      await tester.pumpWidget(
        _host(
          MapWidget(
            mapService: service,
            pilotPosition: _krippenstein,
            headingDeg: 0,
            clock: () => now,
          ),
        ),
      );
      await tester.pump();
      expect(service.buildStyleCalls, 1);
      expect(service.builtWith!.variant.layerId, 'thermals_apr_04');
      final movesBefore = service.cameraMoves;

      now = DateTime.utc(2026, 3, 20, 11, 10); // sunrise + 6.02 h
      await tester.pump(const Duration(seconds: 30));
      expect(service.thermalUpdates, isEmpty); // timer not yet fired
      await tester.pump(const Duration(seconds: 31));

      expect(service.thermalUpdates, hasLength(1));
      expect(service.thermalUpdates.single!.variant.layerId, 'thermals_apr_07');
      expect(service.buildStyleCalls, 1);
      expect(service.cameraMoves, movesBefore);
      expect(find.byKey(const Key('thermal_attribution')), findsOneWidget);
    },
  );

  testWidgets('manual variant disables re-evaluation', (tester) async {
    var now = DateTime.utc(2026, 3, 20, 11, 0);
    final service = _FakeMapService();
    await tester.pumpWidget(
      _host(
        MapWidget(
          mapService: service,
          pilotPosition: _krippenstein,
          thermalSeason: ThermalSeason.jul,
          thermalTimeOfDay: ThermalTimeOfDay.evening,
          thermalOpacity: 0.4,
          clock: () => now,
        ),
      ),
    );
    await tester.pump();
    expect(service.builtWith!.variant.layerId, 'thermals_jul_10');
    expect(service.builtWith!.opacity, 0.4);
    now = DateTime.utc(2026, 9, 1, 6);
    await tester.pump(const Duration(minutes: 5));
    expect(service.thermalUpdates, isEmpty);
  });

  testWidgets('pilot jump over 50 km re-evaluates immediately', (tester) async {
    // Close to the morning/midday boundary at Krippenstein; ~6.0 h after
    // sunrise there but only ~5.5 h at a point ~700 km west.
    final now = DateTime.utc(2026, 3, 20, 11, 9);
    final service = _FakeMapService();
    Widget build(LatLng pos) => _host(
      MapWidget(mapService: service, pilotPosition: pos, clock: () => now),
    );
    await tester.pumpWidget(build(_krippenstein));
    await tester.pump();
    expect(service.builtWith!.variant.timeOfDay, ThermalTimeOfDay.midday);

    await tester.pumpWidget(build(const LatLng(47.5, 4.5)));
    await tester.pump();
    expect(service.thermalUpdates, hasLength(1));
    expect(
      service.thermalUpdates.single!.variant.timeOfDay,
      ThermalTimeOfDay.morning,
    );
  });

  group('Thermal attribution', () {
    testWidgets('Scenario: attribution while visible', (tester) async {
      await tester.pumpWidget(
        _host(MapWidget(mapService: _FakeMapService(), showThermals: true)),
      );
      await tester.pump();
      expect(find.text(Kk7Provider.attributionText), findsOneWidget);
      expect(
        Kk7Provider.attributionText,
        'Thermal map © thermal.kk7.ch, CC BY-NC-SA 4.0',
      );
    });

    testWidgets('Scenario: no attribution when hidden; toggling updates the '
        'layer', (tester) async {
      final service = _FakeMapService();
      await tester.pumpWidget(
        _host(MapWidget(mapService: service, showThermals: false)),
      );
      await tester.pump();
      expect(service.builtWith, isNull);
      expect(find.text(Kk7Provider.attributionText), findsNothing);

      await tester.pumpWidget(
        _host(MapWidget(mapService: service, showThermals: true)),
      );
      await tester.pump();
      expect(find.text(Kk7Provider.attributionText), findsOneWidget);
      expect(service.thermalUpdates.last, isNotNull);

      await tester.pumpWidget(
        _host(MapWidget(mapService: service, showThermals: false)),
      );
      await tester.pump();
      expect(find.text(Kk7Provider.attributionText), findsNothing);
      expect(service.thermalUpdates.last, isNull);
    });
  });
}
