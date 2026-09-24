import 'package:flutter/foundation.dart';
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
    return Semantics(
      label: 'Altitude history profile chart',
      readOnly: true,
      child: _buildStyledChart(context),
    );
  }

  Widget _buildStyledChart(BuildContext context) {
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
    return SizedBox.expand(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(160),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white24, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'ALTITUDE HISTORY (SPARKLINE)',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 8.5,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
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
      ),
    );
  }

  // Option 2: Filled Area Graph
  Widget _buildFilledAreaGraph(BuildContext context) {
    return SizedBox.expand(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.blueGrey.shade900,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.cyan.withAlpha(80), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'ALTITUDE PROFILE (AREA)',
              style: TextStyle(
                color: Colors.cyanAccent,
                fontSize: 8.5,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
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
      ),
    );
  }

  // Option 3: Detailed Grid
  Widget _buildDetailedGrid(BuildContext context) {
    return SizedBox.expand(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.greenAccent.shade400, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'ALTITUDE / TIME GRID',
              style: TextStyle(
                color: Colors.greenAccent.shade400,
                fontSize: 8.5,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
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
  }) : bounds = _calcBounds(history);

  final List<double> history;
  final Color lineColor;
  final bool isFilled;
  final bool drawGrid;

  final ({double minVal, double range}) bounds;

  static ({double minVal, double range}) _calcBounds(List<double> history) {
    if (history.isEmpty) return (minVal: 0.0, range: 1.0);
    double min = history[0];
    double max = history[0];
    for (int i = 1; i < history.length; i++) {
      final val = history[i];
      if (val < min) min = val;
      if (val > max) max = val;
    }
    final diff = max - min;
    return (minVal: min, range: diff == 0 ? 1.0 : diff);
  }

  // ⚡ Bolt: Cache Paint objects to avoid per-frame GC allocations
  final Paint _gridPaint = Paint()..strokeWidth = 1;
  final Paint _fillPaint = Paint()..style = PaintingStyle.fill;
  final Paint _linePaint = Paint()
    ..strokeWidth = 2
    ..style = PaintingStyle.stroke;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    if (history.isEmpty) return;

    if (drawGrid) {
      _gridPaint.color = Colors.white.withAlpha(25);
      for (double x = 0; x < size.width; x += size.width / 5) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), _gridPaint);
      }
      for (double y = 0; y < size.height; y += size.height / 3) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), _gridPaint);
      }
    }

    final path = Path();
    if (history.length == 1) {
      final y = size.height / 2;
      path.moveTo(0, y);
      path.lineTo(size.width, y);
    } else {
      // ⚡ Bolt: Factor out loop-invariant scaling calculations to avoid redundant O(N) re-computations inside paint loop
      final stepX = size.width / (history.length - 1);
      final scaleY = (size.height - 10) / bounds.range;
      final base = size.height - 5;
      for (int i = 0; i < history.length; i++) {
        final x = i * stepX;
        final y = base - (history[i] - bounds.minVal) * scaleY;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
    }

    if (isFilled) {
      final fillPath = Path.from(path)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      _fillPaint.color = lineColor.withAlpha(60);
      canvas.drawPath(fillPath, _fillPaint);
    }

    _linePaint.color = lineColor;
    canvas.drawPath(path, _linePaint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return !listEquals(oldDelegate.history, history) ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.isFilled != isFilled ||
        oldDelegate.drawGrid != drawGrid;
  }
}
