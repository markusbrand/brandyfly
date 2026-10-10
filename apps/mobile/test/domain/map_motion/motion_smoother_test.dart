import 'dart:math' as math;

import 'package:brandyfly/domain/map_motion/motion_smoother.dart';
import 'package:flutter_test/flutter_test.dart';

const _lat0 = 47.5;
const _lon0 = 13.6;
const _mPerDegLat = 111320.0;
final _mPerDegLon = _mPerDegLat * math.cos(_lat0 * math.pi / 180);

/// Fix [east]/[north] meters from the reference point.
MotionFix _fix(
  double east,
  double north, {
  double? heading,
  double? speed,
  bool stale = false,
}) => MotionFix(
  latitude: _lat0 + north / _mPerDegLat,
  longitude: _lon0 + east / _mPerDegLon,
  headingDeg: heading,
  speedKmh: speed,
  stale: stale,
);

double _dist(MotionSample a, MotionSample b) =>
    MotionSmoother.distanceM(a.latitude, a.longitude, b.latitude, b.longitude);

double _distToFix(MotionSample a, MotionFix f) =>
    MotionSmoother.distanceM(a.latitude, a.longitude, f.latitude, f.longitude);

const _frame = 1 / 60;

void main() {
  group('MotionSmoother position', () {
    test('1 Hz straight flight produces continuous motion between fixes', () {
      final s = MotionSmoother();
      const speed = 40 / 3.6; // m/s north-east
      final vE = speed * math.sin(math.pi / 4);
      final vN = speed * math.cos(math.pi / 4);
      MotionSample? prev;
      var maxStep = 0.0;
      var t = 0.0;
      var nextFix = 0.0;
      var k = 0;
      while (t < 10.0) {
        if (t >= nextFix - 1e-9) {
          s.addFix(_fix(vE * k, vN * k, heading: 45), t);
          k++;
          nextFix += 1.0;
        }
        final cur = s.sample(t)!;
        if (prev != null && t > 2.0) {
          // after the first velocity estimate
          maxStep = math.max(maxStep, _dist(prev, cur));
          expect(_dist(prev, cur), greaterThan(0), reason: 'moves every frame');
        }
        prev = cur;
        t += _frame;
      }
      // Fix spacing is ~11.1 m; no frame may jump more than 25 % of it.
      expect(maxStep, lessThan(0.25 * speed));
      // And motion follows the fixes north-east.
      final (ve, vn) = s.velocity;
      expect(ve, closeTo(vE, 0.5));
      expect(vn, closeTo(vN, 0.5));
    });

    test('first velocity estimate blends without a jump', () {
      final s = MotionSmoother();
      s.addFix(_fix(0, 0), 0);
      final before = s.sample(1.0)!;
      s.addFix(_fix(0, 11), 1.0);
      final after = s.sample(1.0 + _frame)!;
      expect(_dist(before, after), lessThan(0.25 * 11));
    });

    test('4x replay speed moves continuously at the on-screen rate', () {
      final s = MotionSmoother();
      // 1 s of sim time per fix, delivered every 0.25 s wall time.
      const simSpeed = 11.0; // m per fix
      var t = 0.0;
      var k = 0;
      var nextFix = 0.0;
      MotionSample? prev;
      var maxStep = 0.0;
      while (t < 4.0) {
        if (t >= nextFix - 1e-9) {
          s.addFix(_fix(0, simSpeed * k), t);
          k++;
          nextFix += 0.25;
        }
        final cur = s.sample(t)!;
        if (prev != null && t > 0.6) {
          maxStep = math.max(maxStep, _dist(prev, cur));
        }
        prev = cur;
        t += _frame;
      }
      final (_, vn) = s.velocity;
      expect(vn, closeTo(44.0, 2.0)); // 11 m / 0.25 s
      expect(maxStep, lessThan(0.25 * simSpeed));
    });

    test('prediction stops after 1.5 fix intervals (max 2.0 s)', () {
      final s = MotionSmoother();
      s.addFix(_fix(0, 0), 0);
      s.addFix(_fix(0, 10), 1);
      expect(s.horizon, closeTo(1.5, 1e-9));
      final atHorizon = s.sample(2.5)!;
      final later = s.sample(10.0)!;
      expect(_dist(atHorizon, later), lessThan(0.01));
      // Extrapolated 1.5 s * 10 m/s past the last fix.
      expect(_distToFix(later, _fix(0, 25)), lessThan(0.5));
      expect(s.isSettled(3.0), isTrue);
      expect(s.isSettled(2.0), isFalse);
    });

    test('slow fix streams are capped at the 2.0 s horizon', () {
      final s = MotionSmoother();
      s.addFix(_fix(0, 0), 0);
      s.addFix(_fix(0, 20), 2);
      expect(s.horizon, 2.0);
    });

    test('a paused 4 Hz stream overshoots by at most half an interval '
        'beyond the expected next fix', () {
      final s = MotionSmoother();
      // 44 m/s on screen (4x replay), fixes every 0.25 s.
      for (var k = 0; k <= 8; k++) {
        s.addFix(_fix(0, 11.0 * k), k * 0.25);
      }
      final last = _fix(0, 88);
      // Stream pauses: the display holds 1.5 intervals (0.375 s * 44 m/s)
      // past the last fix, i.e. 5.5 m beyond where the next fix was due -
      // instead of 2 s * 44 m/s = 88 m with a fixed horizon.
      final held = s.sample(5)!;
      expect(_distToFix(held, last), closeTo(16.5, 0.5));
      // Resuming does not pull the display back by tens of meters.
      s.addFix(_fix(0, 99), 5);
      final next = s.sample(5 + _frame)!;
      expect(_dist(held, next), lessThan(2.0));
    });

    test('a 15 m correction converges within 0.5 s without a jump', () {
      final s = MotionSmoother();
      for (var k = 0; k < 5; k++) {
        s.addFix(_fix(0, 10.0 * k), k.toDouble());
      }
      final shown = s.sample(5.0)!;
      final corrected = _fix(15, 50); // 15 m east of the predicted position
      s.addFix(corrected, 5.0);
      final next = s.sample(5.0 + _frame)!;
      expect(_dist(shown, next), lessThan(5), reason: 'no visible jump');
      final (ve, vn) = s.velocity;
      final onTrajectory = _fix(15 + ve * 0.5, 50 + vn * 0.5);
      expect(_distToFix(s.sample(5.5)!, onTrajectory), lessThan(0.5));
    });

    test('a fix more than 300 m away snaps immediately', () {
      final s = MotionSmoother();
      s.addFix(_fix(0, 0), 0);
      s.addFix(_fix(0, 10), 1);
      final far = _fix(1000, 0);
      s.addFix(far, 2);
      expect(_distToFix(s.sample(2)!, far), lessThan(0.01));
      expect(s.velocity, (0.0, 0.0), reason: 'velocity reset on snap');
    });

    test('explicit snap (replay seek) jumps even for short distances', () {
      final s = MotionSmoother();
      s.addFix(_fix(0, 0), 0);
      final f = _fix(50, 0);
      s.addFix(f, 1, snap: true);
      expect(_distToFix(s.sample(1)!, f), lessThan(0.01));
    });

    test('stale fixes freeze the display', () {
      final s = MotionSmoother();
      s.addFix(_fix(0, 0), 0);
      s.addFix(_fix(0, 10), 1);
      final shown = s.sample(1.5)!;
      s.addFix(_fix(0, 500, stale: true), 1.5);
      expect(s.isStale, isTrue);
      expect(_dist(s.sample(1.5)!, shown), lessThan(0.01));
      expect(_dist(s.sample(5)!, shown), lessThan(0.01));
      expect(s.isSettled(1.6), isTrue);
      // Recovery snaps to the next valid fix.
      final valid = _fix(0, 30);
      s.addFix(valid, 6);
      expect(s.isStale, isFalse);
      expect(_distToFix(s.sample(6)!, valid), lessThan(0.01));
    });

    test('no fix yields no sample and is settled', () {
      final s = MotionSmoother();
      expect(s.sample(1), isNull);
      expect(s.isSettled(1), isTrue);
    });
  });

  group('MotionSmoother heading', () {
    test('circling at 18 deg/s rotates continuously, not in steps', () {
      final s = MotionSmoother();
      var t = 0.0;
      var k = 0;
      var nextFix = 0.0;
      double? prev;
      var maxStep = 0.0;
      while (t < 20) {
        if (t >= nextFix - 1e-9) {
          s.addFix(_fix(0, 0, heading: (18.0 * k) % 360, speed: 36), t);
          k++;
          nextFix += 1;
        }
        final h = s.sample(t)!.headingDeg;
        if (prev != null && t > 8) {
          final d = MotionSmoother.shortestDelta(prev, h).abs();
          maxStep = math.max(maxStep, d);
          expect(d, greaterThan(0), reason: 'rotates on every frame');
        }
        prev = h;
        t += _frame;
      }
      // 18 deg per fix; per-frame steps stay far below that.
      expect(maxStep, lessThan(3.0));
      // Steady state tracks the turn closely.
      final err = MotionSmoother.shortestDelta(
        s.sample(t)!.headingDeg,
        (18.0 * (t)) % 360,
      ).abs();
      expect(err, lessThan(10));
    });

    test('±3 deg alternating jitter is attenuated by at least 50 %', () {
      final s = MotionSmoother();
      var minH = double.infinity;
      var maxH = -double.infinity;
      for (var k = 0; k < 60; k++) {
        s.addFix(
          _fix(0, 0, heading: 90 + (k.isOdd ? 3.0 : -3.0), speed: 38),
          k.toDouble(),
        );
        if (k < 30) continue;
        for (var f = 0; f < 60; f++) {
          final h = s.sample(k + f * _frame)!.headingDeg;
          minH = math.min(minH, h);
          maxH = math.max(maxH, h);
        }
      }
      expect(maxH - minH, lessThan(3.0)); // raw jitter is 6 deg p-p
    });

    test('wrap-around 355 -> 5 rotates 10 deg through north', () {
      final s = MotionSmoother();
      s.addFix(_fix(0, 0, heading: 355, speed: 38), 0);
      s.addFix(_fix(0, 0, heading: 5, speed: 38), 1);
      for (var f = 0; f < 120; f++) {
        final h = s.sample(1 + f * _frame)!.headingDeg;
        final d = MotionSmoother.shortestDelta(0, h);
        expect(d.abs(), lessThanOrEqualTo(10.01), reason: 'h=$h');
      }
    });

    test('heading is held while on the ground', () {
      final s = MotionSmoother();
      s.addFix(_fix(0, 0, heading: 120, speed: 30), 0);
      s.addFix(_fix(0, 0, heading: 300, speed: 1), 1);
      expect(s.sample(3)!.headingDeg, closeTo(120, 0.5));
    });
  });

  test('identical fix/time sequences yield identical output', () {
    List<String> run() {
      final s = MotionSmoother();
      final out = <String>[];
      final rnd = math.Random(7);
      var t = 0.0;
      for (var k = 0; k < 30; k++) {
        s.addFix(
          _fix(k * 11.0, rnd.nextDouble() * 3, heading: rnd.nextDouble() * 360),
          t,
        );
        for (var f = 0; f < 10; f++) {
          out.add(s.sample(t + f * 0.1).toString());
        }
        t += 1.0;
      }
      return out;
    }

    expect(run(), run());
  });
}
