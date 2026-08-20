import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/ui_config.dart';

/// Paragliding Map Widget with offline Alpine topo contours,
/// airspace polygons, thermal overlays, breadcrumb tracks, and pilot position.
class MapWidget extends StatefulWidget {
  const MapWidget({
    super.key,
    this.style = MapWidgetStyle.topoContours,
    this.orientation = MapOrientation.trackUp,
    this.showAirspace = true,
    this.showThermals = true,
    this.showTrack = true,
    this.showContours = true,
    this.altitudeM = 1450.0,
    this.speedKmh = 42.5,
    this.climbRateMs = 1.8,
    this.headingDeg = 220.0,
    this.altitudeHistory = const [],
    this.onZoomIn,
    this.onZoomOut,
  });

  final MapWidgetStyle style;
  final MapOrientation orientation;
  final bool showAirspace;
  final bool showThermals;
  final bool showTrack;
  final bool showContours;
  final double altitudeM;
  final double speedKmh;
  final double climbRateMs;
  final double headingDeg;
  final List<double> altitudeHistory;
  final VoidCallback? onZoomIn;
  final VoidCallback? onZoomOut;

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  double _zoomLevel = 1.0;
  Offset _panOffset = Offset.zero;
  bool _centerOnPilot = true;

  void _handleZoom(double delta) {
    setState(() {
      _zoomLevel = (_zoomLevel + delta).clamp(0.5, 3.0);
    });
    if (delta > 0) {
      widget.onZoomIn?.call();
    } else {
      widget.onZoomOut?.call();
    }
  }

  void _recenter() {
    setState(() {
      _panOffset = Offset.zero;
      _centerOnPilot = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        children: [
          // Interactive Pan & Zoom Custom Paint Canvas
          Positioned.fill(
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  _panOffset += details.delta;
                  _centerOnPilot = false;
                });
              },
              child: CustomPaint(
                painter: _MapTerrainPainter(
                  style: widget.style,
                  orientation: widget.orientation,
                  zoomLevel: _zoomLevel,
                  panOffset: _panOffset,
                  showAirspace: widget.showAirspace,
                  showThermals: widget.showThermals,
                  showTrack: widget.showTrack,
                  showContours: widget.showContours,
                  altitudeM: widget.altitudeM,
                  speedKmh: widget.speedKmh,
                  climbRateMs: widget.climbRateMs,
                  headingDeg: widget.headingDeg,
                  altitudeHistory: widget.altitudeHistory,
                ),
              ),
            ),
          ),

