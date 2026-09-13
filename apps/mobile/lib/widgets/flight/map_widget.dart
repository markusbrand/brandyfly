import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:maplibre/maplibre.dart' hide Marker;

import '../../models/flight_model.dart';
import '../../models/lat_lng.dart';
import '../../models/ui_config.dart';
import '../../services/maplibre_map_service.dart';

/// Paragliding Map Widget with MapLibre GL offline vector tile rendering,
/// Copernicus DEM hillshade terrain relief, local PMTiles fallback detection,
/// airspace polygons, thermal overlays, breadcrumb tracks, and pilot position.
class MapWidget extends StatefulWidget {
  const MapWidget({
    super.key,
    this.style = MapWidgetStyle.alpineRelief,
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
    this.initialZoom = 13.5,
    this.pilotPosition,
    this.trackPoints,
    this.flightPoints,
    this.mapTrackHistoryMinutes = 10,
    this.mapTrackShowOlderTail = true,
    this.onZoomIn,
    this.onZoomOut,
    this.onZoomChanged,
    this.regionId,
    this.mapService,
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
  final double initialZoom;
  final LatLng? pilotPosition;
  final List<LatLng>? trackPoints;
  final List<FlightPoint>? flightPoints;
  final int mapTrackHistoryMinutes;
  final bool mapTrackShowOlderTail;
  final VoidCallback? onZoomIn;
  final VoidCallback? onZoomOut;
  final ValueChanged<double>? onZoomChanged;
  final String? regionId;
  final MapLibreMapService? mapService;

  /// Continuous piecewise color interpolation for the vario gradient flight
  /// track. Maps vertical speed (m/s) to a lift/sink colour stop.
  static Color getVarioTrackColor(double vario) {
    if (vario <= -3.0) return const Color(0xFF991B1B); // Deep Dark Red
    if (vario < -1.5) {
      final t = (vario - (-3.0)) / (-1.5 - (-3.0));
      return Color.lerp(
        const Color(0xFF991B1B),
        const Color(0xFFEF4444),
        t,
      )!;
    }
    if (vario < -0.5) {
      final t = (vario - (-1.5)) / (-0.5 - (-1.5));
      return Color.lerp(
        const Color(0xFFEF4444),
        const Color(0xFFFCA5A5),
        t,
      )!;
    }
    if (vario <= 0.5) {
      return const Color(0xFF94A3B8); // Neutral Slate Grey
    }
    if (vario < 1.5) {
      final t = (vario - 0.5) / (1.5 - 0.5);
      return Color.lerp(
        const Color(0xFF86EFAC),
        const Color(0xFF22C55E),
        t,
      )!;
    }
    if (vario < 3.5) {
      final t = (vario - 1.5) / (3.5 - 1.5);
      return Color.lerp(
        const Color(0xFF22C55E),
        const Color(0xFF15803D),
        t,
      )!;
    }
    return const Color(0xFF15803D); // Dark Emerald Green
  }

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  late final MapLibreMapService _mapService;
  late double _currentZoom;
  bool _centerOnPilot = true;
  Timer? _recenterTimer;
  Offset _panOffset = Offset.zero;
  String? _styleJson;

  // Default Alpine launch reference coordinates (Dachstein / Krippenstein)
  static const LatLng _defaultPilotPosition = LatLng(47.525, 13.685);

  LatLng get _effectivePilotPosition =>
      widget.pilotPosition ?? _defaultPilotPosition;

  List<LatLng> get _effectiveTrackPoints {
    if (widget.trackPoints != null && widget.trackPoints!.isNotEmpty) {
      return widget.trackPoints!;
    }
    final p = _effectivePilotPosition;
    return [
      LatLng(p.latitude - 0.015, p.longitude - 0.018),
      LatLng(p.latitude - 0.010, p.longitude - 0.012),
      LatLng(p.latitude - 0.006, p.longitude - 0.008),
      LatLng(p.latitude - 0.003, p.longitude - 0.003),
      LatLng(p.latitude - 0.001, p.longitude - 0.001),
      p,
    ];
  }

  List<FlightPoint> get _effectiveFlightPoints {
    if (widget.flightPoints != null && widget.flightPoints!.isNotEmpty) {
      return widget.flightPoints!;
    }
    return _buildMockFlightPoints(_effectivePilotPosition);
  }

  @override
  void initState() {
    super.initState();
    _mapService = widget.mapService ?? MapLibreMapService();
    _currentZoom = widget.initialZoom;
    _initMapStyle();
  }

  Future<void> _initMapStyle() async {
    final style = await _mapService.buildStyleJson(
      regionId: widget.regionId,
    );
    if (mounted) {
      setState(() {
        _styleJson = style;
      });
    }
  }

  @override
  void dispose() {
    _recenterTimer?.cancel();
    if (widget.mapService == null) {
      _mapService.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(MapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.mapService != oldWidget.mapService) {
      if (oldWidget.mapService == null) {
        _mapService.dispose();
      }
      _mapService = widget.mapService ?? MapLibreMapService();
      _initMapStyle();
    } else if (widget.regionId != oldWidget.regionId) {
      _initMapStyle();
    }

    if (widget.initialZoom != oldWidget.initialZoom) {
      _currentZoom = widget.initialZoom;
      _updateCamera();
    }

    final oldPilot = oldWidget.pilotPosition ?? _defaultPilotPosition;
    final newPilot = _effectivePilotPosition;
    if (_centerOnPilot && oldPilot != newPilot) {
      _updateCamera();
    }

    if (widget.orientation != oldWidget.orientation ||
        (widget.orientation == MapOrientation.trackUp &&
            widget.headingDeg != oldWidget.headingDeg)) {
      _updateCamera();
    }
  }

  void _updateCamera() {
    final bearing = widget.orientation == MapOrientation.trackUp
        ? widget.headingDeg
        : 0.0;
    _mapService.moveCamera(
      position: _effectivePilotPosition,
      zoom: _currentZoom,
      bearing: bearing,
    );
  }

  void _handleZoom(double delta) {
    final newZoom = (_currentZoom + delta).clamp(1.0, 22.0);
    setState(() {
      _currentZoom = newZoom;
    });

    _mapService.moveCamera(
      position: _effectivePilotPosition,
      zoom: newZoom,
    );

    widget.onZoomChanged?.call(newZoom);
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
    _updateCamera();
  }

  void _startRecenterTimer() {
    _recenterTimer?.cancel();
    _recenterTimer = Timer(const Duration(seconds: 6), _recenter);
  }

  @override
  Widget build(BuildContext context) {
    final pilotPos = _effectivePilotPosition;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        children: [
          // 1. Map Canvas / MapLibre GL Base Map
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (details) {
                setState(() {
                  _panOffset += details.delta;
                  _centerOnPilot = false;
                });
                _startRecenterTimer();
              },
              child: _buildMapBackground(pilotPos),
            ),
          ),

          // 2. Flight Overlays (Airspace, Flight Track, Thermals, Pilot Marker)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _FlightOverlayPainter(
                  pilotPosition: pilotPos,
                  orientation: widget.orientation,
                  headingDeg: widget.headingDeg,
                  zoom: _currentZoom,
                  panOffset: _panOffset,
                  showAirspace: widget.showAirspace,
                  showTrack: widget.showTrack,
                  showThermals: widget.showThermals,
                  flightPoints: _effectiveFlightPoints,
                  trackPoints: _effectiveTrackPoints,
                  climbRateMs: widget.climbRateMs,
                  mapTrackHistoryMinutes: widget.mapTrackHistoryMinutes,
                  mapTrackShowOlderTail: widget.mapTrackShowOlderTail,
                ),
              ),
            ),
          ),

          // 3. Fallback Badge ("No offline data")
          if (_mapService.isFallbackActive)
            Positioned(
              top: 36,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amber.shade900.withAlpha(220),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.amberAccent, width: 1),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 12, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      'No offline data (Overview fallback)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 4. Map Header Badge
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(180),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: Colors.cyanAccent.withAlpha(100),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.map_outlined,
                    size: 12,
                    color: Colors.cyanAccent,
                  ),
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

          // 5. North / Orientation Compass Widget
          Positioned(
            top: 8,
            right: 8,
            child: _buildCompassIndicator(),
          ),

          // 6. In-flight Zoom Steppers & Recenter Toolbar
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
                  onPressed: () => _handleZoom(0.5),
                ),
                const SizedBox(height: 4),
                _mapActionButton(
                  key: const Key('btn_map_zoom_out'),
                  icon: Icons.remove,
                  tooltip: 'Zoom Out',
                  onPressed: () => _handleZoom(-0.5),
                ),
              ],
            ),
          ),

          // 7. Dynamic Scale Bar & Altitude / Speed HUD
          Positioned(
            bottom: 8,
            left: 8,
            child: _buildScaleAndLegend(),
          ),
        ],
      ),
    );
  }

  Widget _buildMapBackground(LatLng pilotPos) {
    if (_styleJson != null) {
      return MapLibreMap(
        options: MapOptions(
          initCenter: Geographic(
            lon: pilotPos.longitude,
            lat: pilotPos.latitude,
          ),
          initZoom: _currentZoom,
          initStyle: _styleJson!,
        ),
        onMapCreated: _mapService.onMapCreated,
        onStyleLoaded: _mapService.onStyleLoaded,
      );
    }

    return const SizedBox.expand();
  }

  String _getStyleTitle(MapWidgetStyle style) {
    switch (style) {
      case MapWidgetStyle.alpineRelief:
      case MapWidgetStyle.topoContours:
        return 'ALPINE RELIEF (OFFLINE PMTILES)';
      case MapWidgetStyle.minimalVector:
        return 'VECTOR HUD (OFFLINE)';
      case MapWidgetStyle.thermalHeatmap:
        return 'THERMAL RADAR (OFFLINE)';
      case MapWidgetStyle.satelliteTerrain:
        return 'TERRAIN DEM (OFFLINE)';
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
    final scaleKm = (40000.0 / math.pow(2, _currentZoom)).clamp(0.2, 50.0);
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
    return Container(
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
      child: IconButton(
        key: key,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 28, height: 28),
        icon: Icon(
          icon,
          size: 16,
          color: active ? Colors.white : Colors.white70,
        ),
        tooltip: tooltip,
        splashRadius: 14,
        onPressed: onPressed,
      ),
    );
  }

  List<FlightPoint> _buildMockFlightPoints(LatLng p) {
    final now = DateTime.now();
    final latSteps = [0.015, 0.010, 0.006, 0.003, 0.001, 0.0];
    final lngSteps = [0.018, 0.012, 0.008, 0.003, 0.001, 0.0];
    final varioProfile = [3.2, 2.4, 1.6, 0.8, 0.2, -0.3, -0.8, -1.6, -2.4, 0.5, 1.2, 2.8];

    final mock = <FlightPoint>[];
    for (var i = 0; i < latSteps.length; i++) {
      mock.add(
        FlightPoint(
          timestamp: now.subtract(Duration(minutes: (latSteps.length - i - 1) * 1)),
          latitude: p.latitude - latSteps[i],
          longitude: p.longitude - lngSteps[i],
          altitude: 1450.0 + (i * 12),
          vario: varioProfile[(i * 3) % varioProfile.length],
        ),
      );
    }
    return mock;
  }
}

