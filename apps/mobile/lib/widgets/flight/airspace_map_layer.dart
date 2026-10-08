import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../services/airspace_service.dart';

/// Tactical map overlay rendering airspace vector boundaries, class labels,
/// and active proximity alert highlights.
class AirspaceMapLayer extends StatelessWidget {
  const AirspaceMapLayer({
    super.key,
    required this.airspaces,
    required this.centerLat,
    required this.centerLon,
    required this.zoom,
    this.activeAlertLevel = AirspaceAlertLevel.clear,
    this.highlightedAirspaceId,
  });

  final List<AirspaceModel> airspaces;
  final double centerLat;
  final double centerLon;
  final double zoom;
  final AirspaceAlertLevel activeAlertLevel;
  final String? highlightedAirspaceId;

  @override
  Widget build(BuildContext context) {
    if (airspaces.isEmpty) {
      return const SizedBox.shrink();
    }

    return RepaintBoundary(
      child: CustomPaint(
        painter: AirspaceMapPainter(
          airspaces: airspaces,
          centerLat: centerLat,
          centerLon: centerLon,
          zoom: zoom,
          activeAlertLevel: activeAlertLevel,
          highlightedAirspaceId: highlightedAirspaceId,
        ),
      ),
    );
  }
}

/// Custom painter for rendering vector airspace polygons onto a map canvas.
class AirspaceMapPainter extends CustomPainter {
  AirspaceMapPainter({
    required this.airspaces,
    required this.centerLat,
    required this.centerLon,
    required this.zoom,
    required this.activeAlertLevel,
    this.highlightedAirspaceId,
  });

  final List<AirspaceModel> airspaces;
  final double centerLat;
  final double centerLon;
  final double zoom;
  final AirspaceAlertLevel activeAlertLevel;
  final String? highlightedAirspaceId;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0 || airspaces.isEmpty) return;

    final centerPix = _latLonToPixels(centerLat, centerLon, zoom);
    final originPix = Offset(
      centerPix.dx - size.width / 2.0,
      centerPix.dy - size.height / 2.0,
    );

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (final airspace in airspaces) {
      if (airspace.polygon.length < 3) continue;

      final isHighlighted = highlightedAirspaceId == airspace.id ||
          (activeAlertLevel.severity >= 2 &&
              airspace.name.contains(highlightedAirspaceId ?? ''));

      final color = _getAirspaceColor(airspace.airspaceClass, isHighlighted);

      final path = Path();
      var first = true;
      var sumX = 0.0;
      var sumY = 0.0;

      for (final pt in airspace.polygon) {
        final pix = _latLonToPixels(pt.lat, pt.lon, zoom);
        final sx = pix.dx - originPix.dx;
        final sy = pix.dy - originPix.dy;

        sumX += sx;
        sumY += sy;

        if (first) {
          path.moveTo(sx, sy);
          first = false;
        } else {
          path.lineTo(sx, sy);
        }
      }
      path.close();

      // Draw semi-transparent polygon fill
      final fillPaint = Paint()
        ..color = color.withValues(alpha: isHighlighted ? 0.35 : 0.12)
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, fillPaint);

      // Draw outline stroke
      final strokePaint = Paint()
        ..color = isHighlighted ? Colors.redAccent : color
        ..style = PaintingStyle.stroke
        ..strokeWidth = isHighlighted ? 2.5 : 1.2;
      canvas.drawPath(path, strokePaint);

      // Label at polygon centroid
      final count = airspace.polygon.length.toDouble();
      final centroidX = sumX / count;
      final centroidY = sumY / count;

      if (centroidX >= 0 &&
          centroidX <= size.width &&
          centroidY >= 0 &&
          centroidY <= size.height) {
        textPainter.text = TextSpan(
          text: '${airspace.name}\n[${airspace.airspaceClass}]',
          style: TextStyle(
            color: isHighlighted ? Colors.white : color,
            fontSize: 9,
            fontWeight: FontWeight.bold,
            shadows: const [
              Shadow(
                color: Colors.black,
                blurRadius: 3.0,
              ),
            ],
          ),
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(
            centroidX - textPainter.width / 2.0,
            centroidY - textPainter.height / 2.0,
          ),
        );
      }
    }
  }

  static Offset _latLonToPixels(double lat, double lon, double zoom) {
    final scale = 256.0 * math.pow(2.0, zoom);
    final x = (lon + 180.0) / 360.0 * scale;

    final latRad = lat.clamp(-85.0511, 85.0511) * math.pi / 180.0;
    final y = (1.0 -
            math.log(math.tan(latRad) + 1.0 / math.cos(latRad)) / math.pi) /
        2.0 *
        scale;

    return Offset(x, y);
  }

  static Color _getAirspaceColor(String cls, bool isHighlighted) {
    if (isHighlighted) return Colors.redAccent;
    switch (cls.toUpperCase()) {
      case 'CTR':
        return Colors.cyan;
      case 'R':
      case 'RESTRICTED':
        return Colors.orangeAccent;
      case 'P':
      case 'PROHIBITED':
        return Colors.red;
      case 'Q':
      case 'D':
      case 'DANGER':
        return Colors.amber;
      case 'GP':
      case 'GLIDER':
        return Colors.greenAccent;
      case 'TMZ':
      case 'RMZ':
        return Colors.purpleAccent;
      default:
        return Colors.lightBlueAccent;
    }
  }

  @override
  bool shouldRepaint(covariant AirspaceMapPainter oldDelegate) {
    return oldDelegate.airspaces != airspaces ||
        oldDelegate.centerLat != centerLat ||
        oldDelegate.centerLon != centerLon ||
        oldDelegate.zoom != zoom ||
        oldDelegate.activeAlertLevel != activeAlertLevel ||
        oldDelegate.highlightedAirspaceId != highlightedAirspaceId;
  }
}
