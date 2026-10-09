import 'dart:math' as math;

import 'package:brandyfly/domain/thermal_assistant/circling_detector.dart';
import 'package:brandyfly/domain/thermal_assistant/heading_tracker.dart';
import 'package:brandyfly/domain/thermal_assistant/thermal_assistant.dart';
import 'package:brandyfly/domain/thermal_assistant/thermal_assistant_engine.dart';
import 'package:brandyfly/domain/thermal_assistant/thermal_core_calculator.dart';
import 'package:brandyfly/domain/thermal_assistant/wind_estimator.dart';
import 'package:flutter_test/flutter_test.dart';

const double _rEarth = 6371000.0;

/// Kinematic flyer mirroring the Rust test helper.
class _Flyer {
  int tMs = 1000;
  double lat = 47.0;
  double lon = 13.0;
  double heading = 0.0;

  ThermalSample step(
    double turnDps, {
    double airspeed = 10.0,
    double windE = 0.0,
    double windN = 0.0,
    double climb = 2.0,
    int dtMs = 1000,
  }) {
    final dt = dtMs / 1000.0;
    heading = (heading + turnDps * dt) % 360.0;
    final h = heading * math.pi / 180.0;
    final ve = airspeed * math.sin(h) + windE;
    final vn = airspeed * math.cos(h) + windN;
    lat += vn * dt / _rEarth * 180.0 / math.pi;
    lon +=
        ve * dt / (_rEarth * math.cos(lat * math.pi / 180.0)) * 180.0 / math.pi;
    tMs += dtMs;
    return ThermalSample(
      timestampMs: tMs,
      position: GeoPosition(lat, lon),
      headingDeg: heading,
      climbRateMs: climb,
    );
  }
}