          // Map Header Badge
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(180),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.cyanAccent.withAlpha(100), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.map_outlined, size: 12, color: Colors.cyanAccent),
                  const SizedBox(width: 4),
                  Text(
                    _getStyleTitle(widget.style),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // North / Orientation Compass Widget
          Positioned(
            top: 8,
            right: 8,
            child: _buildCompassIndicator(),
          ),

          // Quick Action Layer & Zoom Controls Toolbar
          Positioned(
            bottom: 8,
            right: 8,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _mapActionButton(
                  key: const Key('btn_map_recenter'),
                  icon: Icons.my_location,
                  tooltip: 'Center Pilot',
                  active: _centerOnPilot,
                  onPressed: _recenter,
                ),
                const SizedBox(height: 4),
                _mapActionButton(
                  key: const Key('btn_map_zoom_in'),
                  icon: Icons.add,
                  tooltip: 'Zoom In',
                  onPressed: () => _handleZoom(0.25),
                ),
                const SizedBox(height: 4),
                _mapActionButton(
                  key: const Key('btn_map_zoom_out'),
                  icon: Icons.remove,
                  tooltip: 'Zoom Out',
                  onPressed: () => _handleZoom(-0.25),
                ),
              ],
            ),
          ),

          // Map Scale Bar & Altitude Legend
          Positioned(
            bottom: 8,
            left: 8,
            child: _buildScaleAndLegend(),
          ),
        ],
      ),
    );
  }

  String _getStyleTitle(MapWidgetStyle style) {
    switch (style) {
      case MapWidgetStyle.topoContours:
        return 'ALPINE TOPO 1:50k (OFFLINE)';
      case MapWidgetStyle.minimalVector:
        return 'VECTOR HUD (OFFLINE)';
      case MapWidgetStyle.thermalHeatmap:
        return 'THERMAL RADAR (OFFLINE)';
      case MapWidgetStyle.satelliteTerrain:
        return 'RELIEF SHADED (OFFLINE)';
    }
  }

  Widget _buildCompassIndicator() {
    final rotation = widget.orientation == MapOrientation.trackUp
        ? -widget.headingDeg * math.pi / 180
        : 0.0;

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(180),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: Transform.rotate(
        angle: rotation,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'N',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Icon(Icons.arrow_upward, size: 12, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScaleAndLegend() {
    final scaleKm = (1.0 / _zoomLevel).clamp(0.2, 5.0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(160),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 35,
                height: 2,
                color: Colors.white70,
              ),
              const SizedBox(width: 4),
              Text(
                '${scaleKm.toStringAsFixed(1)} km',
                style: const TextStyle(color: Colors.white70, fontSize: 9),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'ALT: ${widget.altitudeM.toStringAsFixed(0)}m  SPD: ${widget.speedKmh.toStringAsFixed(0)}km/h',
            style: const TextStyle(
              color: Colors.cyanAccent,
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapActionButton({
    required Key key,
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    bool active = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        key: key,
        onTap: onPressed,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: active ? Colors.cyan.shade800 : Colors.black.withAlpha(200),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: active ? Colors.cyanAccent : Colors.white24,
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            size: 16,
            color: active ? Colors.white : Colors.white70,
          ),
        ),
      ),
    );
  }
}

class _MapTerrainPainter extends CustomPainter {
  _MapTerrainPainter({
    required this.style,
    required this.orientation,
    required this.zoomLevel,
    required this.panOffset,
    required this.showAirspace,
    required this.showThermals,
    required this.showTrack,
    required this.showContours,
    required this.altitudeM,
    required this.speedKmh,
    required this.climbRateMs,
    required this.headingDeg,
    required this.altitudeHistory,
  });

  final MapWidgetStyle style;
  final MapOrientation orientation;
  final double zoomLevel;
  final Offset panOffset;
  final bool showAirspace;
  final bool showThermals;
  final bool showTrack;
  final bool showContours;
  final double altitudeM;
  final double speedKmh;
  final double climbRateMs;
  final double headingDeg;
  final List<double> altitudeHistory;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    canvas.save();
    canvas.clipRect(Offset.zero & size);

    canvas.translate(center.dx + panOffset.dx, center.dy + panOffset.dy);
    canvas.scale(zoomLevel);
    if (orientation == MapOrientation.trackUp) {
      canvas.rotate(-headingDeg * math.pi / 180);
    }
    canvas.translate(-center.dx, -center.dy);

    // 1. Base terrain background
    _drawTerrainBackground(canvas, size, center);

    // 2. Topographic contour lines & elevation heights
    if (showContours) {
      _drawContourLines(canvas, size, center);
    }

    // 3. Mountain peaks & waypoints
    _drawPeaksAndWaypoints(canvas, size, center);

    // 4. Airspace polygons
    if (showAirspace) {
      _drawAirspaces(canvas, size, center);
    }

    // 5. Thermal updraft hotspots
    if (showThermals) {
      _drawThermals(canvas, size, center);
    }

    // 6. Flight Trail / Track polyline
    if (showTrack) {
      _drawFlightTrack(canvas, size, center);
    }

    // 7. Paraglider Pilot Marker
    _drawPilotMarker(canvas, size, center);

    canvas.restore();
  }

  void _drawTerrainBackground(Canvas canvas, Size size, Offset center) {
    final bgPaint = Paint();

    switch (style) {
      case MapWidgetStyle.topoContours:
        bgPaint.shader = RadialGradient(
          center: Alignment.center,
          radius: 1.2,
          colors: [
            const Color(0xFF1E293B),
            const Color(0xFF0F172A),
            const Color(0xFF020617),
          ],
        ).createShader(Offset.zero & size);
        break;
      case MapWidgetStyle.minimalVector:
        bgPaint.color = const Color(0xFF0A0F1D);
        break;
      case MapWidgetStyle.thermalHeatmap:
        bgPaint.color = const Color(0xFF0D1117);
        break;
      case MapWidgetStyle.satelliteTerrain:
        bgPaint.shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2A3439),
            const Color(0xFF1B2327),
            const Color(0xFF0F1416),
          ],
        ).createShader(Offset.zero & size);
        break;
    }

    canvas.drawRect(
      Rect.fromCenter(
        center: center,
        width: size.width * 4,
        height: size.height * 4,
      ),
      bgPaint,
    );
  }

  void _drawContourLines(Canvas canvas, Size size, Offset center) {
    final contourPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final primaryContourPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    switch (style) {
      case MapWidgetStyle.topoContours:
        contourPaint.color = const Color(0xFFD97706).withAlpha(100);
        primaryContourPaint.color = const Color(0xFFF59E0B).withAlpha(180);
        break;
      case MapWidgetStyle.minimalVector:
        contourPaint.color = Colors.cyanAccent.withAlpha(60);
        primaryContourPaint.color = Colors.cyanAccent.withAlpha(140);
        break;
      case MapWidgetStyle.thermalHeatmap:
        contourPaint.color = Colors.blueGrey.withAlpha(40);
        primaryContourPaint.color = Colors.blueGrey.withAlpha(80);
        break;
      case MapWidgetStyle.satelliteTerrain:
        contourPaint.color = Colors.white24;
        primaryContourPaint.color = Colors.white38;
        break;
    }

    final radii = [60.0, 110.0, 160.0, 220.0, 290.0, 360.0];
    for (int i = 0; i < radii.length; i++) {
      final r = radii[i];
      final path = Path();
      final points = 24;
      for (int step = 0; step <= points; step++) {
        final angle = step * 2 * math.pi / points;
        final noise = math.sin(angle * 3 + i) * 12 + math.cos(angle * 5 + i * 2) * 8;
        final dist = r + noise;
        final x = center.dx + dist * math.cos(angle);
        final y = center.dy + dist * math.sin(angle) * 0.85;
        if (step == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();

      final isMajor = i % 2 == 1;
      canvas.drawPath(path, isMajor ? primaryContourPaint : contourPaint);
    }
  }

  void _drawPeaksAndWaypoints(Canvas canvas, Size size, Offset center) {
    final peaks = [
      (Offset(center.dx - 90, center.dy - 80), 'Hohe Salve 1828m'),
      (Offset(center.dx + 110, center.dy - 120), 'Kitzbuehel 1996m'),
      (Offset(center.dx + 80, center.dy + 100), 'Hahnenkamm 1712m'),
    ];

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (final peak in peaks) {
      final peakPath = Path();
      peakPath.moveTo(peak.$1.dx, peak.$1.dy - 6);
      peakPath.lineTo(peak.$1.dx - 5, peak.$1.dy + 4);
      peakPath.lineTo(peak.$1.dx + 5, peak.$1.dy + 4);
      peakPath.close();

      canvas.drawPath(
        peakPath,
        Paint()
          ..color = const Color(0xFFFBBF24)
          ..style = PaintingStyle.fill,
      );

      textPainter.text = TextSpan(
        text: peak.$2,
        style: const TextStyle(
          color: Color(0xFFFBBF24),
          fontSize: 8,
          fontWeight: FontWeight.w600,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(peak.$1.dx - textPainter.width / 2, peak.$1.dy + 6),
      );
    }
  }

  void _drawAirspaces(Canvas canvas, Size size, Offset center) {
    final airspacePath = Path();
    airspacePath.moveTo(center.dx - 140, center.dy - 180);
    airspacePath.lineTo(center.dx + 60, center.dy - 200);
    airspacePath.lineTo(center.dx + 40, center.dy - 90);
    airspacePath.lineTo(center.dx - 150, center.dy - 100);
    airspacePath.close();

    canvas.drawPath(
      airspacePath,
      Paint()
        ..color = const Color(0xFFEF4444).withAlpha(35)
        ..style = PaintingStyle.fill,
    );

    canvas.drawPath(
      airspacePath,
      Paint()
        ..color = const Color(0xFFEF4444).withAlpha(180)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'CTR INNSBRUCK [D] GND-FL120',
        style: TextStyle(
          color: Color(0xFFFCA5A5),
          fontSize: 8,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(canvas, Offset(center.dx - 130, center.dy - 140));
  }

  void _drawThermals(Canvas canvas, Size size, Offset center) {
    final thermals = [
      (Offset(center.dx - 45, center.dy + 35), '+2.8 m/s', 30.0),
      (Offset(center.dx + 65, center.dy - 30), '+3.4 m/s', 38.0),
      (Offset(center.dx - 10, center.dy - 90), '+1.9 m/s', 24.0),
    ];

    for (final th in thermals) {
      final pos = th.$1;
      final lift = th.$2;
      final radius = th.$3;

      final thermalGradient = RadialGradient(
        colors: [
          const Color(0xFFF97316).withAlpha(160),
          const Color(0xFFEA580C).withAlpha(60),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: pos, radius: radius));

      canvas.drawCircle(
        pos,
        radius,
        Paint()..shader = thermalGradient,
      );

      canvas.drawCircle(
        pos,
        3.5,
        Paint()..color = const Color(0xFFFACC15),
      );

      final tp = TextPainter(
        text: TextSpan(
          text: lift,
          style: const TextStyle(
            color: Color(0xFFFDBA74),
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy + 6));
    }
  }

  void _drawFlightTrack(Canvas canvas, Size size, Offset center) {
    final trackPoints = [
      Offset(center.dx - 120, center.dy + 110),
      Offset(center.dx - 80, center.dy + 85),
      Offset(center.dx - 50, center.dy + 50),
      Offset(center.dx - 40, center.dy + 30),
      Offset(center.dx - 15, center.dy + 15),
      center,
    ];

    final trackPath = Path();
    for (int i = 0; i < trackPoints.length; i++) {
      if (i == 0) {
        trackPath.moveTo(trackPoints[i].dx, trackPoints[i].dy);
      } else {
        trackPath.lineTo(trackPoints[i].dx, trackPoints[i].dy);
      }
    }

    canvas.drawPath(
      trackPath,
      Paint()
        ..color = Colors.black87
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final trailColor = climbRateMs >= 0.2
        ? const Color(0xFF22C55E)
        : (climbRateMs <= -0.2 ? const Color(0xFFEF4444) : const Color(0xFFEAB308));

    canvas.drawPath(
      trackPath,
      Paint()
        ..color = trailColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    for (final pt in trackPoints) {
      canvas.drawCircle(pt, 2.0, Paint()..color = Colors.white);
    }
  }

  void _drawPilotMarker(Canvas canvas, Size size, Offset center) {
    final pilotPath = Path();
    pilotPath.moveTo(center.dx, center.dy - 12);
    pilotPath.lineTo(center.dx - 9, center.dy + 9);
    pilotPath.lineTo(center.dx, center.dy + 4);
    pilotPath.lineTo(center.dx + 9, center.dy + 9);
    pilotPath.close();

    canvas.drawCircle(
      center,
      16,
      Paint()
        ..color = Colors.cyanAccent.withAlpha(50)
        ..style = PaintingStyle.fill,
    );

    canvas.drawPath(
      pilotPath,
      Paint()
        ..color = Colors.black87
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    canvas.drawPath(
      pilotPath,
      Paint()
        ..color = Colors.cyanAccent
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_MapTerrainPainter old) {
    return old.style != style ||
        old.orientation != orientation ||
        old.zoomLevel != zoomLevel ||
        old.panOffset != panOffset ||
        old.showAirspace != showAirspace ||
        old.showThermals != showThermals ||
        old.showTrack != showTrack ||
        old.showContours != showContours ||
        old.altitudeM != altitudeM ||
        old.speedKmh != speedKmh ||
        old.climbRateMs != climbRateMs ||
        old.headingDeg != headingDeg;
  }
}