/// Flight overlay painter that renders airspace polygons, vario flight track,
/// thermal markers, and pilot position marker.
class _FlightOverlayPainter extends CustomPainter {
  const _FlightOverlayPainter({
    required this.pilotPosition,
    required this.orientation,
    required this.headingDeg,
    required this.zoom,
    required this.panOffset,
    required this.showAirspace,
    required this.showTrack,
    required this.showThermals,
    required this.flightPoints,
    required this.trackPoints,
    required this.climbRateMs,
    required this.mapTrackHistoryMinutes,
    required this.mapTrackShowOlderTail,
  });

  final LatLng pilotPosition;
  final MapOrientation orientation;
  final double headingDeg;
  final double zoom;
  final Offset panOffset;
  final bool showAirspace;
  final bool showTrack;
  final bool showThermals;
  final List<FlightPoint> flightPoints;
  final List<LatLng> trackPoints;
  final double climbRateMs;
  final int mapTrackHistoryMinutes;
  final bool mapTrackShowOlderTail;

  Offset _toScreen(LatLng point, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // 1 degree lat approx 111,000m. Scale based on zoom.
    final pixelsPerDegreeLat = math.pow(2, zoom) * 8.0;
    final cosLat = math.cos(pilotPosition.latitude * math.pi / 180);
    final pixelsPerDegreeLng = pixelsPerDegreeLat * cosLat;

    final dLat = point.latitude - pilotPosition.latitude;
    final dLng = point.longitude - pilotPosition.longitude;

    var dx = dLng * pixelsPerDegreeLng;
    var dy = -dLat * pixelsPerDegreeLat; // Screen Y is inverted

    if (orientation == MapOrientation.trackUp) {
      final rad = -headingDeg * math.pi / 180;
      final rotX = dx * math.cos(rad) - dy * math.sin(rad);
      final rotY = dx * math.sin(rad) + dy * math.cos(rad);
      dx = rotX;
      dy = rotY + size.height * 0.1; // Forward bias
    }

    return center + Offset(dx, dy) + panOffset;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Airspace
    if (showAirspace) {
      _paintAirspace(canvas, size);
    }

    // 2. Flight track
    if (showTrack) {
      _paintFlightTrack(canvas, size);
    }

    // 3. Thermals
    if (showThermals) {
      _paintThermals(canvas, size);
    }

    // 4. Pilot Position Marker
    _paintPilotMarker(canvas, size);
  }

