import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:maplibre/maplibre.dart' hide Marker;
import 'package:provider/provider.dart';

import '../../../../domain/map_motion/motion_smoother.dart';
import '../../../../domain/models/cockpit_telemetry.dart';
import '../../../../models/flight_model.dart';
import '../../../../models/lat_lng.dart';
import '../../../../domain/models/ui_config.dart';
import '../../../../domain/thermal/kk7_provider.dart';
import '../../../../domain/thermal/thermal_layer_spec.dart';
import '../../../../domain/thermal/thermal_variant_resolver.dart';
import '../../../../services/airspace_service.dart';
import '../../../../services/maplibre_map_service.dart';
import '../../../../services/region_manager_service.dart';
import '../../../../widgets/flight/airspace_map_layer.dart';
import '../layers/map_flight_layers.dart';
import '../layers/vario_track_palette.dart';
import '../platform/map_renderer_availability.dart';
import '../view_models/map_camera_view_model.dart';
import '../view_models/map_motion_controller.dart';

/// Paragliding Map Widget with MapLibre GL offline vector tile rendering,
/// Copernicus DEM hillshade terrain relief, local PMTiles fallback detection,
/// KK7 thermal probability heatmap, airspace polygons, breadcrumb tracks, and
/// pilot position.
///
/// The camera follows a display-rate smoothed pilot position
/// ([MapMotionController]); track, mock airspace and the free-floating pilot
/// marker are native MapLibre layers ([MapFlightLayers]) so they stay locked
/// to the base map. Telemetry can be supplied either as discrete constructor
/// values or, without rebuilding the widget on every tick, as a [telemetry]
/// listenable.
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
    this.telemetry,
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

  /// Live telemetry. When set it overrides [altitudeM], [speedKmh],
  /// [headingDeg], [pilotPosition] and [flightPoints], and the widget
  /// subscribes to it directly instead of being rebuilt on every tick.
  final ValueListenable<CockpitTelemetry>? telemetry;
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

  /// Max update rate of the native pilot symbol while the map is panned.
  static const Duration pilotSymbolInterval = Duration(milliseconds: 66);

  /// Continuous piecewise color interpolation for the vario gradient flight
  /// track. Maps vertical speed (m/s) to a lift/sink colour stop.
  static Color getVarioTrackColor(double vario) =>
      VarioTrackPalette.colorFor(vario);

  @override
  State<MapWidget> createState() => MapWidgetState();
}

/// State of [MapWidget]; public members are exposed for tests only.
class MapWidgetState extends State<MapWidget> with TickerProviderStateMixin {
  late MapLibreMapService _mapService;
  late MapCameraViewModel _camera;
  bool _ownsCamera = false;
  MapCameraRegistry? _registry;
  String? _registeredId;
  late double _currentZoom;
  late bool _centerOnPilot;
  late int _seenRecenterRequests;
  String? _styleJson;

  late final MapMotionController _motion;
  final MapFlightLayers _layers = MapFlightLayers();
  final ValueNotifier<MotionFrame?> _frame = ValueNotifier(null);
  final ValueNotifier<(int, int)> _hud = ValueNotifier((0, 0));
  late final ValueNotifier<(LatLng, double)> _cameraView;

  /// Camera center / bearing currently shown (follow or manual pan).
  late LatLng _cameraCenter;
  double _cameraBearing = 0;
  double _viewportHeight = 0;

  // Last camera written to the native map (dedupe).
  LatLng? _writtenCenter;
  double? _writtenZoom;
  double? _writtenBearing;
  double? _writtenPadding;
  Duration? _lastPilotSymbolUpdate;

  ValueListenable<CockpitTelemetry>? _subscribedTelemetry;
  List<FlightPoint>? _lastFlightPoints;
  LatLng? _mockAnchor;
  List<FlightPoint> _mockPoints = const [];

  // KK7 thermal heatmap state
  ThermalLayerSpec? _thermalSpec;
  Timer? _thermalTimer;
  LatLng? _lastKnownPilot;
  LatLng? _thermalEvalPosition;

  // Default Alpine launch reference coordinates (Dachstein / Krippenstein)
  static const LatLng _defaultPilotPosition = LatLng(47.525, 13.685);

  /// Camera center currently presented (tests).
  @visibleForTesting
  LatLng get cameraCenter => _cameraCenter;

  /// Latest smoothed frame (diagnostics, profiling harness and tests).
  MotionFrame? get motionFrame => _frame.value;

  /// Native overlay manager (diagnostics, profiling harness and tests).
  MapFlightLayers get flightLayers => _layers;

