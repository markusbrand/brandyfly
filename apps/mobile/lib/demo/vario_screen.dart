import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

/// A single snapshot of flight instrument readings.
class FlightSnapshot {
  const FlightSnapshot({
    required this.altitudeM,
    required this.varioMs,
    required this.speedKmh,
    required this.glideRatio,
    required this.altitudeHistory,
  });

  final double altitudeM;
  final double varioMs;
  final double speedKmh;
  final double? glideRatio;
  final List<double> altitudeHistory;
}

/// Emits [FlightSnapshot]s for the demo UI.
class MockFlightDataService {
  MockFlightDataService({
    this.tickInterval = const Duration(milliseconds: 100),
  });

  final Duration tickInterval;

  static const List<(int, double, double)> _profile = [
    (0, 1200, 0),
    (5000, 1800, 2.8),
    (8000, 1900, 0.4),
    (12000, 1500, -1.5),
    (16000, 1600, 1.2),
    (20000, 1550, -0.3),
    (25000, 1100, -2.2),
    (28000, 850, -3.0),
    (30000, 1200, 0),
  ];

  final _controller = StreamController<FlightSnapshot>.broadcast();
  Timer? _timer;
  int _tickMs = 0;
  final _history = <double>[];

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
    final rng = Random();
    final noisyAlt = alt + (rng.nextDouble() - 0.5) * 2;
    final noisyVario = vario + (rng.nextDouble() - 0.5) * 0.15;
    final noisySpeed = speed + (rng.nextDouble() - 0.5) * 1.5;

    _history.add(noisyAlt);
    if (_history.length > 60) {
      _history.removeAt(0);
    }

    final glide = noisyVario.abs() > 0.1 && noisyVario < 0
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
        final speed = 38.0 + vario.abs() * 3.0;
        return (alt, vario, speed);
      }
    }
    return (_profile.last.$2, _profile.last.$3, 38.0);
  }
}

class VarioScreen extends StatelessWidget {
  const VarioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0D0D1A),
      body: SafeArea(
        child: Padding(padding: EdgeInsets.all(20), child: _VarioShell()),
      ),
    );
  }
}

class VarioDemoCard extends StatelessWidget {
  const VarioDemoCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        color: Color(0xFF0D0D1A),
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: _VarioShell(compact: true),
      ),
    );
  }
}

class _VarioShell extends StatefulWidget {
  const _VarioShell({this.compact = false});

  final bool compact;

  @override
  State<_VarioShell> createState() => _VarioShellState();
}

class _VarioShellState extends State<_VarioShell> {
  final MockFlightDataService _service = MockFlightDataService();
  late final StreamSubscription<FlightSnapshot> _subscription;
  FlightSnapshot? _snapshot;

  @override
  void initState() {
    super.initState();
    _service.start();
    _subscription = _service.snapshots.listen((snapshot) {
      if (mounted) {
        setState(() => _snapshot = snapshot);
      }
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    if (snapshot == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return VarioDashboard(snapshot: snapshot, compact: widget.compact);
  }
}

class VarioDashboard extends StatelessWidget {
  const VarioDashboard({
    super.key,
    required this.snapshot,
    this.compact = false,
  });

  final FlightSnapshot snapshot;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final s = snapshot;
    return Column(
      children: [
        _TopBar(altitudeM: s.altitudeM, compact: compact),
        SizedBox(height: compact ? 4 : 8),
        Expanded(child: _VarioGauge(varioMs: s.varioMs)),
        SizedBox(height: compact ? 4 : 8),
        _BottomStats(
          speedKmh: s.speedKmh,
          glideRatio: s.glideRatio,
          compact: compact,
        ),
        SizedBox(height: compact ? 8 : 12),
        _AltitudeSparkline(history: s.altitudeHistory),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.altitudeM, required this.compact});

  final double altitudeM;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'BrandyFly',
          style: TextStyle(
            color: const Color(0xFF7B8CDE),
            fontSize: compact ? 14 : 16,
            letterSpacing: 2,
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${altitudeM.toStringAsFixed(0)} m',
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 24 : 28,
                fontWeight: FontWeight.w300,
                letterSpacing: 1,
              ),
            ),
            const Text(
              'MSL',
              style: TextStyle(color: Color(0xFF7B8CDE), fontSize: 11),
            ),
          ],
        ),
      ],
    );
  }
}

