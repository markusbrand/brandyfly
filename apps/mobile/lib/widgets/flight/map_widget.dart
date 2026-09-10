import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../../models/flight_model.dart';
import '../../models/ui_config.dart';
import '../../services/map_tile_service.dart';

/// Paragliding Map Widget with OpenStreetMap & OpenTopoMap tile rendering,
/// offline tile caching, airspace polygons, thermal overlays, breadcrumb tracks, and pilot position.
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
    this.initialZoom = 13.5,
    this.pilotPosition,
    this.trackPoints,
    this.flightPoints,
    this.mapTrackHistoryMinutes = 10,
    this.mapTrackShowOlderTail = true,
    this.onZoomIn,
    this.onZoomOut,
    this.onZoomChanged,
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
  late final MapController _mapController;
  late double _currentZoom;
  bool _centerOnPilot = true;

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

  late final BrandyFlyTileProvider _tileProvider = BrandyFlyTileProvider();

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _currentZoom = widget.initialZoom;
  }

  @override
  void didUpdateWidget(MapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialZoom != oldWidget.initialZoom) {
      _currentZoom = widget.initialZoom;
      try {
        final targetCenter = _centerOnPilot
            ? _effectivePilotPosition
            : _mapController.camera.center;
        _mapController.move(targetCenter, _currentZoom);
      } catch (_) {}
    }

    final oldPilot = oldWidget.pilotPosition ?? _defaultPilotPosition;
    final newPilot = _effectivePilotPosition;
    if (_centerOnPilot && oldPilot != newPilot) {
      try {
        _mapController.move(newPilot, _mapController.camera.zoom);
      } catch (_) {}
    }

    if (widget.orientation != oldWidget.orientation ||
        (widget.orientation == MapOrientation.trackUp &&
            widget.headingDeg != oldWidget.headingDeg)) {
      try {
        if (widget.orientation == MapOrientation.trackUp) {
          _mapController.rotate(-widget.headingDeg);
        } else if (widget.orientation == MapOrientation.northUp) {
          _mapController.rotate(0.0);
        }
      } catch (_) {}
    }
  }

  void _handleZoom(double delta) {
    final newZoom = (_currentZoom + delta).clamp(1.0, 22.0);
    setState(() {
      _currentZoom = newZoom;
    });

    try {
      final center = _centerOnPilot
          ? _effectivePilotPosition
          : _mapController.camera.center;
      _mapController.move(center, newZoom);
    } catch (_) {}

    widget.onZoomChanged?.call(newZoom);
    if (delta > 0) {
      widget.onZoomIn?.call();
    } else {
      widget.onZoomOut?.call();
    }
  }

  void _recenter() {
    setState(() {
      _centerOnPilot = true;
    });
    try {
      _mapController.move(_effectivePilotPosition, _mapController.camera.zoom);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final tileConfig = MapTileStyleConfig.forStyle(
      widget.style,
      showContours: widget.showContours,
    );
    final pilotPos = _effectivePilotPosition;
    final initialRotation = widget.orientation == MapOrientation.trackUp
        ? -widget.headingDeg
        : 0.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        children: [
          // 1. FlutterMap Tile Layer & Paragliding Vector Overlays
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: pilotPos,
                initialZoom: _currentZoom,
                minZoom: 1.0,
                maxZoom: 22.0,
                initialRotation: initialRotation,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
                onPositionChanged: (camera, hasGesture) {
                  if (hasGesture && _centerOnPilot) {
                    setState(() {
                      _centerOnPilot = false;
                    });
                  }
                  if (camera.zoom != _currentZoom) {
                    _currentZoom = camera.zoom;
                  }
                },
              ),
              children: [
                // Base OSM / OpenTopoMap Tile Layer
                TileLayer(
                  key: ValueKey(
                    'tile_layer_${widget.style.name}_${widget.showContours}_${tileConfig.urlTemplate}',
                  ),
                  urlTemplate: tileConfig.urlTemplate,
                  fallbackUrl: tileConfig.fallbackUrl,
                  subdomains: tileConfig.subdomains,
                  tileProvider: _tileProvider,
                  userAgentPackageName: 'rocks.brandstaetter.brandyfly',
                  maxNativeZoom: tileConfig.maxZoom.toInt(),
                  minNativeZoom: tileConfig.minZoom.toInt(),
                  maxZoom: 22.0,
                  minZoom: 1.0,
                  panBuffer: 2,
                  keepBuffer: 6,
                  tileDisplay: const TileDisplay.fadeIn(
                    duration: Duration(milliseconds: 100),
                  ),
                  errorTileCallback: (tile, error, stackTrace) {
                    debugPrint('[MapTile Error] ${tile.coordinates}: $error');
                  },
                ),

                // Topographic Elevation Contours & Mountain Peaks (when showContours is true)
                if (widget.showContours) ...[
                  PolylineLayer(
                    polylines: _buildContourPolylines(pilotPos),
                  ),
                  MarkerLayer(
                    markers: _buildPeakMarkers(pilotPos),
                  ),
                ],

                // Airspace Polygons (CTR / TMA)
                if (widget.showAirspace)
                  PolygonLayer(
                    polygons: _buildAirspaces(pilotPos),
                  ),

                // GPS Breadcrumb Flight Track
                if (widget.showTrack)
                  PolylineLayer(
                    polylines: _buildTrackPolylines(),
                  ),

                // Thermal Updraft Markers
                if (widget.showThermals)
                  MarkerLayer(
                    markers: _buildThermalMarkers(pilotPos),
                  ),

                // Pilot Position Marker with Heading Rotation
                MarkerLayer(
                  markers: [
                    Marker(
                      point: pilotPos,
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      child: _buildPilotMarker(),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. Map Header Badge
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

          // 3. North / Orientation Compass Widget
          Positioned(
            top: 8,
            right: 8,
            child: _buildCompassIndicator(),
          ),

          // 4. In-flight Zoom Steppers & Recenter Toolbar
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

          // 5. Dynamic Scale Bar & Altitude / Speed HUD
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

  Color _getTrackColor(double climbRate) {
    if (climbRate >= 0.2) {
      return const Color(0xFF22C55E); // Green (Lift)
    } else if (climbRate <= -0.2) {
      return const Color(0xFFEF4444); // Red (Sink)
    }
    return const Color(0xFFEAB308); // Yellow (Glide)
  }

  // ---------------------------------------------------------------------------
  // Vario color-graded gradient flight track (tasks 3.1-3.5)
  // ---------------------------------------------------------------------------

  /// Builds the flight-track polylines.
  ///
  /// Uses vario-attributed time-windowed [FlightPoint] data when available to
  /// render continuous color-graded, batched segments. Falls back to a single
  /// uniform-color polyline based on instantaneous climb rate otherwise.
  List<Polyline> _buildTrackPolylines() {
    final points = _effectiveFlightPoints;
    if (points.isEmpty) {
      return [
        Polyline(
          points: _effectiveTrackPoints,
          color: _getTrackColor(widget.climbRateMs),
          strokeWidth: 3.5,
          borderColor: Colors.black87,
          borderStrokeWidth: 1.5,
        ),
      ];
    }
    return _buildGradientPolylines(points);
  }

  /// Partitions [points] into an active time window and a historical baseline,
  /// then batches contiguous points with near-identical colors into polyline
  /// segments for [PolylineLayer] performance.
  List<Polyline> _buildGradientPolylines(List<FlightPoint> points) {
    final polylines = <Polyline>[];

    final trimmed = points.length > 1
        ? points.sublist(math.max(0, points.length - 600))
        : points;
    if (trimmed.isEmpty) return polylines;

    // Determine the active time window (0 minutes = full flight).
    final minutes = widget.mapTrackHistoryMinutes;
    final cutoff =
        minutes > 0 ? trimmed.last.timestamp.subtract(Duration(minutes: minutes)) : trimmed.first.timestamp;

    final activePoints = <FlightPoint>[];
    final oldPoints = <FlightPoint>[];
    for (final fp in trimmed) {
      if (minutes > 0 && fp.timestamp.isBefore(cutoff)) {
        oldPoints.add(fp);
      } else {
        activePoints.add(fp);
      }
    }

    // Muted/neutral baseline for points older than the active window.
    if (widget.mapTrackShowOlderTail && oldPoints.length > 1) {
      polylines.add(
        Polyline(
          points: oldPoints.map((fp) => LatLng(fp.latitude, fp.longitude)).toList(),
          color: const Color(0xFF94A3B8).withAlpha(90),
          strokeWidth: 1.4,
          borderColor: Colors.black54,
          borderStrokeWidth: 0.8,
        ),
      );
    }

    // High-contrast gradient segments for the active time window.
    polylines.addAll(_segmentAndBatch(activePoints));
    return polylines;
  }

  /// Batches contiguous [FlightPoint]s whose vario-derived color is within the
  /// configured delta into a single [Polyline]. Adjacent segments share their
  /// boundary point so the trail renders as one visually connected line.
  List<Polyline> _segmentAndBatch(List<FlightPoint> points) {
    if (points.isEmpty) return const [];
    if (points.length == 1) {
      return [
        Polyline(
          points: [LatLng(points.first.latitude, points.first.longitude)],
          color: MapWidget.getVarioTrackColor(points.first.vario),
          strokeWidth: 3.5,
          borderColor: Colors.black87,
          borderStrokeWidth: 1.5,
        ),
      ];
    }

    const deltaThreshold = 0.0075;
    final polylines = <Polyline>[];
    var segmentStart = 0;
    var segmentColor = MapWidget.getVarioTrackColor(points.first.vario);

    for (var i = 1; i < points.length; i++) {
      final prevColor = MapWidget.getVarioTrackColor(points[i - 1].vario);
      final curColor = MapWidget.getVarioTrackColor(points[i].vario);
      final isSplit = _colorDistance(prevColor, curColor) > deltaThreshold;

      if (isSplit) {
        polylines.add(
          Polyline(
            points: List.generate(
              i - segmentStart + 1,
              (j) => LatLng(
                points[segmentStart + j].latitude,
                points[segmentStart + j].longitude,
              ),
            ),
            color: segmentColor,
            strokeWidth: 3.5,
            borderColor: Colors.black87,
            borderStrokeWidth: 1.5,
          ),
        );
        segmentStart = i - 1;
        segmentColor = curColor;
      }
    }

    polylines.add(
      Polyline(
        points: List.generate(
          points.length - segmentStart,
          (j) => LatLng(
            points[segmentStart + j].latitude,
            points[segmentStart + j].longitude,
          ),
        ),
        color: segmentColor,
        strokeWidth: 3.5,
        borderColor: Colors.black87,
        borderStrokeWidth: 1.5,
      ),
    );

    return polylines;
  }

  double _colorDistance(Color a, Color b) {
    final dr = a.r - b.r;
    final dg = a.g - b.g;
    final db = a.b - b.b;
    return math.sqrt(dr * dr + dg * dg + db * db);
  }

  /// Generates deterministic mock vario-attributed flight points along the
  /// pilot's track for local simulation and preview when no telemetry exists.
  List<FlightPoint> _buildMockFlightPoints(LatLng p) {
    final now = DateTime.now();
    final latSteps = [0.015, 0.010, 0.006, 0.003, 0.001, 0.0];
    final lngSteps = [0.018, 0.012, 0.008, 0.003, 0.001, 0.0];

    // Simulate a thermal/glide cycle: strong lift -> neutral -> sink -> lift.
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

  List<Polygon> _buildAirspaces(LatLng center) {
    return [
      Polygon(
        points: [
          LatLng(center.latitude + 0.025, center.longitude - 0.035),
          LatLng(center.latitude + 0.035, center.longitude + 0.025),
          LatLng(center.latitude + 0.010, center.longitude + 0.040),
          LatLng(center.latitude - 0.015, center.longitude - 0.010),
        ],
        color: const Color(0xFFEF4444).withAlpha(35),
        borderColor: const Color(0xFFEF4444).withAlpha(180),
        borderStrokeWidth: 1.5,
        label: 'CTR INNSBRUCK [D] GND-FL120',
        labelStyle: const TextStyle(
          color: Color(0xFFFCA5A5),
          fontSize: 8,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    ];
  }

  List<Marker> _buildPeakMarkers(LatLng center) {
    final peaks = [
      (LatLng(center.latitude - 0.050, center.longitude - 0.079), 'Hoher Dachstein', '2995m'),
      (LatLng(center.latitude, center.longitude), 'Krippenstein', '2108m'),
      (LatLng(center.latitude - 0.040, center.longitude - 0.050), 'Gjaidstein', '2794m'),
      (LatLng(center.latitude + 0.070, center.longitude + 0.020), 'Sarstein', '1975m'),
      (LatLng(center.latitude + 0.050, center.longitude - 0.070), 'Plassen', '1953m'),
      (LatLng(center.latitude + 0.130, center.longitude + 0.090), 'Loser', '1838m'),
    ];

    return peaks.map((pk) {
      return Marker(
        point: pk.$1,
        width: 100,
        height: 24,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(200),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFFFBBF24), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.change_history, size: 9, color: Color(0xFFFBBF24)),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  '${pk.$2} ${pk.$3}',
                  style: const TextStyle(
                    color: Color(0xFFFBBF24),
                    fontSize: 7.5,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  List<Polyline> _buildContourPolylines(LatLng center) {
    final polylines = <Polyline>[];
    final elevations = [
      (0.009, 0.013, const Color(0xFFD97706).withAlpha(120), 1.2),
      (0.018, 0.025, const Color(0xFFF59E0B).withAlpha(160), 1.6),
      (0.028, 0.038, const Color(0xFFD97706).withAlpha(140), 1.4),
      (0.040, 0.052, const Color(0xFFF59E0B).withAlpha(180), 2.0),
      (0.055, 0.070, const Color(0xFFFACC15).withAlpha(200), 2.2),
    ];

    for (final el in elevations) {
      final points = <LatLng>[];
      const count = 24;
      for (int i = 0; i <= count; i++) {
        final angle = (i * 2 * math.pi) / count;
        final noiseLat = math.sin(angle * 3) * (el.$1 * 0.15);
        final noiseLng = math.cos(angle * 4) * (el.$2 * 0.15);
        final lat = center.latitude + (el.$1 + noiseLat) * math.cos(angle);
        final lng = center.longitude + (el.$2 + noiseLng) * math.sin(angle);
        points.add(LatLng(lat, lng));
      }
      polylines.add(
        Polyline(
          points: points,
          color: el.$3,
          strokeWidth: el.$4,
        ),
      );
    }
    return polylines;
  }

  List<Marker> _buildThermalMarkers(LatLng center) {
    final hotspots = [
      (LatLng(center.latitude + 0.008, center.longitude + 0.012), '+2.8 m/s'),
      (LatLng(center.latitude - 0.006, center.longitude + 0.018), '+3.4 m/s'),
      (LatLng(center.latitude - 0.012, center.longitude - 0.009), '+1.9 m/s'),
    ];

    return hotspots.map((th) {
      return Marker(
        point: th.$1,
        width: 60,
        height: 40,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF97316).withAlpha(200),
                border: Border.all(color: const Color(0xFFFACC15), width: 1.5),
              ),
              child: const Center(
                child: Icon(Icons.north, size: 8, color: Colors.white),
              ),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(190),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                th.$2,
                style: const TextStyle(
                  color: Color(0xFFFDBA74),
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildPilotMarker() {
    return Transform.rotate(
      angle: widget.headingDeg * math.pi / 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.cyanAccent.withAlpha(45),
            ),
          ),
          const CustomPaint(
            size: Size(26, 26),
            painter: _PilotArrowPainter(),
          ),
        ],
      ),
    );
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
}

class _PilotArrowPainter extends CustomPainter {
  const _PilotArrowPainter();

  // ⚡ Bolt: Cache Paint objects statically to avoid per-frame allocations during animations
  static final Paint _outlinePaint = Paint()
    ..color = Colors.black87
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5;

  static final Paint _bodyPaint = Paint()
    ..color = Colors.cyanAccent
    ..style = PaintingStyle.fill;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final path = Path();
    path.moveTo(center.dx, center.dy - 11);
    path.lineTo(center.dx - 8, center.dy + 8);
    path.lineTo(center.dx, center.dy + 3);
    path.lineTo(center.dx + 8, center.dy + 8);
    path.close();

    // Outline
    canvas.drawPath(path, _outlinePaint);

    // Body
    canvas.drawPath(path, _bodyPaint);
  }

  @override
  bool shouldRepaint(_PilotArrowPainter old) => false;
}
