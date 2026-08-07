import 'dart:math';
import 'package:flutter/material.dart';
import 'mock_flight_data_service.dart';

class VarioScreen extends StatefulWidget {
  const VarioScreen({super.key});

  @override
  State<VarioScreen> createState() => _VarioScreenState();
}

class _VarioScreenState extends State<VarioScreen> {
  final _service = MockFlightDataService();
  FlightSnapshot? _snapshot;

  @override
  void initState() {
    super.initState();
    _service.start();
    _service.snapshots.listen((s) {
      if (mounted) setState(() => _snapshot = s);
    });
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = _snapshot;
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: s == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _TopBar(altitudeM: s.altitudeM),
                    const SizedBox(height: 8),
                    Expanded(child: _VarioGauge(varioMs: s.varioMs)),
                    const SizedBox(height: 8),
                    _BottomStats(
                      speedKmh: s.speedKmh,
                      glideRatio: s.glideRatio,
                    ),
                    const SizedBox(height: 12),
                    _AltitudeSparkline(history: s.altitudeHistory),
                  ],
                ),
              ),
            ),
    );
  }
}

// ── Top bar: altitude ──────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.altitudeM});
  final double altitudeM;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'BrandyFly',
          style: TextStyle(color: Color(0xFF7B8CDE), fontSize: 16, letterSpacing: 2),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${altitudeM.toStringAsFixed(0)} m',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
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

// ── Central vario gauge ────────────────────────────────────────────────────

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
  _GaugePainter({required this.fraction, required this.color});
  final double fraction; // -1..1
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    // Background ring.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xFF1A1A2E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16,
    );

    // Arc from 7 o'clock (225°) sweeping 270° total.
    final startAngle = pi * 0.75; // 135° from right = 7 o'clock (going clockwise from right)
    final fullSweep = pi * 1.5; // 270°
    final arcSweep = fullSweep * fraction.abs() * (fraction >= 0 ? 1 : -1);
    final arcStart = fraction >= 0 ? startAngle + fullSweep / 2 : startAngle + fullSweep / 2 + arcSweep;

    final arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      arcStart,
      arcSweep.abs(),
      false,
      arcPaint,
    );

    // Tick marks.
    final tickPaint = Paint()
      ..color = const Color(0xFF3A3A5C)
      ..strokeWidth = 1.5;
    for (int i = 0; i <= 10; i++) {
      final angle = startAngle + fullSweep * i / 10;
      final inner = center + Offset(cos(angle), sin(angle)) * (radius - 12);
      final outer = center + Offset(cos(angle), sin(angle)) * (radius + 2);
      canvas.drawLine(inner, outer, tickPaint);
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.fraction != fraction || old.color != color;
}

// ── Bottom stat row ────────────────────────────────────────────────────────

class _BottomStats extends StatelessWidget {
  const _BottomStats({required this.speedKmh, required this.glideRatio});
  final double speedKmh;
  final double? glideRatio;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _StatTile(
          label: 'GND SPD',
          value: '${speedKmh.toStringAsFixed(0)} km/h',
        ),
        _StatTile(
          label: 'GLIDE',
          value: glideRatio != null ? glideRatio!.toStringAsFixed(1) : '—',
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});
  final String label;
  final String value;

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
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }
}

// ── Altitude sparkline ─────────────────────────────────────────────────────

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
  _SparklinePainter(this.values);
  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final range = (max - min).abs().clamp(1.0, double.infinity);

    final paint = Paint()
      ..color = const Color(0xFF7B8CDE)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    for (int i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y = size.height - size.height * (values[i] - min) / range;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) => old.values != values;
}