  /// Motion controller (tests).
  @visibleForTesting
  MapMotionController get motion => _motion;

  /// Camera state driving this map (zoom, center-lock, recenter).
  MapCameraViewModel get camera => _camera;

  CockpitTelemetry? get _t => widget.telemetry?.value;

  LatLng? get _rawPilotPosition =>
      widget.telemetry != null ? _t?.pilotPosition : widget.pilotPosition;

  LatLng get _effectivePilotPosition =>
      _rawPilotPosition ?? _defaultPilotPosition;

  double get _heading =>
      widget.telemetry != null ? _t!.effectiveHeading : widget.headingDeg;

  double get _speed => widget.telemetry != null ? _t!.speed : widget.speedKmh;

  double get _altitude =>
      widget.telemetry != null ? _t!.altitude : widget.altitudeM;

  bool get _stale => widget.telemetry != null && _t!.isStale;

  List<FlightPoint>? get _rawFlightPoints =>
      widget.telemetry != null ? _t?.flightPoints : widget.flightPoints;

  bool get _trackUp => widget.orientation == MapOrientation.trackUp;

  /// Recorded track, or a demo track around the pilot when there is no
  /// telemetry source (previews, idle canvas). A live source without a
  /// recorded track (pre-takeoff) shows no track rather than a fake one.
  List<FlightPoint> get _effectiveFlightPoints {
    final raw = _rawFlightPoints;
    if (raw != null && raw.isNotEmpty) return raw;
    if (widget.telemetry != null && _t!.hasSource) return const [];
    final p = _effectivePilotPosition;
    if (_mockAnchor != p) {
      _mockAnchor = p;
      _mockPoints = List.unmodifiable(_buildMockFlightPoints(p));
    }
    return _mockPoints;
  }

  @override
  void initState() {
    super.initState();
    _mapService = widget.mapService ?? MapLibreMapService();
    _mapService.addListener(_onMapServiceChanged);
    _attachCamera(widget.cameraViewModel);
    _cameraCenter = _effectivePilotPosition;
    _cameraBearing = _trackUp ? _heading : 0.0;
    _cameraView = ValueNotifier((_cameraCenter, _currentZoom));
    _motion = MapMotionController(
      vsync: this,
      onFrame: _applyFrame,
      initialZoom: _currentZoom,
      trackUp: _trackUp,
    );
    _layers.configure(
      showTrack: widget.showTrack,
      historyMinutes: widget.mapTrackHistoryMinutes,
      showOlderTail: widget.mapTrackShowOlderTail,
      showAirspace: widget.showAirspace,
    );
    _subscribeTelemetry();
    _lastKnownPilot = _rawPilotPosition;
    _thermalSpec = _computeThermalSpec();
    _syncThermalTimer();
    _syncInputs();
    _initMapStyle();
  }

  void _subscribeTelemetry() {
    if (identical(_subscribedTelemetry, widget.telemetry)) return;
    _subscribedTelemetry?.removeListener(_onTelemetry);
    _subscribedTelemetry = widget.telemetry;
    _subscribedTelemetry?.addListener(_onTelemetry);
  }

  void _onTelemetry() {
    if (!mounted) return;
    _syncInputs();
    _checkThermalJump(rebuild: true);
  }

  /// Feeds the current telemetry into motion, overlay layers and HUD.
  void _syncInputs() {
    final pilot = _effectivePilotPosition;
    final points = _effectiveFlightPoints;
    // A replaced recorded track list (flight load, replay seek) is a
    // discontinuity: jump instead of animating across it. Growing tracks keep
    // their list identity (live recording, replay ticks).
    final raw = _rawFlightPoints;
    final last = _lastFlightPoints;
    final snap = raw != null && last != null && !identical(last, raw);
    _lastFlightPoints = raw;
    _motion.pushFix(
      MotionFix(
        latitude: pilot.latitude,
        longitude: pilot.longitude,
        headingDeg: _heading,
        speedKmh: _speed,
        stale: _stale,
      ),
      snap: snap,
    );
    _layers.updateTrack(points);
    _hud.value = (_altitude.round(), _speed.round());
    if (_rawPilotPosition != null) _lastKnownPilot = _rawPilotPosition;
  }

  DateTime _now() => (widget.clock ?? DateTime.now)();