void main() {
  group('heading math', () {
    test('normalizeHeading matches Rust semantics', () {
      expect(normalizeHeading(0.0), 0.0);
      expect(normalizeHeading(180.0), -180.0);
      expect(normalizeHeading(-180.0), -180.0);
      expect(normalizeHeading(350.0), -10.0);
      expect(normalizeHeading(400.0), 40.0);
      expect(normalizeHeading(-10.0), -10.0);
      expect(normalizeHeading(-400.0), -40.0);
    });

    test('headingDelta', () {
      expect(headingDelta(10.0, 20.0), 10.0);
      expect(headingDelta(350.0, 10.0), 20.0);
      expect(headingDelta(10.0, 350.0), -20.0);
      expect(headingDelta(180.0, -170.0), 10.0);
    });
  });

  group('CirclingStateDetector', () {
    test('detects right turn after 270 degrees', () {
      final d = CirclingStateDetector();
      var t = 1000;
      var h = 0.0;
      for (var i = 0; i < 14; i++) {
        expect(d.update(t, h), const FlightModeState.gliding());
        t += 1000;
        h = (h + 20.0) % 360.0;
      }
      expect(
        d.update(t, h),
        const FlightModeState.circling(TurnDirection.right),
      );
    });

    test('detects left turn', () {
      final d = CirclingStateDetector();
      var t = 1000;
      var h = 0.0;
      for (var i = 0; i < 14; i++) {
        expect(d.update(t, h), const FlightModeState.gliding());
        t += 1000;
        h = (h - 20.0 + 360.0) % 360.0;
      }
      expect(
        d.update(t, h),
        const FlightModeState.circling(TurnDirection.left),
      );
    });

    test('rejects erratic heading reversals', () {
      final d = CirclingStateDetector();
      var t = 1000;
      var h = 0.0;
      for (var i = 0; i < 30; i++) {
        expect(d.update(t, h), const FlightModeState.gliding());
        t += 1000;
        h = h == 0.0 ? 45.0 : 0.0;
      }
    });

    test('returns to gliding after 8 s of stable heading', () {
      final d = CirclingStateDetector();
      var t = 1000;
      var h = 0.0;
      for (var i = 0; i < 15; i++) {
        d.update(t, h);
        t += 1000;
        h = (h + 20.0) % 360.0;
      }
      expect(d.state, const FlightModeState.circling(TurnDirection.right));
      for (var i = 0; i < 8; i++) {
        expect(d.update(t, h).isCircling, isTrue);
        t += 1000;
      }
      expect(d.update(t, h), const FlightModeState.gliding());
    });
  });

  group('WindEstimator', () {
    test('distanceXy', () {
      final (dx, dy) = WindEstimator.distanceXy(
        const GeoPosition(0, 0),
        const GeoPosition(0, 1),
      );
      expect(dx, closeTo(111194.9, 10));
      expect(dy, 0.0);
    });

    test('estimates west wind from eastward drift', () {
      final w = WindEstimator();
      var t = 1000;
      var h = 0.0;
      var lon = 0.0;
      for (var i = 0; i < 80; i++) {
        w.update(t, h, GeoPosition(0.0, lon), true);
        t += 1000;
        h += 10.0;
        if (h >= 360.0) h -= 360.0;
        lon += 10.0 / (_rEarth * math.pi / 180.0);
      }
      final est = w.estimate!;
      expect(est.directionDeg, closeTo(270.0, 5.0));
      expect(est.speedKmh, closeTo(36.0, 1.0));
    });
  });

  group('ThermalCoreCalculator', () {
    test('lift-weighted centroid pulls towards strong lift', () {
      final c = ThermalCoreCalculator()
        ..addPoint(const CoreTrackPoint(1000, GeoPosition(0.001, 0), 2.0))
        ..addPoint(const CoreTrackPoint(2000, GeoPosition(0, 0.001), 1.0))
        ..addPoint(const CoreTrackPoint(3000, GeoPosition(-0.001, 0), -1.0))
        ..addPoint(const CoreTrackPoint(4000, GeoPosition(0, -0.001), -2.0));
      final est = c.calculate(4000, null);
      expect(est.valid, isTrue);
      expect(est.center.lat, greaterThan(0.0));
      expect(est.center.lon, greaterThan(0.0));
      expect(est.center.lat, greaterThan(est.center.lon));
    });

    test('pure sink falls back to geometric centre', () {
      final c = ThermalCoreCalculator()
        ..addPoint(const CoreTrackPoint(1000, GeoPosition(0.001, 0), -1.0))
        ..addPoint(const CoreTrackPoint(2000, GeoPosition(-0.001, 0), -1.0));
      final est = c.calculate(2000, null);
      expect(est.valid, isTrue);
      expect(est.center.lat, closeTo(0.0, 1e-9));
    });

    test('retains at most 60 s of points', () {
      final c = ThermalCoreCalculator();
      for (var i = 0; i < 200; i++) {
        c.addPoint(CoreTrackPoint(i * 1000, const GeoPosition(0, 0), 1));
      }
      expect(c.pointCount, lessThanOrEqualTo(61));
    });
  });

  group('ThermalAssistant orchestrator', () {
    test('enters circling and estimates wind', () {
      final ta = ThermalAssistant();
      final f = _Flyer();
      late ThermalAssistantOutput out;
      for (var i = 0; i < 90; i++) {
        out = ta.update(f.step(18.0, windE: 10.0));
      }
      expect(out.state, const FlightModeState.circling(TurnDirection.right));
      expect(out.wind!.directionDeg, closeTo(270.0, 5.0));
      expect(out.wind!.speedKmh, closeTo(36.0, 2.0));
      expect(out.core, isNotNull);
    });

    test('stale samples are ignored', () {
      final ta = ThermalAssistant();
      final f = _Flyer();
      final before = ta.update(f.step(0.0));
      final s = f.step(90.0);
      final stale = ThermalSample(
        timestampMs: s.timestampMs,
        position: s.position,
        headingDeg: s.headingDeg,
        climbRateMs: s.climbRateMs,
        stale: true,
      );
      expect(identical(ta.update(stale), before), isTrue);
    });

    test('gap interrupts circling but keeps wind', () {
      final ta = ThermalAssistant();
      final f = _Flyer();
      for (var i = 0; i < 90; i++) {
        ta.update(f.step(18.0, windE: 5.0));
      }
      final wind = ta.output.wind;
      expect(ta.output.state.isCircling, isTrue);
      f.tMs += 6000;
      final out = ta.update(f.step(18.0, windE: 5.0));
      expect(out.state.isCircling, isFalse);
      expect(out.core, isNull);
      expect(out.wind, wind);
    });
  });

  group('ThermalAssistantEngine', () {
    test('publishes track only while circling and clears it on glide', () {
      final e = ThermalAssistantEngine();
      final f = _Flyer();
      for (var i = 0; i < 5; i++) {
        expect(e.update(f.step(0.0)).track, isEmpty);
      }
      late ThermalAssistantState s;
      for (var i = 0; i < 60; i++) {
        s = e.update(f.step(18.0, windE: 4.0));
      }
      expect(s.isCircling, isTrue);
      expect(s.track, isNotEmpty);
      expect(s.core, isNotNull);
      for (var i = 0; i < 12; i++) {
        s = e.update(f.step(0.0, windE: 4.0));
      }
      expect(s.isCircling, isFalse);
      expect(s.track, isEmpty);
      expect(s.core, isNull);
      expect(s.wind, isNotNull, reason: 'wind retained after glide');
    });

    test('marks wind stale after 15 minutes without refinement', () {
      final e = ThermalAssistantEngine();
      final f = _Flyer();
      for (var i = 0; i < 90; i++) {
        e.update(f.step(18.0, windE: 5.0));
      }
      for (var i = 0; i < 12; i++) {
        e.update(f.step(0.0, windE: 5.0));
      }
      expect(e.state.wind!.isStale, isFalse);
      // Glide on for > 15 min at 1 Hz.
      for (var i = 0; i < 15 * 60 + 5; i++) {
        e.update(f.step(0.0, windE: 5.0));
      }
      expect(e.state.wind!.isStale, isTrue);
    });

    test('revision only changes when published content changes', () {
      final e = ThermalAssistantEngine();
      final f = _Flyer();
      final r0 = e.update(f.step(0.0, dtMs: 100)).revision;
      // Gliding: track not published, so 100 ms ticks do not bump revision.
      final r1 = e.update(f.step(0.0, dtMs: 100)).revision;
      expect(r1, r0);
    });

    test('track window bounded to 300 s and 1 Hz', () {
      final e = ThermalAssistantEngine();
      final f = _Flyer();
      for (var i = 0; i < 6000; i++) {
        e.update(f.step(18.0, dtMs: 100));
      }
      expect(e.trackSampleCount, lessThanOrEqualTo(301));
      expect(e.coreSampleCount, lessThanOrEqualTo(601));
    });
  });
}
