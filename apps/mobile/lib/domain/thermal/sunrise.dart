import 'dart:math' as math;

/// Result of a sunrise computation for a calendar date and position.
sealed class SunriseResult {
  const SunriseResult();
}

/// The sun rises at [utc].
class SunriseAt extends SunriseResult {
  const SunriseAt(this.utc);
  final DateTime utc;
}

/// The sun stays above the horizon all day (polar day).
class PolarDay extends SunriseResult {
  const PolarDay();
}

/// The sun stays below the horizon all day (polar night).
class PolarNight extends SunriseResult {
  const PolarNight();
}

/// Offline sunrise calculation (NOAA / standard sunrise equation, about
/// one-minute accuracy for |latitude| < 65°). Pure Dart, no network.
class SunriseCalculator {
  const SunriseCalculator._();

  static const double _deg = math.pi / 180.0;

  /// Official sunrise zenith including refraction and solar disc radius.
  static const double _horizonAltitudeDeg = -0.833;

  /// Computes sunrise for the local calendar day [year]-[month]-[day] at
  /// [latitude] / [longitude] (degrees, east positive).
  static SunriseResult sunrise({
    required int year,
    required int month,
    required int day,
    required double latitude,
    required double longitude,
  }) {
    // Julian day at 12:00 UTC of the given date.
    final noonUtc = DateTime.utc(year, month, day, 12);
    final jd = noonUtc.millisecondsSinceEpoch / 86400000.0 + 2440587.5;
    final n = (jd - 2451545.0 + 0.0008).roundToDouble();

    // Mean solar time of local solar noon.
    final jStar = n - longitude / 360.0;
    final m = _norm360(357.5291 + 0.98560028 * jStar);
    final mRad = m * _deg;
    final c =
        1.9148 * math.sin(mRad) +
        0.0200 * math.sin(2 * mRad) +
        0.0003 * math.sin(3 * mRad);
    final lambda = _norm360(m + c + 180.0 + 102.9372);
    final lambdaRad = lambda * _deg;
    final jTransit =
        2451545.0 +
        jStar +
        0.0053 * math.sin(mRad) -
        0.0069 * math.sin(2 * lambdaRad);

    final sinDecl = math.sin(lambdaRad) * math.sin(23.4397 * _deg);
    final cosDecl = math.cos(math.asin(sinDecl));
    final phi = latitude * _deg;
    final cosOmega =
        (math.sin(_horizonAltitudeDeg * _deg) - math.sin(phi) * sinDecl) /
        (math.cos(phi) * cosDecl);

    if (cosOmega > 1.0) return const PolarNight();
    if (cosOmega < -1.0) return const PolarDay();

    final omegaDeg = math.acos(cosOmega) / _deg;
    final jRise = jTransit - omegaDeg / 360.0;
    final ms = ((jRise - 2440587.5) * 86400000.0).round();
    return SunriseAt(DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true));
  }

  static double _norm360(double v) {
    final r = v % 360.0;
    return r < 0 ? r + 360.0 : r;
  }
}
