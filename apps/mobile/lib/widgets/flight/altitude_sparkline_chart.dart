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
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ALTITUDE HISTORY (SPARKLINE)',
            style: TextStyle(color: Colors.white54, fontSize: 10),
          ),
          const SizedBox(height: 8),
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
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade900,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.cyan.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ALTITUDE PROFILE (AREA)',
            style: TextStyle(
              color: Colors.cyanAccent,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
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
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.greenAccent.shade400),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ALTITUDE / TIME GRID',
            style: TextStyle(
              color: Colors.greenAccent.shade400,
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 8),
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
  })  : _gridPaint = Paint()
          ..color = Colors.white.withAlpha(25)
          ..strokeWidth = 1,
        _fillPaint = Paint()
          ..style = PaintingStyle.fill,
        _linePaint = Paint()
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;

  final List<double> history;
  final Color lineColor;
  final bool isFilled;
  final bool drawGrid;

  // Cached Paint objects to avoid allocations per frame (Bolt optimization)
  final Paint _gridPaint;
  final Paint _fillPaint;
  final Paint _linePaint;

  @override
  void paint(Canvas canvas, Size size) {
    if (history.isEmpty) return;

    if (drawGrid) {
      for (double x = 0; x < size.width; x += size.width / 5) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), _gridPaint);
      }
      for (double y = 0; y < size.height; y += size.height / 3) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), _gridPaint);
      }
    }

    _fillPaint.color = lineColor.withAlpha(60);
    _linePaint.color = lineColor;

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
      canvas.drawPath(fillPath, _fillPaint);
    }

    canvas.drawPath(path, _linePaint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.history != history ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.isFilled != isFilled ||
        oldDelegate.drawGrid != drawGrid;
  }
}
