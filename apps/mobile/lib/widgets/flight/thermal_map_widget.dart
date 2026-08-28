import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/ui_config.dart';

/// Data model representing a point along the thermaling track
class ThermalPoint {
  const ThermalPoint({
    required this.dx,
    required this.dy,
    required this.climbRateMs,
    required this.timestamp,
    this.altitudeM,
  });

  final double dx; // Offset in meters or relative canvas units from thermal origin
  final double dy;
  final double climbRateMs;
  final DateTime timestamp;
  final double? altitudeM;
}

/// Paragliding Thermal Map Widget.
///
/// Features green uplift circles (> 0 m/s) and red sink circles (< 0 m/s) with
/// dynamic alpha transparency scaling based on climb/sink intensity.
///
/// Supports 3 reference UI styles:
/// - Option 1: XCtrack Bubble Trail (dynamic radius & alpha decay)
/// - Option 2: Burnair Thermal Core Assist (bubbles + estimated core centroid & wind-drift vector)
/// - Option 3: Navigator Heat Ribbon (color-graded spline ribbon + turn stats badge)
class ThermalMapWidget extends StatefulWidget {
  const ThermalMapWidget({
    super.key,
    this.style = ThermalMapStyle.xctrackBubbles,
    this.showCore = true,
    this.historySeconds = 90,
    this.altitudeM = 1450.0,
    this.speedKmh = 38.5,
    this.climbRateMs = 2.4,
    this.headingDeg = 140.0,
    this.windDirDeg = 220.0,
    this.windSpeedKmh = 14.0,
    this.trackPoints,
    this.onZoomIn,
    this.onZoomOut,
  });

  final ThermalMapStyle style;
  final bool showCore;
  final int historySeconds;
  final double altitudeM;
  final double speedKmh;
  final double climbRateMs;
  final double headingDeg;
  final double windDirDeg;
  final double windSpeedKmh;
  final List<ThermalPoint>? trackPoints;
  final VoidCallback? onZoomIn;
  final VoidCallback? onZoomOut;

  @override
  State<ThermalMapWidget> createState() => _ThermalMapWidgetState();
}

