/// Heading tracking primitives. Port of `crates/flight_core/src/circling.rs`
/// (`normalize_heading`, `heading_delta`, `HeadingTracker`).
library;

/// Normalizes a heading in degrees to the range [-180, 180).
///
/// Uses [double.remainder] to match Rust's `%` (truncated, sign of dividend).
double normalizeHeading(double heading) {
  var normalized = heading.remainder(360.0);
  if (normalized < -180.0) {
    normalized += 360.0;
  } else if (normalized >= 180.0) {
    normalized -= 360.0;
  }
  return normalized;
}

/// Shortest signed angular turn from [heading1] to [heading2], in [-180, 180).
double headingDelta(double heading1, double heading2) =>
    normalizeHeading(heading2 - heading1);

class HeadingSample {
  const HeadingSample(this.timestampMs, this.headingDeg);

  final int timestampMs;
  final double headingDeg;
}

/// Sliding window of heading samples.
class HeadingTracker {
  HeadingTracker(this.windowDurationMs);

  final int windowDurationMs;
  final List<HeadingSample> _samples = [];

  int get sampleCount => _samples.length;

  void pushSample(int timestampMs, double headingDeg) {
    _samples.add(HeadingSample(timestampMs, normalizeHeading(headingDeg)));
    final cutoff = _saturatingSub(timestampMs, windowDurationMs);
    _samples.removeWhere((s) => s.timestampMs < cutoff);
  }

  void clear() => _samples.clear();

  /// Independent deep copy (samples are immutable and shared).
  HeadingTracker clone() =>
      HeadingTracker(windowDurationMs).._samples.addAll(_samples);

  /// Cumulative signed heading change across the window.
  double cumulativeHeadingChange() {
    if (_samples.length < 2) return 0.0;
    var total = 0.0;
    var prev = _samples[0].headingDeg;
    for (var i = 1; i < _samples.length; i++) {
      final h = _samples[i].headingDeg;
      total += headingDelta(prev, h);
      prev = h;
    }
    return total;
  }

  /// Whether the heading stayed within [toleranceDeg] for [durationMs].
  bool isHeadingStable(int currentTimeMs, int durationMs, double toleranceDeg) {
    if (_samples.isEmpty) return false;
    final start = _saturatingSub(currentTimeMs, durationMs);
    final relevant = _samples.where((s) => s.timestampMs >= start).toList();
    if (relevant.isEmpty || relevant.first.timestampMs > start + 1000) {
      return false;
    }
    final base = relevant.first.headingDeg;
    for (final s in relevant) {
      if (headingDelta(base, s.headingDeg).abs() > toleranceDeg) return false;
    }
    return true;
  }
}

int _saturatingSub(int a, int b) => a > b ? a - b : 0;
