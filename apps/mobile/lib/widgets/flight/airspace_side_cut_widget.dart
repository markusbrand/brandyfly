import 'package:flutter/material.dart';

import '../../services/airspace_service.dart';

/// Interactive vertical cross-section side-cut profile widget.
/// Renders terrain profile, forward intersecting airspace blocks, aircraft position,
/// and projected glide slope trajectory along current flight heading.
class AirspaceSideCutWidget extends StatelessWidget {
  const AirspaceSideCutWidget({
    super.key,
    required this.aircraftAltitudeMsl,
    required this.groundspeedMps,
    required this.headingDeg,
    this.glideRatio = 8.0,
    this.terrainElevationMsl = 600.0,
    this.forwardBlocks = const [],
    this.lookaheadDistanceM = 10000.0,
    this.maxAltitudeMsl = 3500.0,
    this.minAltitudeMsl = 0.0,
  });

  final double aircraftAltitudeMsl;
  final double groundspeedMps;
  final double headingDeg;
  final double glideRatio;
  final double terrainElevationMsl;
  final List<ForwardAirspaceBlock> forwardBlocks;
  final double lookaheadDistanceM;
  final double maxAltitudeMsl;
  final double minAltitudeMsl;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Airspace Side-Cut Profile View',
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: Colors.white12),
        ),
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            const SizedBox(height: 6.0),
            Expanded(
              child: CustomPaint(
                painter: AirspaceSideCutPainter(
                  aircraftAltitudeMsl: aircraftAltitudeMsl,
                  groundspeedMps: groundspeedMps,
                  headingDeg: headingDeg,
                  glideRatio: glideRatio,
                  terrainElevationMsl: terrainElevationMsl,
                  forwardBlocks: forwardBlocks,
                  lookaheadDistanceM: lookaheadDistanceM,
                  maxAltitudeMsl: maxAltitudeMsl,
                  minAltitudeMsl: minAltitudeMsl,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final hasPenetration = forwardBlocks.any((b) => b.willPenetrate);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.show_chart, size: 14, color: Colors.cyanAccent),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  'SIDE-CUT (${headingDeg.toStringAsFixed(0)}°)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasPenetration)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.redAccent, width: 0.8),
                ),
                child: const Text(
                  'PENETRATION',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            Text(
              'L/D ${glideRatio.toStringAsFixed(1)} | ${(lookaheadDistanceM / 1000).toStringAsFixed(0)}km',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 9,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Custom painter rendering the 2D vertical profile cross-section.
class AirspaceSideCutPainter extends CustomPainter {
  AirspaceSideCutPainter({
    required this.aircraftAltitudeMsl,
    required this.groundspeedMps,
    required this.headingDeg,
    required this.glideRatio,
    required this.terrainElevationMsl,
    required this.forwardBlocks,
    required this.lookaheadDistanceM,
    required this.maxAltitudeMsl,
    required this.minAltitudeMsl,
  });

  final double aircraftAltitudeMsl;
  final double groundspeedMps;
  final double headingDeg;
  final double glideRatio;
  final double terrainElevationMsl;
  final List<ForwardAirspaceBlock> forwardBlocks;
  final double lookaheadDistanceM;
  final double maxAltitudeMsl;
  final double minAltitudeMsl;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final altRange = (maxAltitudeMsl - minAltitudeMsl).clamp(500.0, 10000.0);
    double toScreenX(double distM) =>
        (distM / lookaheadDistanceM) * size.width;
    double toScreenY(double altM) =>
        size.height - ((altM - minAltitudeMsl) / altRange) * size.height;

    // 1. Grid lines and altitude labels
    _paintGrid(canvas, size, altRange, toScreenX, toScreenY);

    // 2. Airspace blocks along track
    _paintAirspaceBlocks(canvas, size, toScreenX, toScreenY);

    // 3. Terrain profile
    _paintTerrain(canvas, size, toScreenY);

    // 4. Glide slope trajectory
    _paintGlideSlope(canvas, size, toScreenX, toScreenY);

    // 5. Aircraft marker at x = 0
    _paintAircraft(canvas, size, toScreenY);
  }

  void _paintGrid(
    Canvas canvas,
    Size size,
    double altRange,
    double Function(double) toX,
    double Function(double) toY,
  ) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1.0;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // Altitude horizontal grid lines (every 500m or 1000m)
    final stepAlt = altRange > 3000 ? 1000.0 : 500.0;
    for (var alt = minAltitudeMsl; alt <= maxAltitudeMsl; alt += stepAlt) {
      final y = toY(alt);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);

      textPainter.text = TextSpan(
        text: '${alt.toInt()}m',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.35),
          fontSize: 9,
          fontFamily: 'monospace',
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(4, y - 11));
    }

    // Distance vertical grid lines (every 2.5 km or 5 km)
    final stepDist = lookaheadDistanceM >= 10000 ? 5000.0 : 2500.0;
    for (var d = stepDist; d <= lookaheadDistanceM; d += stepDist) {
      final x = toX(d);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);

      textPainter.text = TextSpan(
        text: '${(d / 1000).toStringAsFixed(1)}km',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.35),
          fontSize: 9,
          fontFamily: 'monospace',
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - 14, size.height - 12));
    }
  }

  void _paintTerrain(
    Canvas canvas,
    Size size,
    double Function(double) toY,
  ) {
    final groundY = toY(terrainElevationMsl).clamp(0.0, size.height);
    final terrainPaint = Paint()
      ..color = const Color(0xFF334155).withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, groundY)
      ..lineTo(size.width, groundY)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(path, terrainPaint);

    final groundLinePaint = Paint()
      ..color = const Color(0xFF64748B)
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(0, groundY), Offset(size.width, groundY), groundLinePaint);
  }

  void _paintAirspaceBlocks(
    Canvas canvas,
    Size size,
    double Function(double) toX,
    double Function(double) toY,
  ) {
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (final block in forwardBlocks) {
      final left = toX(block.entryDistanceM).clamp(0.0, size.width);
      final right = toX(block.exitDistanceM).clamp(0.0, size.width);
      if (right <= left) continue;

      final top = toY(block.ceilingMslM).clamp(0.0, size.height);
      final bottom = toY(block.floorMslM).clamp(0.0, size.height);

      final rect = Rect.fromLTRB(left, top, right, bottom);
      final color = _airspaceColor(block.airspace.airspaceClass);

      final fillPaint = Paint()
        ..color = color.withValues(alpha: block.willPenetrate ? 0.45 : 0.22)
        ..style = PaintingStyle.fill;
      canvas.drawRect(rect, fillPaint);

      final borderPaint = Paint()
        ..color = block.willPenetrate ? Colors.redAccent : color
        ..style = PaintingStyle.stroke
        ..strokeWidth = block.willPenetrate ? 2.0 : 1.2;
      canvas.drawRect(rect, borderPaint);

      // Label inside airspace block
      final label = '${block.airspace.name} [${block.airspace.airspaceClass}]';
      textPainter.text = TextSpan(
        text: label,
        style: TextStyle(
          color: block.willPenetrate ? Colors.redAccent : color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.layout(maxWidth: (right - left).clamp(20.0, size.width));
      if (rect.width > 25 && rect.height > 15) {
        textPainter.paint(canvas, Offset(left + 4, top + 4));
      }
    }
  }

  void _paintGlideSlope(
    Canvas canvas,
    Size size,
    double Function(double) toX,
    double Function(double) toY,
  ) {
    final startY = toY(aircraftAltitudeMsl);
    final endAlt = aircraftAltitudeMsl - (lookaheadDistanceM / glideRatio);
    final endY = toY(endAlt).clamp(0.0, size.height);

    final hasPenetration = forwardBlocks.any((b) => b.willPenetrate);

    final slopePaint = Paint()
      ..color = hasPenetration ? Colors.redAccent : Colors.greenAccent
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(0, startY), Offset(size.width, endY), slopePaint);

    // Projected glide slope trajectory dashed or dotted glow
    final glowPaint = Paint()
      ..color = (hasPenetration ? Colors.redAccent : Colors.greenAccent)
          .withValues(alpha: 0.3)
      ..strokeWidth = 6.0;
    canvas.drawLine(Offset(0, startY), Offset(size.width, endY), glowPaint);
  }

  void _paintAircraft(
    Canvas canvas,
    Size size,
    double Function(double) toY,
  ) {
    final cy = toY(aircraftAltitudeMsl).clamp(4.0, size.height - 4.0);
    const cx = 8.0;

    final dotPaint = Paint()
      ..color = Colors.cyanAccent
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), 5.0, dotPaint);

    final ringPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(Offset(cx, cy), 7.0, ringPaint);
  }

  static Color _airspaceColor(String cls) {
    switch (cls.toUpperCase()) {
      case 'CTR':
        return Colors.cyan;
      case 'R':
      case 'RESTRICTED':
        return Colors.orangeAccent;
      case 'P':
      case 'PROHIBITED':
        return Colors.redAccent;
      case 'Q':
      case 'D':
      case 'DANGER':
        return Colors.amber;
      case 'GP':
      case 'GLIDER':
        return Colors.lightGreenAccent;
      case 'TMZ':
      case 'RMZ':
        return Colors.purpleAccent;
      default:
        return Colors.blueAccent;
    }
  }

  @override
  bool shouldRepaint(covariant AirspaceSideCutPainter oldDelegate) {
    return oldDelegate.aircraftAltitudeMsl != aircraftAltitudeMsl ||
        oldDelegate.headingDeg != headingDeg ||
        oldDelegate.glideRatio != glideRatio ||
        oldDelegate.terrainElevationMsl != terrainElevationMsl ||
        oldDelegate.forwardBlocks != forwardBlocks;
  }
}
