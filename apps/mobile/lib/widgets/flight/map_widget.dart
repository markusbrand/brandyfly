import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

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
  final VoidCallback? onZoomIn;
  final VoidCallback? onZoomOut;
  final ValueChanged<double>? onZoomChanged;

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
                  tileProvider: BrandyFlyTileProvider(
                    userAgent: 'BrandyFly/0.1.0 (rocks.brandstaetter.brandyfly)',
                  ),
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

                // Airspace Polygons (CTR / TMA)
                if (widget.showAirspace)
                  PolygonLayer(
                    polygons: _buildAirspaces(pilotPos),
                  ),

                // GPS Breadcrumb Flight Track
                if (widget.showTrack)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _effectiveTrackPoints,
                        color: _getTrackColor(widget.climbRateMs),
                        strokeWidth: 3.5,
                        borderColor: Colors.black87,
                        borderStrokeWidth: 1.5,
                      ),
                    ],
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
          CustomPaint(
            size: const Size(26, 26),
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

class _PilotArrowPainter extends CustomPainter {
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
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black87
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Body
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.cyanAccent
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_PilotArrowPainter old) => false;
}
