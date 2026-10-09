import 'dart:math' as math;

import 'package:brandyfly/data/repositories/telemetry_repository.dart';
import 'package:brandyfly/services/flight_replay_service.dart';
import 'package:brandyfly/services/telemetry/telemetry_types.dart';
import 'package:flutter_test/flutter_test.dart';

/// Generates live snapshots of a glider turning in a drifting airmass.
class _Pilot {
  DateTime t = DateTime.utc(2026, 7, 1, 12);
  double lat = 47.5;
  double lon = 13.7;
  double heading = 0;

  TelemetrySnapshot step(
    double turnDps, {
    double windE = 5.0,
    Duration dt = const Duration(seconds: 1),
    bool stale = false,
  }) {
    final s = dt.inMilliseconds / 1000.0;
    heading = (heading + turnDps * s) % 360.0;
    final h = heading * math.pi / 180;
    final ve = 10 * math.sin(h) + windE;
    final vn = 10 * math.cos(h);
    lat += vn * s / 6371000.0 * 180 / math.pi;
    lon += ve * s / (6371000.0 * math.cos(lat * math.pi / 180)) * 180 / math.pi;
    t = t.add(dt);
    return TelemetrySnapshot(
      timestamp: t,
      altitude: 1500,
      vario: turnDps != 0 ? 2.0 : -1.0,
      speed: 36,
      heading: heading,
      latitude: lat,
      longitude: lon,
      isStale: stale,
    );
  }
}

void main() {
  late FlightReplayService replay;
  late TelemetryRepository repo;
  late _Pilot pilot;

  setUp(() {
    replay = FlightReplayService();
    repo = TelemetryRepository(replayService: replay);
    pilot = _Pilot();
  });

  tearDown(() {
    repo.dispose();
    replay.dispose();
  });

  test('wind is never fabricated before an estimate exists', () {
    for (var i = 0; i < 30; i++) {
      repo.onSnapshot(pilot.step(0));
    }
    final t = repo.telemetry.value;
    expect(t.hasSource, isTrue);
    expect(t.windDir, isNull);
    expect(t.windSpeed, isNull);
    expect(t.thermal.isCircling, isFalse);
  });

  test('circling is flagged once 270 degrees are turned', () {
    var circlingAt = -1;
    for (var i = 0; i < 20; i++) {
      repo.onSnapshot(pilot.step(19));
      if (circlingAt < 0 && repo.telemetry.value.thermal.isCircling) {
        circlingAt = i;
      }
    }
    // Sample 0 contributes no delta; sample i has turned i x 19 deg, so the
    // first sample >= 270 deg is index 15 (285 deg).
    expect(circlingAt, 15);
    expect(repo.telemetry.value.thermal.track, isNotEmpty);
  });

  test('wind is published after two complete turns and matches drift', () {
    for (var i = 0; i < 60; i++) {
      repo.onSnapshot(pilot.step(18));
    }
    final t = repo.telemetry.value;
    expect(t.windDir, isNotNull);
    expect(t.windDir!, closeTo(270, 10));
    expect(t.windSpeed!, closeTo(18, 4));
    expect(t.windStale, isFalse);
  });

  test('GPS dropout > 5 s falls back to gliding and retains wind', () {
    for (var i = 0; i < 60; i++) {
      repo.onSnapshot(pilot.step(18));
    }
    final wind = repo.telemetry.value.windDir;
    expect(repo.telemetry.value.thermal.isCircling, isTrue);
    repo.onSnapshot(pilot.step(18, dt: const Duration(seconds: 7)));
    final t = repo.telemetry.value;
    expect(t.thermal.isCircling, isFalse);
    expect(t.thermal.track, isEmpty);
    expect(t.windDir, wind);
  });

  test('stale samples do not feed the thermal assistant', () {
    for (var i = 0; i < 10; i++) {
      repo.onSnapshot(pilot.step(0));
    }
    final rev = repo.telemetry.value.thermal.revision;
    for (var i = 0; i < 20; i++) {
      repo.onSnapshot(pilot.step(19, stale: true));
    }
    expect(repo.telemetry.value.thermal.isCircling, isFalse);
    expect(repo.telemetry.value.thermal.revision, rev);
    expect(repo.telemetry.value.isStale, isTrue);
  });

  test('detaching the source resets thermal state', () {
    for (var i = 0; i < 60; i++) {
      repo.onSnapshot(pilot.step(18));
    }
    repo.detachSource();
    expect(repo.thermalState.isCircling, isFalse);
    expect(repo.thermalState.wind, isNull);
    expect(repo.telemetry.value.hasSource, isFalse);
  });
}