  /// Resolves the desired heatmap layer, or null when thermals are hidden.
  ThermalLayerSpec? _computeThermalSpec() {
    if (!widget.showThermals) return null;
    _thermalEvalPosition = _rawPilotPosition ?? _lastKnownPilot;
    final variant = ThermalVariantResolver.resolve(
      season: widget.thermalSeason,
      timeOfDay: widget.thermalTimeOfDay,
      now: _now(),
      gpsFix: _rawPilotPosition,
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

  /// Re-evaluates the thermal variant immediately after a large jump.
  void _checkThermalJump({required bool rebuild}) {
    final pilot = _rawPilotPosition;
    if (!widget.showThermals || pilot == null) return;
    final evalPos = _thermalEvalPosition;
    final jumped =
        evalPos == null ||
        _distanceKm(evalPos, pilot) > MapWidget.thermalReevaluateDistanceKm;
    if (!jumped) return;
    if (rebuild) {
      _refreshThermal();
    } else {
      final spec = _computeThermalSpec();
      if (spec != _thermalSpec) {
        _thermalSpec = spec;
        _mapService.setThermalLayer(spec);
      }
    }
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

  bool _syncingGestureZoom = false;

  /// Applies camera view model changes (from built-in buttons, map control
  /// widgets or the inactivity timer) to the motion controller.
  void _onCameraChanged() {
    if (!mounted) return;
    final oldZoom = _currentZoom;
    final newZoom = _camera.zoom;
    final recenterRequested = _camera.recenterRequests != _seenRecenterRequests;
    _seenRecenterRequests = _camera.recenterRequests;

    if (newZoom != oldZoom || _centerOnPilot != _camera.centerLocked) {
      setState(() {
        _currentZoom = newZoom;
        _centerOnPilot = _camera.centerLocked;
      });
    }

    if (!_camera.centerLocked && _motion.following) {
      _motion.release();
    }
    if (recenterRequested) {
      _motion.recenter(from: _cameraCenter, fromBearing: _cameraBearing);
    }

    if (newZoom != oldZoom) {
      if (_syncingGestureZoom) {
        // The native camera already shows this zoom.
        _writtenZoom = newZoom;
        _motion.setZoom(newZoom, animate: false);
      } else {
        _motion.setZoom(newZoom);
      }
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

  /// Presents one smoothed frame: one camera write while following, the
  /// native pilot symbol (throttled) while panned.
  void _applyFrame(MotionFrame f) {
    _frame.value = f;
    if (f.following) {
      _cameraCenter = f.cameraCenter;
      _cameraBearing = f.bearing;
      _writeCamera(f.cameraCenter, f.zoom, f.bearing, f.topPaddingFraction);
      _layers.updatePilot(f.pilot, f.headingDeg, visible: false);
    } else {
      if (f.zoom != _writtenZoom) {
        _writeCamera(
          _cameraCenter,
          f.zoom,
          _cameraBearing,
          _writtenPadding ?? f.topPaddingFraction,
        );
      }
      final now = SchedulerBinding.instance.currentFrameTimeStamp;
      final last = _lastPilotSymbolUpdate;
      if (last == null ||
          now < last ||
          now - last >= MapWidget.pilotSymbolInterval) {
        _lastPilotSymbolUpdate = now;
        _layers.updatePilot(f.pilot, f.headingDeg, visible: true);
      }
    }
    _cameraView.value = (_cameraCenter, f.zoom);
  }

  void _writeCamera(
    LatLng center,
    double zoom,
    double bearing,
    double topPaddingFraction,
  ) {
    if (center == _writtenCenter &&
        zoom == _writtenZoom &&
        bearing == _writtenBearing &&
        topPaddingFraction == _writtenPadding) {
      return;
    }
    _writtenCenter = center;
    _writtenZoom = zoom;
    _writtenBearing = bearing;
    _writtenPadding = topPaddingFraction;
    _mapService.moveCamera(
      position: center,
      zoom: zoom,
      bearing: bearing,
      padding: EdgeInsets.only(top: topPaddingFraction * _viewportHeight),
    );
  }

  Future<void> _initMapStyle() async {
    String? effectiveRegion = widget.regionId;
    if (effectiveRegion == null && widget.regionManager != null) {
      final pos = _rawPilotPosition ?? _lastKnownPilot;
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

  void _onMapCreated(MapController controller) {
    _mapService.onMapCreated(controller);
    // Force the next frame to (re)write the camera to the new controller.
    _writtenCenter = null;
    _motion.requestFrame();
  }

  Future<void> _onStyleLoaded(StyleController style) async {
    _mapService.onStyleLoaded(style);
    _layers.detach();
    await _layers.attach(style, belowLayerId: _mapService.thermalBelowLayerId);
    if (!mounted) return;
    if (_layers.isAttached) {
      _mapService.overlayBottomLayerId = MapFlightLayers.bottomLayerId;
    }
    _layers.updateTrack(_effectiveFlightPoints);
    _motion.requestFrame();
  }

  @override
  void dispose() {
    _thermalTimer?.cancel();
    _subscribedTelemetry?.removeListener(_onTelemetry);
    _mapService.removeListener(_onMapServiceChanged);
    _detachCamera();
    _motion.dispose();
    _layers.detach();
    _frame.dispose();
    _hud.dispose();
    _cameraView.dispose();
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
      _layers.detach();
      _initMapStyle();
    } else if (widget.regionId != oldWidget.regionId) {
      _initMapStyle();
    }

    if (!identical(widget.cameraViewModel, oldWidget.cameraViewModel)) {
      _detachCamera();
      _attachCamera(widget.cameraViewModel);
      _syncRegistration();
      _motion.setZoom(_currentZoom, animate: false);
    } else if (widget.cameraId != oldWidget.cameraId) {
      _syncRegistration();
    }

    if (widget.initialZoom != oldWidget.initialZoom) {
      _camera.resetZoom(widget.initialZoom);
      _currentZoom = _camera.zoom;
      _motion.setZoom(_currentZoom, animate: false);
    }

    if (widget.orientation != oldWidget.orientation) {
      _motion.setTrackUp(_trackUp);
    }

    _layers.configure(
      showTrack: widget.showTrack,
      historyMinutes: widget.mapTrackHistoryMinutes,
      showOlderTail: widget.mapTrackShowOlderTail,
      showAirspace: widget.showAirspace,
    );

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

    final telemetryChanged = !identical(widget.telemetry, oldWidget.telemetry);
    _subscribeTelemetry();
    if (widget.telemetry == null || telemetryChanged) {
      _syncInputs();
    }

    if (thermalSettingsChanged) {
      // A rebuild follows didUpdateWidget, so plain assignment is enough.
      final spec = _computeThermalSpec();
      if (spec != _thermalSpec) {
        _thermalSpec = spec;
        _mapService.setThermalLayer(spec);
      }
    } else {
      _checkThermalJump(rebuild: false);
    }
  }

  void _handleZoom(double delta) => _camera.zoomBy(delta);

  void _recenter() => _camera.recenter();

  void _onMapEvent(MapEvent event) {
    if (event is MapEventStartMoveCamera) {
      // Only real user gestures release center-lock; our own per-frame
      // camera writes report a developer/API reason.
      if (event.reason == CameraChangeReason.apiGesture) {
        _camera.beginManualPan();
      }
    } else if (event is MapEventMoveCamera) {
      if (_camera.centerLocked) return; // our own follow moves
      final cam = event.camera;
      final newCenter = LatLng(cam.center.lat, cam.center.lon);
      final latDiff = (_cameraCenter.latitude - newCenter.latitude).abs();
      final lngDiff = (_cameraCenter.longitude - newCenter.longitude).abs();
      final zoomDiff = (_currentZoom - cam.zoom).abs();

      if (latDiff > 1e-6 || lngDiff > 1e-6 || zoomDiff > 0.01) {
        _cameraCenter = newCenter;
        _cameraBearing = cam.bearing;
        _writtenCenter = newCenter;
        _writtenBearing = cam.bearing;
        _cameraView.value = (newCenter, cam.zoom);
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
    final bearing = _cameraBearing;

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

    _cameraCenter = LatLng(newLat, newLng);
    _camera.beginManualPan();
    _writeCamera(
      _cameraCenter,
      _writtenZoom ?? _currentZoom,
      bearing,
      _writtenPadding ?? 0.0,
    );
    _cameraView.value = (_cameraCenter, _writtenZoom ?? _currentZoom);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final h = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : 0.0;
          if (h != _viewportHeight) {
            _viewportHeight = h;
            _writtenPadding = null; // padding pixels changed
            SchedulerBinding.instance.addPostFrameCallback((_) {
              if (mounted) _motion.requestFrame();
            });
          }
          return _buildStack(context);
        },
      ),
    );
  }

  Widget _buildStack(BuildContext context) {
    // Expand: all layers are positioned, so a loosely constrained map would
    // otherwise collapse to 0x0 and the native map would never become ready.
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Map Canvas / MapLibre GL Base Map (track, mock airspace and the
        //    free-floating pilot symbol are native layers inside it).
        Positioned.fill(
          child: Semantics(
            button: false,
            label: 'Interactive map canvas',
            child: GestureDetector(
              key: const Key('map_gesture_detector'),
              behavior: HitTestBehavior.opaque,
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              child: _buildMapBackground(),
            ),
          ),
        ),

        // 2. Airspace vector map layer (OpenAir, Flutter overlay)
        if (widget.showAirspace)
          Consumer<AirspaceService?>(
            builder: (context, airspace, _) {
              if (airspace == null || airspace.loadedAirspaces.isEmpty) {
                return const SizedBox.shrink();
              }
              return Positioned.fill(
                child: IgnorePointer(
                  child: ValueListenableBuilder<(LatLng, double)>(
                    valueListenable: _cameraView,
                    builder: (context, view, _) => AirspaceMapLayer(
                      airspaces: airspace.loadedAirspaces,
                      centerLat: view.$1.latitude,
                      centerLon: view.$1.longitude,
                      zoom: view.$2,
                      activeAlertLevel: airspace.activeAlertLevel,
                    ),
                  ),
                ),
              );
            },
          ),

        // 2b. Screen-anchored pilot marker while center-locked. The camera
        //     puts the smoothed pilot exactly on this anchor every frame.
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                key: const Key('map_pilot_marker'),
                painter: PilotMarkerPainter(
                  frame: _frame,
                  fallbackRotationDeg: _trackUp ? 0.0 : _heading,
                  fallbackTopPadding: _trackUp
                      ? MapMotionController.trackUpTopPadding
                      : 0.0,
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
    );
  }

  Widget _buildMapBackground() {
    if (_styleJson != null && isMapRendererAvailable) {
      return MapLibreMap(
        options: MapOptions(
          initCenter: Geographic(
            lon: _cameraCenter.longitude,
            lat: _cameraCenter.latitude,
          ),
          initZoom: _currentZoom,
          initBearing: _cameraBearing,
          initStyle: _styleJson!,
        ),
        onMapCreated: _onMapCreated,
        onStyleLoaded: _onStyleLoaded,
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
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(180),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: ValueListenableBuilder<MotionFrame?>(
        valueListenable: _frame,
        builder: (context, frame, child) {
          final bearing = frame?.bearing ?? (_trackUp ? _heading : 0.0);
          return Transform.rotate(
            angle: -bearing * math.pi / 180,
            child: child,
          );
        },
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
          ValueListenableBuilder<(int, int)>(
            valueListenable: _hud,
            builder: (context, v, _) => Text(
              'ALT: ${v.$1}m  SPD: ${v.$2}km/h',
              style: const TextStyle(
                color: Colors.cyanAccent,
                fontSize: 8,
                fontWeight: FontWeight.w600,
              ),
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

/// Paints the glider marker at the camera's pilot anchor (true center in
/// north-up, 60 % from the top in track-up) while the map is center-locked.
/// Repaints from [frame] without rebuilding any widget.
class PilotMarkerPainter extends CustomPainter {
  PilotMarkerPainter({
    required this.frame,
    required this.fallbackRotationDeg,
    required this.fallbackTopPadding,
  }) : super(repaint: frame);

  final ValueListenable<MotionFrame?> frame;
  final double fallbackRotationDeg;
  final double fallbackTopPadding;

  static final Paint _haloPaint = Paint()
    ..color = Colors.cyanAccent.withAlpha(45)
    ..style = PaintingStyle.fill;
  static final Paint _outlinePaint = Paint()
    ..color = Colors.black87
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5;
  static final Paint _bodyPaint = Paint()
    ..color = Colors.cyanAccent
    ..style = PaintingStyle.fill;
  static final Path _arrowPath = Path()
    ..moveTo(0, -11)
    ..lineTo(-8, 8)
    ..lineTo(0, 3)
    ..lineTo(8, 8)
    ..close();

  /// Marker anchor for a viewport of [size] (tests).
  Offset anchorFor(Size size) {
    final f = frame.value;
    final padding = f?.topPaddingFraction ?? fallbackTopPadding;
    return Offset(size.width / 2, size.height * (1 + padding) / 2);
  }

  /// Marker rotation in degrees relative to the screen (tests).
  double get rotationDeg =>
      frame.value?.markerRotationDeg ?? fallbackRotationDeg;

  /// Whether the marker is drawn (hidden while the map is panned; the
  /// native symbol then shows the pilot).
  bool get visible => frame.value?.following ?? true;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || !visible) return;
    final pos = anchorFor(size);
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(rotationDeg * math.pi / 180);
    canvas.drawCircle(Offset.zero, 18, _haloPaint);
    canvas.drawPath(_arrowPath, _outlinePaint);
    canvas.drawPath(_arrowPath, _bodyPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(PilotMarkerPainter old) =>
      !identical(old.frame, frame) ||
      old.fallbackRotationDeg != fallbackRotationDeg ||
      old.fallbackTopPadding != fallbackTopPadding;
}
