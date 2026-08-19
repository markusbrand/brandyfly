import 'package:flutter/material.dart';
import '../../models/ui_config.dart';

class AltitudeSparklineChart extends StatelessWidget {
  const AltitudeSparklineChart({
    super.key,
    required this.history,
    required this.style,
  });

  final List<double> history;
  final AltitudeChartStyle style;

  @override
  Widget build(BuildContext context) {
    switch (style) {
      case AltitudeChartStyle.minimalSparkline:
        return _buildMinimalSparkline(context);
      case AltitudeChartStyle.filledAreaGraph:
        return _buildFilledAreaGraph(context);
      case AltitudeChartStyle.detailedGrid:
        return _buildDetailedGrid(context);
    }
  }

  // Option 1: Minimal Sparkline
  Widget _buildMinimalSparkline(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'ALTITUDE HISTORY (SPARKLINE)',
            style: TextStyle(color: Colors.white54, fontSize: 9),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: CustomPaint(
              painter: _SparklinePainter(
                history: history,
                lineColor: Colors.cyanAccent,
                isFilled: false,
                drawGrid: false,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Option 2: Filled Area Graph
  Widget _buildFilledAreaGraph(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade900,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.cyan.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'ALTITUDE PROFILE (AREA)',
            style: TextStyle(
              color: Colors.cyanAccent,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: CustomPaint(
              painter: _SparklinePainter(
                history: history,
                lineColor: Colors.blueAccent,
                isFilled: true,
                drawGrid: false,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Option 3: Detailed Grid
  Widget _buildDetailedGrid(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.greenAccent.shade400),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'ALTITUDE / TIME GRID',
            style: TextStyle(
              color: Colors.greenAccent.shade400,
              fontSize: 9,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: CustomPaint(
              painter: _SparklinePainter(
                history: history,
                lineColor: Colors.greenAccent,
                isFilled: false,
                drawGrid: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.history,
    required this.lineColor,
    required this.isFilled,
    required this.drawGrid,
  });

  final List<double> history;
  final Color lineColor;
  final bool isFilled;
  final bool drawGrid;

  @override
  void paint(Canvas canvas, Size size) {
    if (history.isEmpty) return;

    if (drawGrid) {
      final gridPaint = Paint()
        ..color = Colors.white.withAlpha(25)
        ..strokeWidth = 1;
      for (double x = 0; x < size.width; x += size.width / 5) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      }
      for (double y = 0; y < size.height; y += size.height / 3) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      }
    }

    double minVal = history[0];
    double maxVal = history[0];
    for (int i = 1; i < history.length; i++) {
      final val = history[i];
      if (val < minVal) minVal = val;
      if (val > maxVal) maxVal = val;
    }
    final range = (maxVal - minVal) == 0 ? 1.0 : (maxVal - minVal);

    final path = Path();
    final stepX = size.width / (history.length - 1);

    for (int i = 0; i < history.length; i++) {
      final normY = (history[i] - minVal) / range;
      final x = i * stepX;
      final y = size.height - (normY * (size.height - 10) + 5);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    if (isFilled) {
      final fillPath = Path.from(path)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      final fillPaint = Paint()
        ..color = lineColor.withAlpha(60)
        ..style = PaintingStyle.fill;
      canvas.drawPath(fillPath, fillPaint);
    }

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.history != history ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.isFilled != isFilled ||
        oldDelegate.drawGrid != drawGrid;
  }
}
