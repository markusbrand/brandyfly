import 'dart:math' as math;

import 'package:brandyfly/data/repositories/telemetry_repository.dart';
import 'package:brandyfly/domain/models/cockpit_telemetry.dart';
import 'package:brandyfly/domain/thermal/thermal_layer_spec.dart';
import 'package:brandyfly/models/flight_model.dart';
import 'package:brandyfly/models/lat_lng.dart';
import 'package:brandyfly/services/flight_replay_service.dart';
import 'package:brandyfly/services/maplibre_map_service.dart';
import 'package:brandyfly/ui/features/map/views/map_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _QuietMapService extends MapLibreMapService {
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
  }) async {}
}

FlightModel _flight({int n = 120}) {
  final base = DateTime.utc(2026, 7, 1, 10);
  final points = [
    for (var i = 0; i < n; i++)
      FlightPoint(
        timestamp: base.add(Duration(seconds: i)),
        latitude: 47.5 + 0.0001 * math.sin(i / 10) + i * 0.00005,
        longitude: 13.6 + 0.0001 * math.cos(i / 10),
        altitude: 1500 + i * 0.5,
        vario: math.sin(i / 7) * 2,
        speed: 36,
        heading: (i * 18.0) % 360,
      ),
  ];
  return FlightModel(id: 'f', title: 'Replay', date: base, points: points);
}

String _signature(CockpitTelemetry t) =>
    '${t.latitude},${t.longitude},${t.altitude},${t.heading},${t.climb},'
    '${t.flightPoints?.length},${t.flightPoints?.last.timestamp},'
    '${t.thermal.revision}';

void main() {
  group('Replay track views', () {
    test('replay ticks do not copy the track; seek replaces the list', () {
      final replay = FlightReplayService(flight: _flight());
      addTearDown(replay.dispose);
      final first =
          replay.currentTelemetry['flightPoints'] as List<FlightPoint>;
      replay.advance(1);
      replay.advance(1);
      final later =
          replay.currentTelemetry['flightPoints'] as List<FlightPoint>;
      expect(identical(first, later), isTrue, reason: 'live view, no copy');
      expect(later.length, 3);
      expect(() => later.add(later.first), throwsUnsupportedError);

      replay.seekTo(50);
      final afterSeek =
          replay.currentTelemetry['flightPoints'] as List<FlightPoint>;
      expect(identical(afterSeek, later), isFalse, reason: 'seek = new list');
      expect(afterSeek.length, 51);
    });
  });

  testWidgets(
    'smoothed map is presentation-only: replay telemetry is identical '
    'with and without the map mounted',
    (tester) async {
      Future<List<String>> run({required bool withMap}) async {
        final replay = FlightReplayService(flight: _flight());
        final repo = TelemetryRepository(replayService: replay);
        repo.setReplayActive(true);
        final service = _QuietMapService();
        final out = <String>[];
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: withMap
                  ? SizedBox(
                      width: 400,
                      height: 400,
                      child: MapWidget(
                        mapService: service,
                        telemetry: repo.telemetry,
                        showThermals: false,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        );
        for (var i = 0; i < 100; i++) {
          replay.advance(1);
          out.add(_signature(repo.telemetry.value));
          await tester.pump(const Duration(milliseconds: 250));
        }
        replay.seekTo(10);
        out.add(_signature(repo.telemetry.value));
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 3));
        repo.dispose();
        replay.dispose();
        service.dispose();
        return out;
      }

      final withMap = await run(withMap: true);
      final withoutMap = await run(withMap: false);
      expect(withMap, hasLength(101));
      expect(withMap, withoutMap);
    },
  );
}
