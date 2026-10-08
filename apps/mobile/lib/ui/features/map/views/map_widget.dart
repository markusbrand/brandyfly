import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:maplibre/maplibre.dart' hide Marker;

import '../../../../models/flight_model.dart';
import '../../../../models/lat_lng.dart';
import '../../../../domain/models/ui_config.dart';
import '../../../../domain/thermal/kk7_provider.dart';
import '../../../../domain/thermal/thermal_layer_spec.dart';
import '../../../../domain/thermal/thermal_variant_resolver.dart';
import '../../../../services/maplibre_map_service.dart';
import '../../../../services/region_manager_service.dart';
import '../platform/map_renderer_availability.dart';
import '../view_models/map_camera_view_model.dart';

/// Paragliding Map Widget with MapLibre GL offline vector tile rendering,
/// Copernicus DEM hillshade terrain relief, local PMTiles fallback detection,
/// KK7 thermal probability heatmap, airspace polygons, breadcrumb tracks, and
/// pilot position.
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
    this.regionManager,
    this.mapService,
    this.cameraViewModel,
    this.cameraId,
    this.showBuiltInControls = true,
    this.thermalSeason = ThermalSeason.auto,
    this.thermalTimeOfDay = ThermalTimeOfDay.auto,
    this.thermalOpacity = WidgetPlacementModel.defaultThermalOpacity,
    this.clock,
    this.thermalReevaluateInterval = const Duration(seconds: 60),
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
  final RegionManagerService? regionManager;
  final MapLibreMapService? mapService;

  /// Optional externally owned camera state. When null the widget creates its
  /// own [MapCameraViewModel].
  final MapCameraViewModel? cameraViewModel;

  /// Id under which the camera is registered in the nearest [MapCameraScope]
  /// so placeable map control widgets can drive it.
  final String? cameraId;

  /// Whether the built-in zoom / recenter HUD buttons are rendered.
  final bool showBuiltInControls;

  /// KK7 thermal heatmap season setting (only used when [showThermals]).
  final ThermalSeason thermalSeason;

  /// KK7 thermal heatmap time-of-day setting.
  final ThermalTimeOfDay thermalTimeOfDay;

  /// KK7 thermal heatmap layer opacity (0.1-1.0).
  final double thermalOpacity;

  /// Wall clock used for automatic variant selection (tests inject one).
  final DateTime Function()? clock;

  /// How often automatic season / time-of-day selection is re-evaluated.
  final Duration thermalReevaluateInterval;

  /// Pilot displacement that forces an immediate variant re-evaluation.
  static const double thermalReevaluateDistanceKm = 50.0;

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
  late MapLibreMapService _mapService;
  late MapCameraViewModel _camera;
  bool _ownsCamera = false;
  MapCameraRegistry? _registry;
  String? _registeredId;
  late double _currentZoom;
  late bool _centerOnPilot;
  late int _seenRecenterRequests;
  late LatLng _cameraCenter;
  String? _styleJson;
  bool _isProgrammaticMove = false;
  Timer? _programmaticMoveTimer;

  // KK7 thermal heatmap state
  ThermalLayerSpec? _thermalSpec;
  Timer? _thermalTimer;
  LatLng? _lastKnownPilot;
  LatLng? _thermalEvalPosition;

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
    _attachCamera(widget.cameraViewModel);
    _cameraCenter = _effectivePilotPosition;
    _lastKnownPilot = widget.pilotPosition;
    _thermalSpec = _computeThermalSpec();
    _syncThermalTimer();
    _initMapStyle();
  }

  DateTime _now() => (widget.clock ?? DateTime.now)();

  /// Resolves the desired heatmap layer, or null when thermals are hidden.
  ThermalLayerSpec? _computeThermalSpec() {
    if (!widget.showThermals) return null;
    _thermalEvalPosition = widget.pilotPosition ?? _lastKnownPilot;
    final variant = ThermalVariantResolver.resolve(
      season: widget.thermalSeason,
      timeOfDay: widget.thermalTimeOfDay,
      now: _now(),
      gpsFix: widget.pilotPosition,
      lastKnownPosition: _lastKnownPilot,
      mapCenter: _cameraCenter,
    );
    return ThermalLayerSpec(
      variant: variant,
      opacity: widget.thermalOpacity.clamp(0.1, 1.0),
    );
  }

  /// Re-resolves the heatmap variant and swaps the layer if it changed.
  void _refreshThermal() {
    if (!mounted) return;
    final spec = _computeThermalSpec();
    if (spec == _thermalSpec) return;
    setState(() => _thermalSpec = spec);
    _mapService.setThermalLayer(spec);
  }

  bool get _thermalNeedsTimer =>
      widget.showThermals &&
      (widget.thermalSeason == ThermalSeason.auto ||
          widget.thermalTimeOfDay == ThermalTimeOfDay.auto);

  void _syncThermalTimer() {
    if (_thermalNeedsTimer) {
      _thermalTimer ??= Timer.periodic(
        widget.thermalReevaluateInterval,
        (_) => _refreshThermal(),
      );
    } else {
      _thermalTimer?.cancel();
      _thermalTimer = null;
    }
  }

  static double _distanceKm(LatLng a, LatLng b) {
    const r = 6371.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180.0;
    final dLon = (b.longitude - a.longitude) * math.pi / 180.0;
    final h =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(a.latitude * math.pi / 180.0) *
            math.cos(b.latitude * math.pi / 180.0) *
            math.pow(math.sin(dLon / 2), 2);
    return 2 * r * math.asin(math.sqrt(h.toDouble()));
  }

  void _attachCamera(MapCameraViewModel? external) {
    if (external != null) {
      _camera = external;
      _ownsCamera = false;
    } else {
      _camera = MapCameraViewModel(initialZoom: widget.initialZoom);
      _ownsCamera = true;
    }
    _currentZoom = _camera.zoom;
    _centerOnPilot = _camera.centerLocked;
    _seenRecenterRequests = _camera.recenterRequests;
    _camera.addListener(_onCameraChanged);
  }

  void _detachCamera() {
    _camera.removeListener(_onCameraChanged);
    _unregister();
    if (_ownsCamera) _camera.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncRegistration();
  }

  void _syncRegistration() {
    final registry = MapCameraScope.maybeOf(context);
    final id = widget.cameraId;
    if (identical(registry, _registry) && id == _registeredId) {
      if (registry != null && id != null) registry.register(id, _camera);
      return;
    }
    _unregister();
    _registry = registry;
    _registeredId = id;
    if (registry != null && id != null) registry.register(id, _camera);
  }

  void _unregister() {
    final id = _registeredId;
    if (id != null) _registry?.unregister(id, _camera);
    _registry = null;
    _registeredId = null;
  }

  void _onMapServiceChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  /// Applies camera view model changes (from built-in buttons, map control
  /// widgets or the inactivity timer) to the native map camera.
  void _onCameraChanged() {
    if (!mounted) return;
    final oldZoom = _currentZoom;
    final newZoom = _camera.zoom;
    final recenterRequested = _camera.recenterRequests != _seenRecenterRequests;
    _seenRecenterRequests = _camera.recenterRequests;

    setState(() {
      _currentZoom = newZoom;
      _centerOnPilot = _camera.centerLocked;
      if (recenterRequested) {
        _cameraCenter = _effectivePilotPosition;
      }
    });

    if (recenterRequested) {
      _updateCamera(animate: true);
    } else if (newZoom != oldZoom && !_syncingGestureZoom) {
      _mapService.moveCamera(position: _cameraCenter, zoom: newZoom);
    }

    if (newZoom != oldZoom) {
      widget.onZoomChanged?.call(newZoom);
      if (!_syncingGestureZoom) {
        if (newZoom > oldZoom) {
          widget.onZoomIn?.call();
        } else {
          widget.onZoomOut?.call();
        }
      }
    }
  }

  bool _syncingGestureZoom = false;

  Future<void> _initMapStyle() async {
    String? effectiveRegion = widget.regionId;
    if (effectiveRegion == null && widget.regionManager != null) {
      final pos = widget.pilotPosition ?? _lastKnownPilot;
      if (pos != null) {
        final downloaded = await widget.regionManager!.getDownloadedRegions();
        for (final r in downloaded) {
          final b = r.bounds;
          if (b != null &&
              b.isValid &&
              pos.latitude >= b.south &&
              pos.latitude <= b.north &&
              pos.longitude >= b.west &&
              pos.longitude <= b.east) {
            effectiveRegion = r.id;
            break;
          }
        }
      }
    }
    final style = await _mapService.buildStyleJson(
      regionId: effectiveRegion,
      thermal: _thermalSpec,
    );
    if (mounted) {
      setState(() {
        _styleJson = style;
      });
    }
  }

  @override
  void dispose() {
    _programmaticMoveTimer?.cancel();
    _thermalTimer?.cancel();
    _mapService.removeListener(_onMapServiceChanged);
    _detachCamera();
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

    if (!identical(widget.cameraViewModel, oldWidget.cameraViewModel)) {
      _detachCamera();
      _attachCamera(widget.cameraViewModel);
      _syncRegistration();
    } else if (widget.cameraId != oldWidget.cameraId) {
      _syncRegistration();
    }

    if (widget.initialZoom != oldWidget.initialZoom) {
      _camera.resetZoom(widget.initialZoom);
      _currentZoom = _camera.zoom;
      _updateCamera();
    }

    if (widget.pilotPosition != null) _lastKnownPilot = widget.pilotPosition;
    final thermalSettingsChanged =
        widget.showThermals != oldWidget.showThermals ||
        widget.thermalSeason != oldWidget.thermalSeason ||
        widget.thermalTimeOfDay != oldWidget.thermalTimeOfDay ||
        widget.thermalOpacity != oldWidget.thermalOpacity;
    if (thermalSettingsChanged ||
        widget.thermalReevaluateInterval !=
            oldWidget.thermalReevaluateInterval) {
      _thermalTimer?.cancel();
      _thermalTimer = null;
      _syncThermalTimer();
    }
    final evalPos = _thermalEvalPosition;
    final jumped =
        widget.pilotPosition != null &&
        (evalPos == null ||
            _distanceKm(evalPos, widget.pilotPosition!) >
                MapWidget.thermalReevaluateDistanceKm);
    if (thermalSettingsChanged || (widget.showThermals && jumped)) {
      // A rebuild follows didUpdateWidget, so plain assignment is enough.
      final spec = _computeThermalSpec();
      if (spec != _thermalSpec) {
        _thermalSpec = spec;
        _mapService.setThermalLayer(spec);
      }
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

  void _handleZoom(double delta) => _camera.zoomBy(delta);

  void _recenter() => _camera.recenter();

  void _onMapEvent(MapEvent event) {
    if (event is MapEventStartMoveCamera) {
      if (event.reason == CameraChangeReason.apiGesture ||
          !_isProgrammaticMove) {
        _camera.beginManualPan();
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
          _cameraCenter = newCenter;
        });
        _camera.beginManualPan();
        _syncingGestureZoom = true;
        try {
          _camera.syncZoomFromGesture(cam.zoom);
        } finally {
          _syncingGestureZoom = false;
        }
      }
    }
  }

  void _onPanStart(DragStartDetails details) {
    _camera.beginManualPan();
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
    });
    _camera.beginManualPan();

    _updateCamera();
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

          // 2. Flight Overlays (Airspace, Flight Track, Pilot Marker). The
          //    KK7 thermal heatmap is a MapLibre raster layer below these.
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
          if (widget.showBuiltInControls)
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
                    onPressed: _camera.canZoomIn
                        ? () => _handleZoom(_camera.zoomStep)
                        : null,
                  ),
                  const SizedBox(height: 4),
                  _mapActionButton(
                    key: const Key('btn_map_zoom_out'),
                    icon: Icons.remove,
                    tooltip: 'Zoom Out',
                    onPressed: _camera.canZoomOut
                        ? () => _handleZoom(-_camera.zoomStep)
                        : null,
                  ),
                ],
              ),
            ),

          // 7. Dynamic Scale Bar & Altitude / Speed HUD
          Positioned(bottom: 8, left: 52, child: _buildScaleAndLegend()),

          // 8. KK7 thermal heatmap attribution (CC BY-NC-SA 4.0)
          if (_thermalSpec != null)
            Positioned(
              bottom: 46,
              left: 52,
              right: 44,
              child: IgnorePointer(
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Container(
                    key: const Key('thermal_attribution'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(150),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Text(
                      Kk7Provider.attributionText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white70, fontSize: 8),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMapBackground(LatLng cameraPos) {
    if (_styleJson != null && isMapRendererAvailable) {
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
    required VoidCallback? onPressed,
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

/// Flight overlay painter that renders airspace polygons, vario flight track
/// and pilot position marker.
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

    // 3. Pilot Position Marker
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

  void _paintAirspace(Canvas canvas, Size size) {
    if (defaultMockAirspacePolygon.isEmpty) return;

    // ⚡ Bolt: Avoid list allocation in hot path by computing points within loop
    final path = Path();
    for (int i = 0; i < defaultMockAirspacePolygon.length; i++) {
      final pt = _toScreen(defaultMockAirspacePolygon[i], size);
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();

    canvas.drawPath(path, _airspaceFillPaint);
    canvas.drawPath(path, _airspaceBorderPaint);
  }

  void _paintFlightTrack(Canvas canvas, Size size) {
    final points = flightPoints;
    if (points.length < 2) return;

    // ⚡ Bolt: Calculate the first point outside the loop and reuse p2 as p1 in the next iteration
    // to avoid redundant coordinate transformations on the 60Hz rendering hot-path.
    var p1 = _toScreen(LatLng(points[0].latitude, points[0].longitude), size);

    for (int i = 1; i < points.length; i++) {
      final p2 = _toScreen(
        LatLng(points[i].latitude, points[i].longitude),
        size,
      );
      final color = MapWidget.getVarioTrackColor(points[i].vario);

      _trackPaint.color = color;
      canvas.drawLine(p1, p2, _trackPaint);

      p1 = p2;
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
        old.flightPoints != flightPoints ||
        old.trackPoints != trackPoints ||
        old.climbRateMs != climbRateMs ||
        old.mapTrackHistoryMinutes != mapTrackHistoryMinutes ||
        old.mapTrackShowOlderTail != mapTrackShowOlderTail;
  }
}
