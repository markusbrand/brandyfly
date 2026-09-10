import 'package:flutter/material.dart';
import '../../models/flight_model.dart';

/// A [CustomPainter] that renders a 2D track overview of flight GPS points.
class MiniTrackPainter extends CustomPainter {
  const MiniTrackPainter(this.points);

  final List<FlightPoint> points;

  // ⚡ Bolt: Cache Paint objects statically to avoid per-frame allocations without breaking const constructor
  static final Paint _trackPaint = Paint()
    ..color = Colors.cyanAccent
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLon = points.first.longitude;
    var maxLon = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLon) minLon = p.longitude;
      if (p.longitude > maxLon) maxLon = p.longitude;
    }

    final latSpan = (maxLat - minLat).clamp(0.0001, 100.0);
    final lonSpan = (maxLon - minLon).clamp(0.0001, 100.0);

    final path = Path();

    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final x = 20.0 + ((p.longitude - minLon) / lonSpan) * (size.width - 40.0);
      final y =
          size.height -
          20.0 -
          (((p.latitude - minLat) / latSpan) * (size.height - 40.0));

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, _trackPaint);
  }

  @override
  bool shouldRepaint(covariant MiniTrackPainter oldDelegate) =>
      oldDelegate.points != points;
}
