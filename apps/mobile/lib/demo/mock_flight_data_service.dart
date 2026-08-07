import 'dart:async';
import 'dart:math';

/// A single snapshot of flight instrument readings.
class FlightSnapshot {
  const FlightSnapshot({
    required this.altitudeM,
    required this.varioMs,
    required this.speedKmh,
    required this.glideRatio,
    required this.altitudeHistory,
  });

  /// Altitude above mean sea level in metres.
  final double altitudeM;

  /// Vertical speed in m/s. Positive = climbing, negative = descending.
  final double varioMs;

  /// Ground speed in km/h.
  final double speedKmh;

  /// Instantaneous glide ratio (horizontal / vertical distance). Null when
  /// vertical speed is effectively zero.
  final double? glideRatio;

  /// Recent altitude samples (newest last) used for the sparkline.
  final List<double> altitudeHistory;
}

/// Emits [FlightSnapshot]s at [tickInterval] by replaying a synthetic
/// paragliding flight profile.  The profile loops so the demo runs forever.
class MockFlightDataService {
  MockFlightDataService({this.tickInterval = const Duration(milliseconds: 100)});

  final Duration tickInterval;

  // Profile: a sequence of (durationMs, targetAltM, targetVarioMs) waypoints.
  // The service interpolates linearly between them.
  static const List<(int, double, double)> _profile = [
    (0, 1200, 0),
    (5000, 1800, 2.8), // climb on a thermal
    (8000, 1900, 0.4), // topping out
    (12000, 1500, -1.5), // glide out
    (16000, 1600, 1.2), // weak thermal
    (20000, 1550, -0.3), // drift
    (25000, 1100, -2.2), // final glide
    (28000, 850, -3.0), // approach
    (30000, 1200, 0), // loop back to start
  ];

  final _controller = StreamController<FlightSnapshot>.broadcast();
  Timer? _timer;
  int _tickMs = 0;
  final _history = <double>[];
  static const int _historyLength = 60;

  Stream<FlightSnapshot> get snapshots => _controller.stream;

  void start() {
    _timer ??= Timer.periodic(tickInterval, (_) => _tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    stop();
    _controller.close();
  }

  void _tick() {
    final totalMs = _profile.last.$1;
    _tickMs = (_tickMs + tickInterval.inMilliseconds) % totalMs;

    final (alt, vario, speed) = _interpolate(_tickMs);

    // Add subtle sensor noise.
    final rng = Random();
    final noisyAlt = alt + (rng.nextDouble() - 0.5) * 2;
    final noisyVario = vario + (rng.nextDouble() - 0.5) * 0.15;
    final noisySpeed = speed + (rng.nextDouble() - 0.5) * 1.5;

    _history.add(noisyAlt);
    if (_history.length > _historyLength) _history.removeAt(0);

    final glide =
        noisyVario.abs() > 0.1 && noisyVario < 0
            ? noisySpeed / 3.6 / noisyVario.abs()
            : null;

    _controller.add(
      FlightSnapshot(
        altitudeM: noisyAlt,
        varioMs: noisyVario,
        speedKmh: noisySpeed,
        glideRatio: glide,
        altitudeHistory: List.unmodifiable(_history),
      ),
    );
  }

  (double alt, double vario, double speed) _interpolate(int ms) {
    for (int i = 1; i < _profile.length; i++) {
      final (t0, a0, v0) = _profile[i - 1];
      final (t1, a1, v1) = _profile[i];
      if (ms <= t1) {
        final frac = (ms - t0) / (t1 - t0);
        final alt = a0 + (a1 - a0) * frac;
        final vario = v0 + (v1 - v0) * frac;
        // Speed derived from vario magnitude + base glide speed.
        final speed = 38.0 + vario.abs() * 3.0;
        return (alt, vario, speed);
      }
    }
    return (_profile.last.$2, _profile.last.$3, 38.0);
  }
}
