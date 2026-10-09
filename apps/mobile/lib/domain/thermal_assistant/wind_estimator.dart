/// Multi-turn wind drift estimation. Port of `WindEstimator` in
/// `crates/flight_core/src/wind.rs`.
library;

import 'dart:math' as math;

import 'heading_tracker.dart';
import 'thermal_types.dart';

class _TurnCompletion {
  const _TurnCompletion(this.timestampMs, this.position);

  final int timestampMs;
  final GeoPosition position;
}

class WindEstimator {
  WindEstimator();

  static const double _rEarth = 6371000.0;
  static const double _alpha = 0.6;

  final List<_TurnCompletion> _turnCompletions = [];
  double _currentTurnRotation = 0.0;
  double? _lastHeading;
  WindVector? _currentEstimate;

  WindVector? get estimate => _currentEstimate;

  /// Independent deep copy.
  WindEstimator clone() => WindEstimator()
    .._turnCompletions.addAll(_turnCompletions)
    .._currentTurnRotation = _currentTurnRotation
    .._lastHeading = _lastHeading
    .._currentEstimate = _currentEstimate;

  /// Clears turn tracking but keeps the last wind estimate.
  void reset() {
    _turnCompletions.clear();
    _currentTurnRotation = 0.0;
    _lastHeading = null;
  }

  /// Equirectangular metres east/north from [p1] to [p2].
  static (double, double) distanceXy(GeoPosition p1, GeoPosition p2) {
    final latMid = (p1.lat + p2.lat) / 2.0 * math.pi / 180.0;
    final dx = (p2.lon - p1.lon) * math.pi / 180.0 * _rEarth * math.cos(latMid);
    final dy = (p2.lat - p1.lat) * math.pi / 180.0 * _rEarth;
    return (dx, dy);
  }

  static double _direction(double vx, double vy) =>
      (math.atan2(-vx, -vy) * 180.0 / math.pi + 360.0).remainder(360.0);

  void update(
    int timestampMs,
    double headingDeg,
    GeoPosition position,
    bool isCircling,
  ) {
    if (!isCircling) {
      reset();
      return;
    }

    final last = _lastHeading;
    if (last != null) {
      _currentTurnRotation += headingDelta(last, headingDeg);

      if (_currentTurnRotation.abs() >= 360.0) {
        final completion = _TurnCompletion(timestampMs, position);
        _currentTurnRotation = _currentTurnRotation.remainder(360.0);

        if (_turnCompletions.isNotEmpty) {
          final prev = _turnCompletions.last;
          final (dx, dy) = distanceXy(prev.position, completion.position);
          final dtS =
              (completion.timestampMs - prev.timestampMs).toDouble() / 1000.0;

          if (dtS > 0.0) {
            final vx = dx / dtS;
            final vy = dy / dtS;
            final speedMs = math.sqrt(vx * vx + vy * vy);
            final speedKmh = speedMs * 3.6;
            var dirDeg = _direction(vx, vy);
            if (dirDeg < 0.0) dirDeg += 360.0;

            final next = WindVector(
              speedKmh: speedKmh,
              directionDeg: dirDeg,
              velocityXMs: vx,
              velocityYMs: vy,
            );

            final old = _currentEstimate;
            if (old == null) {
              _currentEstimate = next;
            } else {
              final vxAvg =
                  old.velocityXMs * (1.0 - _alpha) + next.velocityXMs * _alpha;
              final vyAvg =
                  old.velocityYMs * (1.0 - _alpha) + next.velocityYMs * _alpha;
              _currentEstimate = WindVector(
                speedKmh:
                    old.speedKmh * (1.0 - _alpha) + next.speedKmh * _alpha,
                velocityXMs: vxAvg,
                velocityYMs: vyAvg,
                directionDeg: _direction(vxAvg, vyAvg),
              );
            }
          }
        }

        _turnCompletions.add(completion);
      }
    }

    _lastHeading = headingDeg;
  }
}