  void _paintAirspace(Canvas canvas, Size size) {
    final pts = [
      _toScreen(LatLng(pilotPosition.latitude + 0.025, pilotPosition.longitude - 0.035), size),
      _toScreen(LatLng(pilotPosition.latitude + 0.035, pilotPosition.longitude + 0.025), size),
      _toScreen(LatLng(pilotPosition.latitude + 0.010, pilotPosition.longitude + 0.040), size),
      _toScreen(LatLng(pilotPosition.latitude - 0.015, pilotPosition.longitude - 0.010), size),
    ];

    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (int i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    path.close();

    final fillPaint = Paint()
      ..color = const Color(0xFFEF4444).withAlpha(35)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = const Color(0xFFEF4444).withAlpha(180)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, borderPaint);
  }

  void _paintFlightTrack(Canvas canvas, Size size) {
    final points = flightPoints;
    if (points.isEmpty) return;

    for (int i = 1; i < points.length; i++) {
      final p1 = _toScreen(LatLng(points[i - 1].latitude, points[i - 1].longitude), size);
      final p2 = _toScreen(LatLng(points[i].latitude, points[i].longitude), size);
      final color = MapWidget.getVarioTrackColor(points[i].vario);

      final trackPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(p1, p2, trackPaint);
    }
  }

