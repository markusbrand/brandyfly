import 'dart:collection';

class _ClimbSample {
  const _ClimbSample(this.timestampMs, this.climbRateMs);
  final int timestampMs;
  final double climbRateMs;
}

/// Rolling integrated climb rate averager.
///
/// Accumulates climb rate samples over time and computes the arithmetic mean
/// over a rolling window (typically 10s, 15s, 20s, or 30s). Gaps exceeding
/// [maxInterruptionGapMs] (5 s) clear the buffer to avoid calculating inaccurate
/// averages across telemetry drops.
class ClimbAverager {
  ClimbAverager({this.defaultWindow = const Duration(seconds: 20)});

  static const int maxInterruptionGapMs = 5000;
  static const int maxRetentionMs = 35000;

  final Duration defaultWindow;
  final Queue<_ClimbSample> _samples = Queue<_ClimbSample>();
  int? _lastTimestampMs;

  int get sampleCount => _samples.length;

  void addSample(int timestampMs, double climbRateMs) {
    if (_lastTimestampMs != null &&
        timestampMs - _lastTimestampMs! > maxInterruptionGapMs) {
      _samples.clear();
    }
    _lastTimestampMs = timestampMs;
    _samples.addLast(_ClimbSample(timestampMs, climbRateMs));

    final cutoff = timestampMs - maxRetentionMs;
    while (_samples.isNotEmpty && _samples.first.timestampMs < cutoff) {
      _samples.removeFirst();
    }
  }

  /// Calculates the average climb rate over [window] (or [defaultWindow]).
  /// Returns 0.0 when no samples exist.
  double calculateAverage([Duration? window]) {
    if (_samples.isEmpty) return 0.0;
    final win = window ?? defaultWindow;
    final nowMs = _samples.last.timestampMs;
    final cutoff = nowMs - win.inMilliseconds;

    double sum = 0.0;
    int count = 0;
    for (final s in _samples) {
      if (s.timestampMs >= cutoff) {
        sum += s.climbRateMs;
        count++;
      }
    }
    if (count == 0) return _samples.last.climbRateMs;
    return sum / count;
  }

  void reset() {
    _samples.clear();
    _lastTimestampMs = null;
  }
}
