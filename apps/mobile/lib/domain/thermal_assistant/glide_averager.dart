import 'dart:collection';

class _GlideSample {
  const _GlideSample(this.timestampMs, this.speedKmh, this.climbRateMs);
  final int timestampMs;
  final double speedKmh;
  final double climbRateMs;
}

/// Rolling integrated glide ratio (L/D) averager.
///
/// Accumulates horizontal groundspeed (km/h) and vertical climb/sink rate (m/s)
/// samples over a rolling window (default 15s) and computes smoothed L/D when
/// the aircraft is in a descending glide. Gaps exceeding [maxInterruptionGapMs]
/// (5 s) clear the sample window to avoid averaging across telemetry drops.
class GlideAverager {
  GlideAverager({this.defaultWindow = const Duration(seconds: 15)});

  static const int maxInterruptionGapMs = 5000;
  static const int maxRetentionMs = 35000;

  /// Minimum sink rate threshold (m/s) required to compute a valid descending L/D.
  static const double minDescendingVarioMs = -0.05;

  /// Minimum groundspeed (km/h) required to compute a valid airborne L/D.
  static const double minAirborneSpeedKmh = 5.0;

  /// Clamping bounds for readable cockpit L/D output.
  static const double minGlideRatio = 0.5;
  static const double maxGlideRatio = 50.0;

  final Duration defaultWindow;
  final Queue<_GlideSample> _samples = Queue<_GlideSample>();
  int? _lastTimestampMs;
  double? _lastValidGlide;

  int get sampleCount => _samples.length;

  /// Adds a telemetry sample at [timestampMs] with [speedKmh] and [climbRateMs].
  void addSample(int timestampMs, double speedKmh, double climbRateMs) {
    if (_lastTimestampMs != null &&
        timestampMs - _lastTimestampMs! > maxInterruptionGapMs) {
      _samples.clear();
    }
    _lastTimestampMs = timestampMs;
    _samples.addLast(_GlideSample(timestampMs, speedKmh, climbRateMs));

    final cutoff = timestampMs - maxRetentionMs;
    while (_samples.isNotEmpty && _samples.first.timestampMs < cutoff) {
      _samples.removeFirst();
    }
  }

  /// Calculates the smoothed rolling glide ratio (L/D) over [window]
  /// (or [defaultWindow]).
  ///
  /// When the aircraft is climbing (`meanVario >= -0.05 m/s`) or nearly
  /// stationary (`meanSpeedKmh < 5.0 km/h`), returns the last valid descending
  /// glide ratio if available, or [fallbackGlide].
  double calculateGlide({double fallbackGlide = 8.4, Duration? window}) {
    if (_samples.isEmpty) return _lastValidGlide ?? fallbackGlide;

    final win = window ?? defaultWindow;
    final nowMs = _samples.last.timestampMs;
    final cutoff = nowMs - win.inMilliseconds;

    double sumSpeedKmh = 0.0;
    double sumClimbMs = 0.0;
    int count = 0;

    for (final s in _samples) {
      if (s.timestampMs >= cutoff) {
        sumSpeedKmh += s.speedKmh;
        sumClimbMs += s.climbRateMs;
        count++;
      }
    }

    if (count == 0) {
      return _lastValidGlide ?? fallbackGlide;
    }

    final meanSpeedKmh = sumSpeedKmh / count;
    final meanClimbMs = sumClimbMs / count;

    if (meanSpeedKmh < minAirborneSpeedKmh ||
        meanClimbMs >= minDescendingVarioMs) {
      return _lastValidGlide ?? fallbackGlide;
    }

    final meanSpeedMps = meanSpeedKmh / 3.6;
    final rawLd = -meanSpeedMps / meanClimbMs;
    final clampedLd = rawLd.clamp(minGlideRatio, maxGlideRatio);
    _lastValidGlide = clampedLd;
    return clampedLd;
  }

  void reset() {
    _samples.clear();
    _lastTimestampMs = null;
    _lastValidGlide = null;
  }
}
