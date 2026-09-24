import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/ui_config.dart';

/// Data model representing a point along the thermaling track
class ThermalPoint {
  ThermalPoint({
    required this.dx,
    required this.dy,
    required this.climbRateMs,
    required this.timestamp,
    this.altitudeM,
  }) : offset = Offset(dx, dy);

  final double
  dx; // Offset in meters or relative canvas units from thermal origin
  final double dy;
  final Offset offset;
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
  bool _useAirmassTrack = false;
  Timer? _recenterTimer;
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
    _recenterTimer?.cancel();
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
    _recenterTimer?.cancel();
    setState(() {
      _panOffset = Offset.zero;
      _centerOnPilot = true;
    });
  }

  void _startRecenterTimer() {
    _recenterTimer?.cancel();
    _recenterTimer = Timer(const Duration(seconds: 6), _recenter);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        children: [
          // Interactive Pan & Zoom Custom Canvas
          Positioned.fill(
            child: Semantics(
              button: false,
              label: 'Interactive thermal map canvas',
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    _panOffset += details.delta;
                    _centerOnPilot = false;
                  });
                  _startRecenterTimer();
                },
                child: CustomPaint(
                  key: const Key('canvas_thermal_map'),
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
                    pulseAnimation: _pulseController,
                    useAirmassTrack: _useAirmassTrack,
                  ),
                ),
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
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
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
                const SizedBox(width: 8),
                Semantics(
                  button: true,
                  label: 'Toggle airmass or ground track',
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _useAirmassTrack = !_useAirmassTrack;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(160),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.white24, width: 0.8),
                      ),
                      child: Text(
                        _useAirmassTrack ? 'AIRMASS' : 'GROUND',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
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
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white30, width: 0.8),
          borderRadius: BorderRadius.circular(6),
        ),
        child: IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          icon: Icon(icon, color: Colors.white, size: 18),
          tooltip: tooltip,
          splashRadius: 16,
          onPressed: onTap,
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
    required this.useAirmassTrack,
  }) : super(
         repaint: pulseAnimation,
       ); // ⚡ Bolt: Bind animation to repaint property to skip widget rebuilds

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
  final Animation<double> pulseAnimation;
  final bool useAirmassTrack;

  // Cached Paint objects to prevent per-frame allocation
  final Paint _ringPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;
  final Paint _axisPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.8;
  final Paint _pathPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;
  final Paint _bubblePaint = Paint();
  final Paint _bubbleOutlinePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;
  final Paint _coreDotPaint = Paint();
  final Paint _pulseRingPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0;
  final Paint _coreCenterPaint = Paint()..style = PaintingStyle.fill;
  final Paint _coreInnerDotPaint = Paint()..color = Colors.white;
  final Paint _driftPaint = Paint()
    ..strokeWidth = 2.0
    ..strokeCap = StrokeCap.round;
  final Paint _ribbonPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 7.0
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final Paint _milestoneWhitePaint = Paint()..color = Colors.white;
  final Paint _milestoneColorPaint = Paint();
  final Paint _badgeBgPaint = Paint();
  final Paint _badgeOutlinePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;
  final Paint _wingShadowPaint = Paint()..color = Colors.black87;
  final Paint _wingFillPaint = Paint()..style = PaintingStyle.fill;
  final Paint _wingOutlinePaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;
  final Paint _headingLinePaint = Paint()
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
    _ringPaint.color = Colors.cyanAccent.withAlpha(25);

    const radii = [40.0, 80.0, 120.0, 160.0];
    for (final r in radii) {
      canvas.drawCircle(Offset.zero, r, _ringPaint);
    }

    // Crosshairs
    _axisPaint.color = Colors.white.withAlpha(20);

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
      final timestamp = now.subtract(
        Duration(milliseconds: (ageSeconds * 1000).toInt()),
      );

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

    final now = DateTime.now();
    final historyDecayFactor = historySeconds > 0 ? 0.6 / historySeconds : 0.0;

    // Pre-calculate wind drift velocity vector outside inner loops if airmass track is enabled
    double wx = 0.0;
    double wy = 0.0;
    if (useAirmassTrack) {
      final windVx = (windDirDeg + 180) * math.pi / 180.0;
      wx = math.sin(windVx) * (windSpeedKmh / 3.6);
      wy = -math.cos(windVx) * (windSpeedKmh / 3.6);
    }

    // Draw connecting faint path
    final path = Path();
    for (int i = 0; i < points.length; i++) {
      double px = points[i].dx;
      double py = points[i].dy;

      if (useAirmassTrack) {
         // Apply wind correction to shift point back to its airmass location.
         final ageSec = now.difference(points[i].timestamp).inMilliseconds / 1000.0;
         // Assuming map scale is 1 unit = 1 meter, we can drift by vx * t.
         px += wx * ageSec;
         py += wy * ageSec;
      }

      final pt = Offset(px, py);

      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    _pathPaint.color = Colors.white.withAlpha(40);
    canvas.drawPath(path, _pathPaint);

    // Draw bubbles
    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      final ageSec = now.difference(p.timestamp).inMilliseconds / 1000.0;
      final ageDecay = (1.0 - (ageSec * historyDecayFactor)).clamp(0.3, 1.0);
      
      final climb = p.climbRateMs;

      Color bColor;
      double bRadius;
      int bAlpha;

      if (climb > 1.5) {
        bColor = const Color(0xFF00E676); // Bright Green
        bRadius = 12.0 + ((climb - 1.5) * 1.5).clamp(0.0, 4.0);
        bAlpha = (230 * ageDecay).toInt();
      } else if (climb > 0.2) {
        bColor = const Color(0xFF76FF03); // Light Green
        bRadius = 9.0 + ((climb - 0.2) * 2.3);
        bAlpha = (204 * ageDecay).toInt();
      } else if (climb > -0.5) {
        bColor = const Color(0xFFFF9100); // Orange
        bRadius = 7.0 + ((climb + 0.5) * 2.8);
        bAlpha = (166 * ageDecay).toInt();
      } else {
        bColor = const Color(0xFFFF1744); // Vivid Red
        bRadius = 6.0 + ((climb.abs() - 0.5) * 1.0).clamp(0.0, 2.0);
        bAlpha = (216 * ageDecay).toInt();
      }

      double px = p.dx;
      double py = p.dy;
      if (useAirmassTrack) {
         px += wx * ageSec;
         py += wy * ageSec;
      }
      final pt = Offset(px, py);

      // Filled Circle
      _bubblePaint.color = bColor.withAlpha(bAlpha.clamp(0, 255));
      canvas.drawCircle(pt, bRadius, _bubblePaint);

      // Outer outline for high contrast
      _bubbleOutlinePaint.color = Colors.black87.withAlpha(
        (180 * ageDecay).toInt().clamp(0, 255),
      );
      _bubbleOutlinePaint.strokeWidth = 1.2;
      canvas.drawCircle(pt, bRadius, _bubbleOutlinePaint);

      // Center bright core dot for strong thermals
      if (climb >= 2.5) {
        _coreDotPaint.color = Colors.white.withAlpha(
          (bAlpha * 0.9).toInt().clamp(0, 255),
        );
        canvas.drawCircle(pt, bRadius * 0.35, _coreDotPaint);
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

    final now = DateTime.now();

    double wx = 0.0;
    double wy = 0.0;
    if (useAirmassTrack) {
      final windVx = (windDirDeg + 180) * math.pi / 180.0;
      wx = math.sin(windVx) * (windSpeedKmh / 3.6);
      wy = -math.cos(windVx) * (windSpeedKmh / 3.6);
    }

    for (final p in points) {
      final climb = p.climbRateMs;
      if (climb > 0.5) {
        final weight = climb * climb;
        double px = p.dx;
        double py = p.dy;

        if (useAirmassTrack) {
           final ageSec = now.difference(p.timestamp).inMilliseconds / 1000.0;
           px += wx * ageSec;
           py += wy * ageSec;
        }

        weightedX += px * weight;
        weightedY += py * weight;
        totalWeight += weight;
        if (climb > maxClimb) maxClimb = climb;
      }
    }

    if (totalWeight > 0) {
      final coreCenter = Offset(
        weightedX / totalWeight,
        weightedY / totalWeight,
      );

      // Draw dashed guidance line from glider to core
      _driftPaint.color = Colors.white.withAlpha(120);
      _drawDashedLine(canvas, Offset.zero, coreCenter, _driftPaint);

      // Pulsing concentric rings
      final pulseRadius = 24.0 + (pulseAnimation.value * 10.0);
      _pulseRingPaint.color = const Color(
        0xFFFACC15,
      ).withAlpha((180 - pulseAnimation.value * 80).toInt().clamp(0, 255));

      canvas.drawCircle(coreCenter, pulseRadius, _pulseRingPaint);

      _coreCenterPaint.color = const Color(0xFF00E676).withAlpha(160);
      canvas.drawCircle(coreCenter, 14.0, _coreCenterPaint);
      canvas.drawCircle(coreCenter, 4.0, _coreInnerDotPaint);

      // Draw wind overlay separately (often done via widget, but here if needed)
      // Wind drift vector arrow originating from core
      final windRad = (windDirDeg) * math.pi / 180.0;
      final driftEnd = Offset(
        coreCenter.dx + math.sin(windRad) * 35.0,
        coreCenter.dy - math.cos(windRad) * 35.0,
      );
      _driftPaint.color = Colors.lightBlueAccent.withAlpha(180);
      _drawArrow(canvas, coreCenter, driftEnd, _driftPaint);

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
      tp.paint(
        canvas,
        Offset(coreCenter.dx - tp.width / 2, coreCenter.dy + 18),
      );
    }
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const double dashWidth = 5.0;
    const double dashSpace = 5.0;
    double startX = p1.dx;
    double startY = p1.dy;
    double distance = (p2 - p1).distance;
    double dx = (p2.dx - p1.dx) / distance;
    double dy = (p2.dy - p1.dy) / distance;
    double drawn = 0.0;
    while (drawn < distance) {
      double end = (drawn + dashWidth).clamp(0.0, distance);
      canvas.drawLine(
        Offset(startX + dx * drawn, startY + dy * drawn),
        Offset(startX + dx * end, startY + dy * end),
        paint,
      );
      drawn += dashWidth + dashSpace;
    }
  }

  void _drawArrow(Canvas canvas, Offset start, Offset end, Paint paint) {
    canvas.drawLine(start, end, paint);
    double dx = end.dx - start.dx;
    double dy = end.dy - start.dy;
    double angle = math.atan2(dy, dx);
    double headLen = 10.0;
    Offset arrow1 = Offset(
      end.dx - headLen * math.cos(angle - math.pi / 6),
      end.dy - headLen * math.sin(angle - math.pi / 6),
    );
    Offset arrow2 = Offset(
      end.dx - headLen * math.cos(angle + math.pi / 6),
      end.dy - headLen * math.sin(angle + math.pi / 6),
    );
    Path path = Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(arrow1.dx, arrow1.dy)
      ..lineTo(arrow2.dx, arrow2.dy)
      ..close();
    canvas.drawPath(path, paint..style = PaintingStyle.fill);
  }

  /// Option 3: Navigator Heat Ribbon (Color-Graded Spline Ribbon + Stats Badge)
  void _drawNavigatorRibbon(Canvas canvas, List<ThermalPoint> points) {
    if (points.isEmpty) return;

    final now = DateTime.now();
    final historyDecayFactor = historySeconds > 0 ? 0.6 / historySeconds : 0.0;

    // Draw continuous color-graded ribbon segments
    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      final avgClimb = (p1.climbRateMs + p2.climbRateMs) / 2.0;
      final ageSec = now.difference(p1.timestamp).inMilliseconds / 1000.0;
      final ageDecay = (1.0 - (ageSec * historyDecayFactor)).clamp(0.3, 1.0);
      final alpha = _calculateAlpha(avgClimb, ageDecay);

      final isLift = avgClimb >= 0;
      final baseColor = isLift
          ? const Color(0xFF00E676)
          : const Color(0xFFFF1744);

      _ribbonPaint.color = baseColor.withAlpha(alpha);

      canvas.drawLine(p1.offset, p2.offset, _ribbonPaint);
    }

    // Draw milestone circles and peak markers
    for (int i = 0; i < points.length; i += 4) {
      final p = points[i];
      final isLift = p.climbRateMs >= 0;
      final color = isLift ? const Color(0xFF00E676) : const Color(0xFFFF1744);
      final pt = p.offset;

      canvas.drawCircle(pt, 5.0, _milestoneWhitePaint);
      _milestoneColorPaint.color = color;
      canvas.drawCircle(pt, 3.5, _milestoneColorPaint);
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
    _badgeBgPaint.color = Colors.black.withAlpha(200);
    canvas.drawRRect(badgeRect, _badgeBgPaint);
    _badgeOutlinePaint.color = const Color(0xFF00E676).withAlpha(120);
    canvas.drawRRect(badgeRect, _badgeOutlinePaint);

    final statsTp = TextPainter(
      text: TextSpan(
        text:
            '360° AVG: ${avgLift >= 0 ? "+" : ""}${avgLift.toStringAsFixed(1)} m/s',
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
      ..lineTo(10, 6) // Right wingtip
      ..lineTo(4, 3) // Trailing edge right
      ..lineTo(0, 7) // Tail
      ..lineTo(-4, 3) // Trailing edge left
      ..lineTo(-10, 6) // Left wingtip
      ..close();

    canvas.drawPath(wingPath, _wingShadowPaint);
    _wingFillPaint.color = const Color(0xFF00E676);
    canvas.drawPath(wingPath, _wingFillPaint);
    canvas.drawPath(wingPath, _wingOutlinePaint);

    // Heading projected velocity line
    _headingLinePaint.color = const Color(0xFF00E676);
    canvas.drawLine(
      const Offset(0, -12),
      const Offset(0, -32),
      _headingLinePaint,
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
        oldDelegate.useAirmassTrack != useAirmassTrack;
  }
}