  void _paintThermals(Canvas canvas, Size size) {
    final hotspots = [
      (LatLng(pilotPosition.latitude + 0.008, pilotPosition.longitude + 0.012), '+2.8'),
      (LatLng(pilotPosition.latitude - 0.006, pilotPosition.longitude + 0.018), '+3.4'),
      (LatLng(pilotPosition.latitude - 0.012, pilotPosition.longitude - 0.009), '+1.9'),
    ];

    final circlePaint = Paint()
      ..color = const Color(0xFFF97316).withAlpha(200)
      ..style = PaintingStyle.fill;
    final ringPaint = Paint()
      ..color = const Color(0xFFFACC15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (final th in hotspots) {
      final pos = _toScreen(th.$1, size);
      canvas.drawCircle(pos, 8, circlePaint);
      canvas.drawCircle(pos, 8, ringPaint);
    }
  }

  void _paintPilotMarker(Canvas canvas, Size size) {
    final pos = _toScreen(pilotPosition, size);
    final rotate = orientation == MapOrientation.trackUp
        ? 0.0
        : headingDeg * math.pi / 180;

    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(rotate);

    // Halo
    final haloPaint = Paint()
      ..color = Colors.cyanAccent.withAlpha(45)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset.zero, 18, haloPaint);

    // Glider Arrow
    final path = Path()
      ..moveTo(0, -11)
      ..lineTo(-8, 8)
      ..lineTo(0, 3)
      ..lineTo(8, 8)
      ..close();

    final outlinePaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    final bodyPaint = Paint()
      ..color = Colors.cyanAccent
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, outlinePaint);
    canvas.drawPath(path, bodyPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FlightOverlayPainter old) => true;
}
