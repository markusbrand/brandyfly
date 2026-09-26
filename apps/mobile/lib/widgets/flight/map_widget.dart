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
      return Color.lerp(const Color(0xFF991B1B), const Color(0xFFEF4444), t)!;
    }
    if (vario < -0.5) {
      final t = (vario - (-1.5)) / (-0.5 - (-1.5));
      return Color.lerp(const Color(0xFFEF4444), const Color(0xFFFCA5A5), t)!;
    }
    if (vario <= 0.5) {
      return const Color(0xFF94A3B8); // Neutral Slate Grey
    }
    if (vario < 1.5) {
      final t = (vario - 0.5) / (1.5 - 0.5);
      return Color.lerp(const Color(0xFF86EFAC), const Color(0xFF22C55E), t)!;
    }
    if (vario < 3.5) {
      final t = (vario - 1.5) / (3.5 - 1.5);
      return Color.lerp(const Color(0xFF22C55E), const Color(0xFF15803D), t)!;
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
  late LatLng _cameraCenter;
  String? _styleJson;
  bool _isProgrammaticMove = false;
  Timer? _programmaticMoveTimer;

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
    _mapService.addListener(_onMapServiceChanged);
    _currentZoom = widget.initialZoom;
    _cameraCenter = _effectivePilotPosition;
    _initMapStyle();
  }

  void _onMapServiceChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _initMapStyle() async {
    final style = await _mapService.buildStyleJson(regionId: widget.regionId);
    if (mounted) {
      setState(() {
        _styleJson = style;
      });
    }
  }

  @override
  void dispose() {
    _programmaticMoveTimer?.cancel();
    _mapService.removeListener(_onMapServiceChanged);
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
      _mapService.removeListener(_onMapServiceChanged);
      if (oldWidget.mapService == null) {
        _mapService.dispose();
      }
      _mapService = widget.mapService ?? MapLibreMapService();
      _mapService.addListener(_onMapServiceChanged);
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
      _cameraCenter = newPilot;
      _updateCamera();
    }

    if (widget.orientation != oldWidget.orientation ||
        (widget.orientation == MapOrientation.trackUp &&
            widget.headingDeg != oldWidget.headingDeg)) {
      _updateCamera();
    }
  }

  void _updateCamera({bool animate = false}) {
    _programmaticMoveTimer?.cancel();
    _isProgrammaticMove = true;
    final bearing = widget.orientation == MapOrientation.trackUp
        ? widget.headingDeg
        : 0.0;
    if (animate) {
      _mapService
          .animateCamera(
            position: _cameraCenter,
            zoom: _currentZoom,
            bearing: bearing,
          )
          .whenComplete(() {
            if (!mounted) return;
            _programmaticMoveTimer?.cancel();
            _programmaticMoveTimer = Timer(
              const Duration(milliseconds: 300),
              () {
                if (mounted) _isProgrammaticMove = false;
              },
            );
          });
    } else {
      _mapService
          .moveCamera(
            position: _cameraCenter,
            zoom: _currentZoom,
            bearing: bearing,
          )
          .whenComplete(() {
            if (!mounted) return;
            _programmaticMoveTimer?.cancel();
            _programmaticMoveTimer = Timer(
              const Duration(milliseconds: 100),
              () {
                if (mounted) _isProgrammaticMove = false;
              },
            );
          });
    }
  }

  void _handleZoom(double delta) {
    final newZoom = (_currentZoom + delta).clamp(1.0, 22.0);
    setState(() {
      _currentZoom = newZoom;
    });

    _mapService.moveCamera(position: _cameraCenter, zoom: newZoom);

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
      _cameraCenter = _effectivePilotPosition;
      _centerOnPilot = true;
    });
    _updateCamera(animate: true);
  }

  void _startRecenterTimer() {
    _recenterTimer?.cancel();
    _recenterTimer = Timer(const Duration(seconds: 6), _recenter);
  }

  void _onMapEvent(MapEvent event) {
    if (event is MapEventStartMoveCamera) {
      if (event.reason == CameraChangeReason.apiGesture ||
          !_isProgrammaticMove) {
        if (_centerOnPilot) {
          setState(() {
            _centerOnPilot = false;
          });
        }
        _startRecenterTimer();
      }
    } else if (event is MapEventMoveCamera) {
      if (_isProgrammaticMove) return;
      final cam = event.camera;
      final newCenter = LatLng(cam.center.lat, cam.center.lon);
      final latDiff = (_cameraCenter.latitude - newCenter.latitude).abs();
      final lngDiff = (_cameraCenter.longitude - newCenter.longitude).abs();
      final zoomDiff = (_currentZoom - cam.zoom).abs();

      if (latDiff > 1e-6 || lngDiff > 1e-6 || zoomDiff > 0.01) {
        setState(() {
          _centerOnPilot = false;
          _cameraCenter = newCenter;
          _currentZoom = cam.zoom;
        });
        _startRecenterTimer();
      }
    }
  }

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _centerOnPilot = false;
    });
    _startRecenterTimer();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final worldSize = 512.0 * math.pow(2.0, _currentZoom);
    final bearing = widget.orientation == MapOrientation.trackUp
        ? widget.headingDeg
        : 0.0;

    double dx = details.delta.dx;
    double dy = details.delta.dy;

    if (bearing != 0.0) {
      final rad = bearing * math.pi / 180.0;
      final rx = dx * math.cos(rad) - dy * math.sin(rad);
      final ry = dx * math.sin(rad) + dy * math.cos(rad);
      dx = rx;
      dy = ry;
    }

    final dLng = -dx * 360.0 / worldSize;
    final radLat = _cameraCenter.latitude * math.pi / 180.0;
    final dLat = dy * 360.0 * math.cos(radLat) / worldSize;

    final newLat = (_cameraCenter.latitude + dLat).clamp(-85.0, 85.0);
    // Use O(1) arithmetic modulo to wrap longitude to [-180, 180] without branching or loop iterations
    final newLng = (_cameraCenter.longitude + dLng + 180.0) % 360.0 - 180.0;

    final newCenter = LatLng(newLat, newLng);

    setState(() {
      _cameraCenter = newCenter;
      _centerOnPilot = false;
    });

    _updateCamera();
    _startRecenterTimer();
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
            child: Semantics(
              button: false,
              label: 'Interactive map canvas',
              child: GestureDetector(
                key: const Key('map_gesture_detector'),
                behavior: HitTestBehavior.opaque,
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                child: _buildMapBackground(_cameraCenter),
              ),
            ),
          ),

          // 2. Flight Overlays (Airspace, Flight Track, Thermals, Pilot Marker)
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _FlightOverlayPainter(
                    mapController: _mapService.controller,
                    pilotPosition: pilotPos,
                    cameraCenter: _cameraCenter,
                    orientation: widget.orientation,
                    headingDeg: widget.headingDeg,
                    zoom: _currentZoom,
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
          ),

          // 3. Fallback Badge ("No offline data" / "Online preview")
          if (_mapService.isFallbackActive)
            Positioned(
              top: 36,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _mapService.isOnlinePreviewActive
                      ? Colors.teal.shade900.withAlpha(220)
                      : Colors.amber.shade900.withAlpha(220),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: _mapService.isOnlinePreviewActive
                        ? Colors.tealAccent
                        : Colors.amberAccent,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _mapService.isOnlinePreviewActive
                          ? Icons.cloud_queue_rounded
                          : Icons.warning_amber_rounded,
                      size: 12,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _mapService.isOnlinePreviewActive
                          ? 'Online preview (No offline data)'
                          : 'No offline data (Overview fallback)',
                      style: const TextStyle(
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
          Positioned(top: 8, right: 8, child: _buildCompassIndicator()),

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
          Positioned(bottom: 8, left: 52, child: _buildScaleAndLegend()),
        ],
      ),
    );
  }

  Widget _buildMapBackground(LatLng cameraPos) {
    if (_styleJson != null) {
      return MapLibreMap(
        options: MapOptions(
          initCenter: Geographic(
            lon: cameraPos.longitude,
            lat: cameraPos.latitude,
          ),
          initZoom: _currentZoom,
          initStyle: _styleJson!,
        ),
        onMapCreated: _mapService.onMapCreated,
        onStyleLoaded: _mapService.onStyleLoaded,
        onEvent: _onMapEvent,
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
        color: Colors.black.withAlpha(200),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white24, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 30, height: 2, color: Colors.white70),
              const SizedBox(width: 4),
              Text(
                '${scaleKm.toStringAsFixed(1)} km',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'ALT: ${widget.altitudeM.toStringAsFixed(0)}m  SPD: ${widget.speedKmh.toStringAsFixed(0)}km/h',
            style: const TextStyle(
              color: Colors.cyanAccent,
              fontSize: 8,
              fontWeight: FontWeight.w600,
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
    final varioProfile = [
      3.2,
      2.4,
      1.6,
      0.8,
      0.2,
      -0.3,
      -0.8,
      -1.6,
      -2.4,
      0.5,
      1.2,
      2.8,
    ];

    final mock = <FlightPoint>[];
    for (var i = 0; i < latSteps.length; i++) {
      mock.add(
        FlightPoint(
          timestamp: now.subtract(
            Duration(minutes: (latSteps.length - i - 1) * 1),
          ),
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
    this.mapController,
    required this.pilotPosition,
    required this.cameraCenter,
    required this.orientation,
    required this.headingDeg,
    required this.zoom,
    required this.showAirspace,
    required this.showTrack,
    required this.showThermals,
    required this.flightPoints,
    required this.trackPoints,
    required this.climbRateMs,
    required this.mapTrackHistoryMinutes,
    required this.mapTrackShowOlderTail,
  });

  final MapController? mapController;
  final LatLng pilotPosition;
  final LatLng cameraCenter;
  final MapOrientation orientation;
  final double headingDeg;
  final double zoom;
  final bool showAirspace;
  final bool showTrack;
  final bool showThermals;
  final List<FlightPoint> flightPoints;
  final List<LatLng> trackPoints;
  final double climbRateMs;
  final int mapTrackHistoryMinutes;
  final bool mapTrackShowOlderTail;

  // ⚡ Bolt: Cache Paint and Path objects statically to avoid per-frame allocations
  static final Paint _airspaceFillPaint = Paint()
    ..color = const Color(0xFFEF4444).withAlpha(35)
    ..style = PaintingStyle.fill;
  static final Paint _airspaceBorderPaint = Paint()
    ..color = const Color(0xFFEF4444).withAlpha(180)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;

  static final Paint _trackPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.5
    ..strokeCap = StrokeCap.round;

  static final Paint _thermalCirclePaint = Paint()
    ..color = const Color(0xFFF97316).withAlpha(200)
    ..style = PaintingStyle.fill;
  static final Paint _thermalRingPaint = Paint()
    ..color = const Color(0xFFFACC15)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;

  static final Paint _pilotHaloPaint = Paint()
    ..color = Colors.cyanAccent.withAlpha(45)
    ..style = PaintingStyle.fill;
  static final Paint _pilotOutlinePaint = Paint()
    ..color = Colors.black87
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5;
  static final Paint _pilotBodyPaint = Paint()
    ..color = Colors.cyanAccent
    ..style = PaintingStyle.fill;
  static final Path _pilotArrowPath = Path()
    ..moveTo(0, -11)
    ..lineTo(-8, 8)
    ..lineTo(0, 3)
    ..lineTo(8, 8)
    ..close();

  Offset _toScreen(LatLng point, Size size) {
    if (mapController != null) {
      try {
        final loc = mapController!.toScreenLocation(
          Geographic(lat: point.latitude, lon: point.longitude),
        );
        if (loc.dx != 0 || loc.dy != 0) {
          return loc;
        }
      } catch (_) {}
    }

    final worldSize = 512.0 * math.pow(2.0, zoom);
    final centerLngX = (cameraCenter.longitude + 180.0) / 360.0 * worldSize;
    final pointLngX = (point.longitude + 180.0) / 360.0 * worldSize;

    double latToMercatorY(double lat) {
      final clamped = lat.clamp(-85.05112878, 85.05112878);
      final sinLat = math.sin(clamped * math.pi / 180.0);
      return (0.5 -
              math.log((1.0 + sinLat) / (1.0 - sinLat)) / (4.0 * math.pi)) *
          worldSize;
    }

    final centerLatY = latToMercatorY(cameraCenter.latitude);
    final pointLatY = latToMercatorY(point.latitude);

    var dx = pointLngX - centerLngX;
    var dy = pointLatY - centerLatY;

    if (orientation == MapOrientation.trackUp) {
      final rad = -headingDeg * math.pi / 180;
      final rotX = dx * math.cos(rad) - dy * math.sin(rad);
      final rotY = dx * math.sin(rad) + dy * math.cos(rad);
      dx = rotX;
      dy = rotY;
    }

    return Offset(size.width / 2 + dx, size.height / 2 + dy);
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

  /// Static geographic boundary coordinates for the mock airspace restriction polygon
  /// centered in the Dachstein / Krippenstein Alpine flight area (47.525°N, 13.685°E).
  static const List<LatLng> defaultMockAirspacePolygon = [
    LatLng(47.550, 13.650),
    LatLng(47.560, 13.710),
    LatLng(47.535, 13.725),
    LatLng(47.510, 13.675),
  ];

  /// Static geographic coordinates for mock thermal updraft hotspots
  /// located on sun-facing slopes in the Dachstein / Krippenstein flight area.
  static const List<(LatLng, String)> defaultMockThermalHotspots = [
    (LatLng(47.533, 13.697), '+2.8'),
    (LatLng(47.519, 13.703), '+3.4'),
    (LatLng(47.513, 13.676), '+1.9'),
  ];

  void _paintAirspace(Canvas canvas, Size size) {
    final pts = defaultMockAirspacePolygon
        .map((point) => _toScreen(point, size))
        .toList();

    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (int i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    path.close();

    canvas.drawPath(path, _airspaceFillPaint);
    canvas.drawPath(path, _airspaceBorderPaint);
  }

  void _paintFlightTrack(Canvas canvas, Size size) {
    final points = flightPoints;
    if (points.isEmpty) return;

    var p1 = _toScreen(LatLng(points[0].latitude, points[0].longitude), size);

    for (int i = 1; i < points.length; i++) {
      final p2 = _toScreen(
        LatLng(points[i].latitude, points[i].longitude),
        size,
      );
      final color = MapWidget.getVarioTrackColor(points[i].vario);

      _trackPaint.color = color;
      canvas.drawLine(p1, p2, _trackPaint);

      p1 =
          p2; // ⚡ Bolt: reuse end coordinate as start coordinate for next iteration to avoid redundant _toScreen calls
    }
  }

  void _paintThermals(Canvas canvas, Size size) {
    for (final th in defaultMockThermalHotspots) {
      final pos = _toScreen(th.$1, size);
      canvas.drawCircle(pos, 8, _thermalCirclePaint);
      canvas.drawCircle(pos, 8, _thermalRingPaint);
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
    canvas.drawCircle(Offset.zero, 18, _pilotHaloPaint);

    // Glider Arrow
    canvas.drawPath(_pilotArrowPath, _pilotOutlinePaint);
    canvas.drawPath(_pilotArrowPath, _pilotBodyPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FlightOverlayPainter old) {
    return old.pilotPosition != pilotPosition ||
        old.cameraCenter != cameraCenter ||
        old.orientation != orientation ||
        old.headingDeg != headingDeg ||
        old.zoom != zoom ||
        old.showAirspace != showAirspace ||
        old.showTrack != showTrack ||
        old.showThermals != showThermals ||
        old.flightPoints != flightPoints ||
        old.trackPoints != trackPoints ||
        old.climbRateMs != climbRateMs ||
        old.mapTrackHistoryMinutes != mapTrackHistoryMinutes ||
        old.mapTrackShowOlderTail != mapTrackShowOlderTail;
  }
}
