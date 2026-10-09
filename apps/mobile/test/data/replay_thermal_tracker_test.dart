import 'dart:math' as math;

import 'package:brandyfly/data/repositories/replay_thermal_tracker.dart';
import 'package:brandyfly/data/repositories/telemetry_repository.dart';
import 'package:brandyfly/domain/thermal_assistant/thermal_assistant_engine.dart';
import 'package:brandyfly/models/flight_model.dart';
import 'package:brandyfly/services/flight_replay_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// 30 min recorded flight at 1 Hz: repeated glide (90 s) / thermal (150 s)
/// cycles drifting in a 5 m/s westerly.
List<FlightPoint> _flight() {
  const r = 6371000.0;
  final pts = <FlightPoint>[];
  var t = DateTime.utc(2026, 7, 1, 11);
  var lat = 47.5;
  var lon = 13.7;
  var heading = 30.0;
  for (var i = 0; i < 1800; i++) {
    final circling = (i % 240) >= 90;
    heading = (heading + (circling ? 18.0 : 0.0)) % 360.0;
    final h = heading * math.pi / 180;
    lat += 10 * math.cos(h) / r * 180 / math.pi;
    lon +=
        (10 * math.sin(h) + 5) /
        (r * math.cos(lat * math.pi / 180)) *
        180 /
        math.pi;
    t = t.add(const Duration(seconds: 1));
    pts.add(
      FlightPoint(
        timestamp: t,
        latitude: lat,
        longitude: lon,
        altitude: 1500,
        vario: circling ? 2.0 + math.sin(i / 5) : -1.1,
        speed: 36,
        heading: heading,
      ),
    );
  }
  return pts;
}

/// Content of a state without its UI revision counter.
String _content(ThermalAssistantState s) {
  final w = s.wind;
  final c = s.core;
  return [
    s.mode,
    w == null
        ? '-'
        : '${w.directionDeg},${w.speedKmh},${w.updatedAt},${w.isStale}',
    c == null ? '-' : '${c.lat},${c.lon}',
    s.track.length,
    if (s.track.isNotEmpty) s.track.first.timestamp,
    if (s.track.isNotEmpty) s.track.last.position,
  ].join('|');
}

void main() {
  final points = _flight();

  List<String> continuous() {
    final tracker = ReplayThermalTracker();
    return [
      for (var i = 0; i < points.length; i++)
        _content(tracker.advanceTo(points, i)),
    ];
  }

  test('two full replays produce identical state sequences', () {
    final a = continuous();
    final b = continuous();
    expect(a, b);
    expect(a.where((s) => s.contains('circling')), isNotEmpty);
    expect(a.last, isNot(contains('|-|-|')), reason: 'wind estimated');
  });

  test('random seeks yield exactly the continuous-replay state', () {
    final reference = continuous();
    final tracker = ReplayThermalTracker();
    final rnd = math.Random(7);
    for (var k = 0; k < 300; k++) {
      final target = rnd.nextInt(points.length);
      final s = tracker.advanceTo(points, target);
      expect(_content(s), reference[target], reason: 'seek #$k to $target');
    }
  });

  test('backward seek reprocesses at most 60 s of flight', () {
    final tracker = ReplayThermalTracker();
    tracker.advanceTo(points, points.length - 1);
    expect(tracker.checkpointCount, greaterThan(20));
    final rnd = math.Random(3);
    for (var k = 0; k < 100; k++) {
      final target = rnd.nextInt(points.length - 1);
      tracker.advanceTo(points, points.length - 1);
      tracker.advanceTo(points, target);
      expect(tracker.lastFedCount, lessThanOrEqualTo(60), reason: 'to $target');
    }
  });

  test('restored state publishes a fresh revision', () {
    final tracker = ReplayThermalTracker();
    final late = tracker.advanceTo(points, 1500).revision;
    final early = tracker.advanceTo(points, 100).revision;
    expect(early, greaterThan(late));
  });

  test('repository publishes replay thermal state and wind', () {
    final flight = FlightModel(
      id: 'f',
      title: 'Test',
      date: points.first.timestamp,
      points: points,
    );
    final replay = FlightReplayService(flight: flight);
    final repo = TelemetryRepository(replayService: replay);
    addTearDown(() {
      repo.dispose();
      replay.dispose();
    });
    repo.setReplayActive(true);
    replay.seekTo(1000);
    final t = repo.telemetry.value;
    expect(t.hasSource, isTrue);
    expect(_content(t.thermal), continuous()[1000]);
    expect(t.windDir, t.thermal.wind?.directionDeg);
    expect(t.windDir, isNotNull);

    replay.seekTo(200);
    expect(_content(repo.telemetry.value.thermal), continuous()[200]);
  });
}