class _ThermalMapWidgetState extends State<ThermalMapWidget>
    with SingleTickerProviderStateMixin {
  double _zoomLevel = 1.0;
  Offset _panOffset = Offset.zero;
  bool _centerOnPilot = true;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _handleZoom(double delta) {
    setState(() {
      _zoomLevel = (_zoomLevel + delta).clamp(0.5, 3.5);
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
          // Interactive Pan & Zoom Custom Canvas
          Positioned.fill(
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  _panOffset += details.delta;
                  _centerOnPilot = false;
                });
              },
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _ThermalMapPainter(
                      style: widget.style,
                      showCore: widget.showCore,
                      historySeconds: widget.historySeconds,
                      zoomLevel: _zoomLevel,
                      panOffset: _panOffset,
                      altitudeM: widget.altitudeM,
                      speedKmh: widget.speedKmh,
                      climbRateMs: widget.climbRateMs,
                      headingDeg: widget.headingDeg,
                      windDirDeg: widget.windDirDeg,
                      windSpeedKmh: widget.windSpeedKmh,
                      trackPoints: widget.trackPoints,
                      pulseAnimation: _pulseController.value,
                    ),
                  );
                },
              ),
            ),
          ),

          // Zoom & Recenter Controls Overlay
          Positioned(
            right: 8,
            bottom: 8,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!_centerOnPilot)
                  _buildOverlayButton(
                    key: const Key('btn_thermal_recenter'),
                    icon: Icons.my_location,
                    tooltip: 'Recenter on Glider',
                    onTap: _recenter,
                  ),
                const SizedBox(height: 4),
                _buildOverlayButton(
                  key: const Key('btn_thermal_zoom_in'),
                  icon: Icons.add,
                  tooltip: 'Zoom In',
                  onTap: () => _handleZoom(0.25),
                ),
                const SizedBox(height: 4),
                _buildOverlayButton(
                  key: const Key('btn_thermal_zoom_out'),
                  icon: Icons.remove,
                  tooltip: 'Zoom Out',
                  onTap: () => _handleZoom(-0.25),
                ),
              ],
            ),
          ),

          // Top Style Badge Indicator
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(160),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.white24, width: 0.8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.style == ThermalMapStyle.burnairCore
                        ? Icons.adjust
                        : (widget.style == ThermalMapStyle.navigatorRibbon
                            ? Icons.timeline
                            : Icons.bubble_chart),
                    color: const Color(0xFF00E676),
                    size: 13,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _styleLabel(widget.style),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _styleLabel(ThermalMapStyle style) {
    switch (style) {
      case ThermalMapStyle.xctrackBubbles:
        return 'XCtrack Bubbles';
      case ThermalMapStyle.burnairCore:
        return 'Burnair Core Assist';
      case ThermalMapStyle.navigatorRibbon:
        return 'Navigator Ribbon';
    }
  }

  Widget _buildOverlayButton({
    Key? key,
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Material(
      key: key,
      color: Colors.black.withAlpha(180),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white30, width: 0.8),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}

class _ThermalMapPainter extends CustomPainter {
  _ThermalMapPainter({
    required this.style,
    required this.showCore,
    required this.historySeconds,
    required this.zoomLevel,
    required this.panOffset,
    required this.altitudeM,
    required this.speedKmh,
    required this.climbRateMs,
    required this.headingDeg,
    required this.windDirDeg,
    required this.windSpeedKmh,
    required this.trackPoints,
    required this.pulseAnimation,
  });

  final ThermalMapStyle style;
  final bool showCore;
  final int historySeconds;
  final double zoomLevel;
  final Offset panOffset;
  final double altitudeM;
  final double speedKmh;
  final double climbRateMs;
  final double headingDeg;
  final double windDirDeg;
  final double windSpeedKmh;
  final List<ThermalPoint>? trackPoints;
  final double pulseAnimation;

  // ⚡ Bolt: Cache Paint objects to avoid per-frame GC allocations
  final Paint _ringPaint = Paint()
    ..color = Colors.cyanAccent.withAlpha(25)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;

  final Paint _axisPaint = Paint()
    ..color = Colors.white.withAlpha(20)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.8;

  final Paint _pathPaint = Paint()
    ..color = Colors.white.withAlpha(40)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;

  final Paint _bubbleFillPaint = Paint();
  final Paint _bubbleStrokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;
  final Paint _bubbleCorePaint = Paint();

  final Paint _corePulsePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0;
  final Paint _coreCenterPaint = Paint()
    ..color = const Color(0xFF00E676).withAlpha(160)
    ..style = PaintingStyle.fill;
  final Paint _coreDotPaint = Paint()..color = Colors.white;

  final Paint _driftLinePaint = Paint()
    ..color = Colors.lightBlueAccent.withAlpha(180)
    ..strokeWidth = 2.0
    ..strokeCap = StrokeCap.round;

  final Paint _ribbonPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 7.0
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  final Paint _whiteDotPaint = Paint()..color = Colors.white;
  final Paint _coloredDotPaint = Paint();

  final Paint _badgeBgPaint = Paint()..color = Colors.black.withAlpha(200);
  final Paint _badgeStrokePaint = Paint()
    ..color = const Color(0xFF00E676).withAlpha(120)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;

  final Paint _gliderShadowPaint = Paint()..color = Colors.black87;
  final Paint _gliderFillPaint = Paint()
    ..color = const Color(0xFF00E676)
    ..style = PaintingStyle.fill;
  final Paint _gliderStrokePaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;
  final Paint _gliderHeadingPaint = Paint()
    ..color = const Color(0xFF00E676)
    ..strokeWidth = 1.8
    ..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2) + panOffset;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(zoomLevel);

    // 1. Draw Subtle Compass & Turn Distance Radial Guides
    _drawRadialGuides(canvas, size);

    // 2. Generate or extract thermal flight track points
    final points = _resolveTrackPoints();

    // 3. Render according to the chosen style
    switch (style) {
      case ThermalMapStyle.xctrackBubbles:
        _drawXCtrackBubbles(canvas, points);
        break;
      case ThermalMapStyle.burnairCore:
        _drawBurnairCore(canvas, points);
        break;
      case ThermalMapStyle.navigatorRibbon:
        _drawNavigatorRibbon(canvas, points);
        break;
    }

    // 4. Draw Glider Position & Heading Indicator at (0, 0)
    _drawGlider(canvas);

    canvas.restore();
  }

  void _drawRadialGuides(Canvas canvas, Size size) {
    const radii = [40.0, 80.0, 120.0, 160.0];
    for (final r in radii) {
      canvas.drawCircle(Offset.zero, r, _ringPaint);
    }

    // Crosshairs
    canvas.drawLine(const Offset(-180, 0), const Offset(180, 0), _axisPaint);
    canvas.drawLine(const Offset(0, -180), const Offset(0, 180), _axisPaint);
  }

  List<ThermalPoint> _resolveTrackPoints() {
    if (trackPoints != null && trackPoints!.isNotEmpty) {
      return trackPoints!;
    }

    // Generate a realistic circling spiral track with varying lift/sink
    final now = DateTime.now();
    final points = <ThermalPoint>[];
    const totalPoints = 36;
    const turnRadius = 65.0;

    // Simulate 2.5 full thermal turns with core on the upper-right (dx: 25, dy: -20)
    for (int i = 0; i < totalPoints; i++) {
      final tRatio = i / totalPoints;
      final angle = (tRatio * 5 * math.pi) - (headingDeg * math.pi / 180.0);
      final ageSeconds = (1.0 - tRatio) * historySeconds;
      final timestamp = now.subtract(Duration(milliseconds: (ageSeconds * 1000).toInt()));

      // Circling coordinates relative to glider at origin
      final px = turnRadius * math.cos(angle) + (1.0 - tRatio) * 15;
      final py = turnRadius * math.sin(angle) - (1.0 - tRatio) * 10;

      // Realistic climb/sink model: highest climb near the core offset
      final distToCore = math.sqrt(math.pow(px - 25, 2) + math.pow(py + 20, 2));
      double simulatedClimb = 3.5 - (distToCore / 25.0);
      if (simulatedClimb < -2.0) simulatedClimb = -2.0;

      points.add(
        ThermalPoint(
          dx: px,
          dy: py,
          climbRateMs: simulatedClimb,
          timestamp: timestamp,
          altitudeM: altitudeM - (1.0 - tRatio) * 50,
        ),
      );
    }

    return points;
  }

  /// Calculates alpha transparency (0..255) based on climb/sink rate
  int _calculateAlpha(double climbRate, double ageDecay) {
    final absRate = climbRate.abs();
    // Base transparency mapping: weak (+/- 0.1 m/s) -> 0.25 (64), strong (+/- 3.0 m/s) -> 1.0 (255)
    final clamped = (absRate / 3.0).clamp(0.15, 1.0);
    final baseAlpha = 60 + (clamped * 195);
    final finalAlpha = (baseAlpha * ageDecay).clamp(30.0, 255.0);
    return finalAlpha.toInt();
  }

  /// Option 1: XCtrack Bubble Trail (Dynamic Radius & Alpha Decay)
  void _drawXCtrackBubbles(Canvas canvas, List<ThermalPoint> points) {
    if (points.isEmpty) return;

    // Draw connecting faint path
    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final pt = Offset(points[i].dx, points[i].dy);
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    canvas.drawPath(
      path,
      _pathPaint,
    );

    // Draw bubbles
    final now = DateTime.now();
    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      final ageSec = now.difference(p.timestamp).inMilliseconds / 1000.0;
      final ageDecay = (1.0 - (ageSec / historySeconds) * 0.6).clamp(0.3, 1.0);
      final alpha = _calculateAlpha(p.climbRateMs, ageDecay);

      final isLift = p.climbRateMs >= 0;
      final baseColor = isLift ? const Color(0xFF00E676) : const Color(0xFFFF1744);
      final color = baseColor.withAlpha(alpha);

      // Dynamic radius scaling: 6px to 14px for lift, 5px to 10px for sink
      final radius = isLift
          ? (6.0 + (p.climbRateMs.clamp(0.0, 4.0) / 4.0) * 8.0)
          : (5.0 + (p.climbRateMs.abs().clamp(0.0, 3.0) / 3.0) * 5.0);

      final pt = Offset(p.dx, p.dy);

      // Filled Circle
      _bubbleFillPaint.color = color;
      canvas.drawCircle(pt, radius, _bubbleFillPaint);

      // Outer outline for high contrast
      _bubbleStrokePaint.color = Colors.black.withAlpha((alpha * 0.7).toInt());
      canvas.drawCircle(
        pt,
        radius,
        _bubbleStrokePaint,
      );

      // Center bright core dot for strong thermals
      if (p.climbRateMs >= 2.5) {
        _bubbleCorePaint.color = Colors.white.withAlpha((alpha * 0.9).toInt());
        canvas.drawCircle(
          pt,
          radius * 0.35,
          _bubbleCorePaint,
        );
      }
    }
  }

  /// Option 2: Burnair Thermal Core Assist (Bubbles + Estimated Core Centroid)
  void _drawBurnairCore(Canvas canvas, List<ThermalPoint> points) {
    if (points.isEmpty) return;

    // Draw standard lift/sink trail bubbles
    _drawXCtrackBubbles(canvas, points);

    if (!showCore) return;

    // Calculate weighted centroid of lift points (climb > 0.5 m/s)
    double totalWeight = 0.0;
    double weightedX = 0.0;
    double weightedY = 0.0;
    double maxClimb = 0.0;

    for (final p in points) {
      if (p.climbRateMs > 0.5) {
        final weight = math.pow(p.climbRateMs, 2).toDouble();
        weightedX += p.dx * weight;
        weightedY += p.dy * weight;
        totalWeight += weight;
        if (p.climbRateMs > maxClimb) maxClimb = p.climbRateMs;
      }
    }

    if (totalWeight > 0) {
      final coreCenter = Offset(weightedX / totalWeight, weightedY / totalWeight);

      // Pulsing concentric rings
      final pulseRadius = 24.0 + (pulseAnimation * 10.0);
      _corePulsePaint.color = const Color(0xFFFACC15).withAlpha((180 - pulseAnimation * 80).toInt());

      canvas.drawCircle(coreCenter, pulseRadius, _corePulsePaint);
      canvas.drawCircle(
        coreCenter,
        14.0,
        _coreCenterPaint,
      );
      canvas.drawCircle(
        coreCenter,
        4.0,
        _coreDotPaint,
      );

      // Wind drift vector arrow originating from core
      final windRad = (windDirDeg + 180) * math.pi / 180.0;
      final driftEnd = Offset(
        coreCenter.dx + math.sin(windRad) * 35.0,
        coreCenter.dy - math.cos(windRad) * 35.0,
      );
      canvas.drawLine(
        coreCenter,
        driftEnd,
        _driftLinePaint,
      );

      // Core Climb Label
      final tp = TextPainter(
        text: TextSpan(
          text: 'CORE +${maxClimb.toStringAsFixed(1)}m/s',
          style: const TextStyle(
            color: Color(0xFFFACC15),
            fontSize: 10,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(color: Colors.black, blurRadius: 4)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(coreCenter.dx - tp.width / 2, coreCenter.dy + 18));
    }
  }

  /// Option 3: Navigator Heat Ribbon (Color-Graded Spline Ribbon + Stats Badge)
  void _drawNavigatorRibbon(Canvas canvas, List<ThermalPoint> points) {
    if (points.isEmpty) return;

    final now = DateTime.now();

    // Draw continuous color-graded ribbon segments
    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      final avgClimb = (p1.climbRateMs + p2.climbRateMs) / 2.0;
      final ageSec = now.difference(p1.timestamp).inMilliseconds / 1000.0;
      final ageDecay = (1.0 - (ageSec / historySeconds) * 0.6).clamp(0.3, 1.0);
      final alpha = _calculateAlpha(avgClimb, ageDecay);

      final isLift = avgClimb >= 0;
      final baseColor = isLift ? const Color(0xFF00E676) : const Color(0xFFFF1744);
      _ribbonPaint.color = baseColor.withAlpha(alpha);

      canvas.drawLine(
        Offset(p1.dx, p1.dy),
        Offset(p2.dx, p2.dy),
        _ribbonPaint,
      );
    }

    // Draw milestone circles and peak markers
    for (int i = 0; i < points.length; i += 4) {
      final p = points[i];
      final isLift = p.climbRateMs >= 0;
      final color = isLift ? const Color(0xFF00E676) : const Color(0xFFFF1744);
      final pt = Offset(p.dx, p.dy);

      canvas.drawCircle(pt, 5.0, _whiteDotPaint);

      _coloredDotPaint.color = color;
      canvas.drawCircle(pt, 3.5, _coloredDotPaint);
    }

    // 360-degree Turn Average Stats Badge Overlay
    double sumLift = 0.0;
    for (final p in points) {
      sumLift += p.climbRateMs;
    }
    final avgLift = sumLift / points.length;

    final badgeRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-80, 85, 160, 24),
      const Radius.circular(12),
    );
    canvas.drawRRect(
      badgeRect,
      _badgeBgPaint,
    );
    canvas.drawRRect(
      badgeRect,
      _badgeStrokePaint,
    );

    final statsTp = TextPainter(
      text: TextSpan(
        text: '360° AVG: ${avgLift >= 0 ? "+" : ""}${avgLift.toStringAsFixed(1)} m/s',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    statsTp.paint(canvas, Offset(-statsTp.width / 2, 90));
  }

  /// Glider Heading Icon at (0, 0)
  void _drawGlider(Canvas canvas) {
    canvas.save();
    canvas.rotate((headingDeg) * math.pi / 180.0);

    // Paraglider chevron wing
    final wingPath = Path()
      ..moveTo(0, -12) // Nose / Apex
      ..lineTo(10, 6)  // Right wingtip
      ..lineTo(4, 3)   // Trailing edge right
      ..lineTo(0, 7)   // Tail
      ..lineTo(-4, 3)  // Trailing edge left
      ..lineTo(-10, 6) // Left wingtip
      ..close();

    canvas.drawPath(
      wingPath,
      _gliderShadowPaint,
    );
    canvas.drawPath(
      wingPath,
      _gliderFillPaint,
    );
    canvas.drawPath(
      wingPath,
      _gliderStrokePaint,
    );

    // Heading projected velocity line
    canvas.drawLine(
      const Offset(0, -12),
      const Offset(0, -32),
      _gliderHeadingPaint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ThermalMapPainter oldDelegate) {
    return oldDelegate.style != style ||
        oldDelegate.showCore != showCore ||
        oldDelegate.historySeconds != historySeconds ||
        oldDelegate.zoomLevel != zoomLevel ||
        oldDelegate.panOffset != panOffset ||
        oldDelegate.altitudeM != altitudeM ||
        oldDelegate.climbRateMs != climbRateMs ||
        oldDelegate.headingDeg != headingDeg ||
        oldDelegate.windDirDeg != windDirDeg ||
        oldDelegate.trackPoints != trackPoints ||
        oldDelegate.pulseAnimation != pulseAnimation;
  }
}