class _VarioGauge extends StatelessWidget {
  const _VarioGauge({required this.varioMs});

  final double varioMs;

  static const double _maxMs = 5.0;

  Color get _color {
    if (varioMs > 0.2) return const Color(0xFF4CAF7D);
    if (varioMs < -0.2) return const Color(0xFFE05C5C);
    return const Color(0xFFBDBDBD);
  }

  @override
  Widget build(BuildContext context) {
    final clampedFrac = (varioMs / _maxMs).clamp(-1.0, 1.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = min(constraints.maxWidth, constraints.maxHeight);
        return Center(
          child: SizedBox.square(
            dimension: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: Size.square(size),
                  painter: _GaugePainter(fraction: clampedFrac, color: _color),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      varioMs >= 0
                          ? '+${varioMs.toStringAsFixed(1)}'
                          : varioMs.toStringAsFixed(1),
                      style: TextStyle(
                        color: _color,
                        fontSize: size * 0.2,
                        fontWeight: FontWeight.w200,
                        letterSpacing: -2,
                      ),
                    ),
                    Text(
                      'm/s',
                      style: TextStyle(
                        color: _color.withAlpha(180),
                        fontSize: size * 0.07,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({required this.fraction, required this.color})
      : _bgPaint = Paint()
          ..color = const Color(0xFF1A1A2E)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 16,
        _arcPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 16
          ..strokeCap = StrokeCap.round,
        _tickPaint = Paint()
          ..color = const Color(0xFF3A3A5C)
          ..strokeWidth = 1.5;

  final double fraction;
  final Color color;

  // Cached Paint objects for performance (Bolt optimization)
  final Paint _bgPaint;
  final Paint _arcPaint;
  final Paint _tickPaint;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    canvas.drawCircle(
      center,
      radius,
      _bgPaint,
    );

    const startAngle = pi * 0.75;
    const fullSweep = pi * 1.5;
    final arcSweep = fullSweep * fraction.abs() * (fraction >= 0 ? 1 : -1);
    final arcStart = fraction >= 0
        ? startAngle + fullSweep / 2
        : startAngle + fullSweep / 2 + arcSweep;

    _arcPaint.color = color;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      arcStart,
      arcSweep.abs(),
      false,
      _arcPaint,
    );

    for (int i = 0; i <= 10; i++) {
      final angle = startAngle + fullSweep * i / 10;
      final inner = center + Offset(cos(angle), sin(angle)) * (radius - 12);
      final outer = center + Offset(cos(angle), sin(angle)) * (radius + 2);
      canvas.drawLine(inner, outer, _tickPaint);
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.fraction != fraction || old.color != color;
}

class _BottomStats extends StatelessWidget {
  const _BottomStats({
    required this.speedKmh,
    required this.glideRatio,
    required this.compact,
  });

  final double speedKmh;
  final double? glideRatio;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _StatTile(
          label: 'GND SPD',
          value: '${speedKmh.toStringAsFixed(0)} km/h',
          compact: compact,
        ),
        _StatTile(
          label: 'GLIDE',
          value: glideRatio != null ? glideRatio!.toStringAsFixed(1) : '—',
          compact: compact,
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.compact,
  });

  final String label;
  final String value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF7B8CDE),
            fontSize: 11,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: compact ? 18 : 22,
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }
}

class _AltitudeSparkline extends StatelessWidget {
  const _AltitudeSparkline({required this.history});

  final List<double> history;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: history.length < 2
          ? const SizedBox.shrink()
          : CustomPaint(
              size: const Size(double.infinity, 48),
              painter: _SparklinePainter(history),
            ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter(this.values)
      : _linePaint = Paint()
          ..color = const Color(0xFF7B8CDE)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;

  final List<double> values;

  // Cached Paint object for performance (Bolt optimization)
  final Paint _linePaint;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    double minValue = values[0];
    double maxValue = values[0];
    for (int i = 1; i < values.length; i++) {
      final val = values[i];
      if (val < minValue) minValue = val;
      if (val > maxValue) maxValue = val;
    }
    final range = (maxValue - minValue).abs().clamp(1.0, double.infinity);

    final path = Path();
    for (int i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y = size.height - size.height * (values[i] - minValue) / range;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, _linePaint);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) => old.values != values;
}
