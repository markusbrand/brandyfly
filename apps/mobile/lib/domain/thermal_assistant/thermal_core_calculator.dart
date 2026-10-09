/// Lift-weighted thermal core calculation. Port of `ThermalCoreCalculator`
/// in `crates/flight_core/src/thermal.rs`.
library;

import 'dart:collection';
import 'dart:math' as math;

import 'thermal_types.dart';

class CoreTrackPoint {
  const CoreTrackPoint(this.timestampMs, this.position, this.climbRateMs);

  final int timestampMs;
  final GeoPosition position;
  final double climbRateMs;
}

/// Thermal core estimate in ground coordinates.
class ThermalCoreEstimate {
  const ThermalCoreEstimate({
    required this.center,
    required this.centerAirmass,
    required this.valid,
  });

  final GeoPosition center;
  final GeoPosition centerAirmass;
  final bool valid;
}

class ThermalCoreCalculator {
  ThermalCoreCalculator();

  /// History used for the core calculation.
  static const int windowDurationMs = 60000;
  static const double _rEarth = 6371000.0;

  final Queue<CoreTrackPoint> _points = Queue<CoreTrackPoint>();

  int get pointCount => _points.length;

  void reset() => _points.clear();

  /// Independent deep copy (points are immutable and shared).
  ThermalCoreCalculator clone() =>
      ThermalCoreCalculator().._points.addAll(_points);

  void addPoint(CoreTrackPoint point) {
    _points.addLast(point);
    final cutoff = point.timestampMs > windowDurationMs
        ? point.timestampMs - windowDurationMs
        : 0;
    while (_points.isNotEmpty && _points.first.timestampMs < cutoff) {
      _points.removeFirst();
    }
  }

  ThermalCoreEstimate calculate(int currentTimeMs, WindVector? wind) {
    if (_points.isEmpty) {
      return const ThermalCoreEstimate(
        center: GeoPosition(0.0, 0.0),
        centerAirmass: GeoPosition(0.0, 0.0),
        valid: false,
      );
    }

    final windVx = wind?.velocityXMs ?? 0.0;
    final windVy = wind?.velocityYMs ?? 0.0;

    final ref = _points.last.position;
    final refTime = currentTimeMs;
    final refLatRad = ref.lat * math.pi / 180.0;
    const degToRad = math.pi / 180.0;
    const radToDeg = 180.0 / math.pi;
    final cosRef = math.cos(refLatRad);

    var sumW = 0.0;
    var sumWx = 0.0;
    var sumWy = 0.0;
    var sumX = 0.0;
    var sumY = 0.0;
    final n = _points.length.toDouble();

    for (final p in _points) {
      final dtS = (refTime.toDouble() - p.timestampMs.toDouble()) / 1000.0;
      final dxGps = (p.position.lon - ref.lon) * degToRad * _rEarth * cosRef;
      final dyGps = (p.position.lat - ref.lat) * degToRad * _rEarth;
      final xAir = dxGps + windVx * dtS;
      final yAir = dyGps + windVy * dtS;

      final climb = math.max(p.climbRateMs, 0.0);
      final w = climb * climb;

      sumW += w;
      sumWx += w * xAir;
      sumWy += w * yAir;
      sumX += xAir;
      sumY += yAir;
    }

    final double coreX;
    final double coreY;
    if (sumW < 1e-6) {
      coreX = sumX / n;
      coreY = sumY / n;
    } else {
      coreX = sumWx / sumW;
      coreY = sumWy / sumW;
    }

    final dLat = coreY / _rEarth * radToDeg;
    final dLon = coreX / (_rEarth * cosRef) * radToDeg;
    final centerAirmass = GeoPosition(ref.lat + dLat, ref.lon + dLon);

    return ThermalCoreEstimate(
      center: centerAirmass,
      centerAirmass: centerAirmass,
      valid: true,
    );
  }
}
