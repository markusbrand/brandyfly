import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:brandyfly_native/brandyfly_native.dart';

import '../models/flight_model.dart';
import 'elevation_service.dart';
import 'flight_replay_service.dart';
import 'flight_tracking_service.dart';

/// Proximity alert levels corresponding to aviation safety standards.
enum AirspaceAlertLevel {
  clear(0, 'CLEAR'),
  advisory(1, 'ADVISORY'),
  warning(2, 'WARNING'),
  violation(3, 'VIOLATION');

  const AirspaceAlertLevel(this.severity, this.label);

  final int severity;
  final String label;

  static AirspaceAlertLevel fromInt(int val) {
    switch (val) {
      case 3:
        return AirspaceAlertLevel.violation;
      case 2:
        return AirspaceAlertLevel.warning;
      case 1:
        return AirspaceAlertLevel.advisory;
      default:
        return AirspaceAlertLevel.clear;
    }
  }
}

/// Airspace boundary model for map visualization and vertical profile slicing.
@immutable
class AirspaceModel {
  const AirspaceModel({
    required this.id,
    required this.name,
    required this.airspaceClass,
    required this.floorLabel,
    required this.ceilingLabel,
    required this.floorMslM,
    required this.ceilingMslM,
    required this.polygon,
  });

  final String id;
  final String name;
  final String airspaceClass;
  final String floorLabel;
  final String ceilingLabel;
  final double floorMslM;
  final double ceilingMslM;
  final List<({double lat, double lon})> polygon;
}

/// Proximity state surfaced on each telemetry cycle.
@immutable
class AirspaceProximityState {
  const AirspaceProximityState({
    required this.alertLevel,
    required this.airspaceName,
    required this.airspaceClass,
    required this.horizontalSeparationM,
    required this.verticalSeparationM,
    required this.total3dDistanceM,
    required this.isInsideHorizontal,
    required this.isInsideVertical,
    required this.floorMslM,
    required this.ceilingMslM,
    required this.forwardIntersectionDistanceM,
    required this.forwardIntersectionTimeS,
    required this.willPenetrateGlideSlope,
  });

  final AirspaceAlertLevel alertLevel;
  final String airspaceName;
  final String airspaceClass;
  final double horizontalSeparationM;
  final double verticalSeparationM;
  final double total3dDistanceM;
  final bool isInsideHorizontal;
  final bool isInsideVertical;
  final double floorMslM;
  final double ceilingMslM;
  final double forwardIntersectionDistanceM;
  final double forwardIntersectionTimeS;
  final bool willPenetrateGlideSlope;

  static const AirspaceProximityState clear = AirspaceProximityState(
    alertLevel: AirspaceAlertLevel.clear,
    airspaceName: '',
    airspaceClass: '',
    horizontalSeparationM: double.infinity,
    verticalSeparationM: double.infinity,
    total3dDistanceM: double.infinity,
    isInsideHorizontal: false,
    isInsideVertical: false,
    floorMslM: 0.0,
    ceilingMslM: 0.0,
    forwardIntersectionDistanceM: -1.0,
    forwardIntersectionTimeS: -1.0,
    willPenetrateGlideSlope: false,
  );
}

/// Forward intersection along heading for vertical cross-section display.
@immutable
class ForwardAirspaceBlock {
  const ForwardAirspaceBlock({
    required this.airspace,
    required this.entryDistanceM,
    required this.exitDistanceM,
    required this.entryAltitudeM,
    required this.floorMslM,
    required this.ceilingMslM,
    required this.willPenetrate,
  });

  final AirspaceModel airspace;
  final double entryDistanceM;
  final double exitDistanceM;
  final double entryAltitudeM;
  final double floorMslM;
  final double ceilingMslM;
  final bool willPenetrate;
}

/// Core service managing loaded airspaces, telemetry feeds, and 3D proximity warnings.
class AirspaceService extends ChangeNotifier {
  AirspaceService({
    BrandyflyNative? nativeClient,
    this._elevationService,
  })  : _native = nativeClient ?? const BrandyflyNative();

  final BrandyflyNative _native;
  final ElevationService? _elevationService;

  StreamSubscription<FlightPoint>? _flightTrackingSub;
  double _activeQnhHpa = 1013.25;

  final List<AirspaceModel> _loadedAirspaces = [];
  AirspaceProximityState _latestProximity = AirspaceProximityState.clear;

  final _proximityController =
      StreamController<AirspaceProximityState>.broadcast();
  final _alertController = StreamController<AirspaceAlertLevel>.broadcast();

  List<AirspaceModel> get loadedAirspaces =>
      List.unmodifiable(_loadedAirspaces);
  AirspaceProximityState get latestProximity => _latestProximity;
  AirspaceAlertLevel get activeAlertLevel => _latestProximity.alertLevel;
  double get activeQnhHpa => _activeQnhHpa;

  Stream<AirspaceProximityState> get proximityStream =>
      _proximityController.stream;
  Stream<AirspaceAlertLevel> get alertStream => _alertController.stream;

  set activeQnhHpa(double qnh) {
    if (_activeQnhHpa != qnh) {
      _activeQnhHpa = qnh;
      notifyListeners();
    }
  }

  /// Binds to a `FlightTrackingService` telemetry stream.
  void attachFlightTrackingService(FlightTrackingService trackingService) {
    detachFlightTrackingService();
    _flightTrackingSub = trackingService.pointStream.listen((point) {
      processFlightPoint(point);
    });
  }

  void detachFlightTrackingService() {
    _flightTrackingSub?.cancel();
    _flightTrackingSub = null;
  }

  FlightReplayService? _flightReplayService;
  VoidCallback? _flightReplayListener;

  /// Binds to a `FlightReplayService` to evaluate airspace proximity during replay simulation.
  void attachFlightReplayService(FlightReplayService replayService) {
    detachFlightReplayService();
    _flightReplayService = replayService;
    void onTick() {
      final pt = replayService.currentPoint;
      if (pt != null) {
        processFlightPoint(pt);
      }
    }
    _flightReplayListener = onTick;
    replayService.addListener(onTick);

    final initialPt = replayService.currentPoint;
    if (initialPt != null) {
      processFlightPoint(initialPt);
    }
  }

  void detachFlightReplayService() {
    if (_flightReplayService != null && _flightReplayListener != null) {
      _flightReplayService!.removeListener(_flightReplayListener!);
      _flightReplayService = null;
      _flightReplayListener = null;
    }
  }

  /// Loads OpenAir formatted text into memory.
  Future<int> loadOpenAirText(String openAirText) async {
    try {
      await _native.airspaceInitStore();
      final count = await _native.airspaceLoadOpenAir(openAirText);

      // Parse Dart models for map rendering and side-cut widget
      _loadedAirspaces.clear();
      _loadedAirspaces.addAll(_parseOpenAirToModels(openAirText));
      notifyListeners();
      return count;
    } catch (e) {
      debugPrint('AirspaceService: Failed to load OpenAir text: $e');
      return 0;
    }
  }

  /// Loads the bundled DACH Alpine airspace fixture.
  Future<int> loadDachFixture() async {
    try {
      await _native.airspaceInitStore();
      final count = await _native.airspaceLoadDachFixture();

      _loadedAirspaces.clear();
      _loadedAirspaces.addAll(_parseOpenAirToModels(_dachOpenAirFixture));
      notifyListeners();
      return count;
    } catch (e) {
      debugPrint('AirspaceService: Failed to load DACH fixture: $e');
      return 0;
    }
  }

  /// Clears all loaded airspaces and resets alert state.
  Future<void> clearAirspaces() async {
    try {
      await _native.airspaceClearStore();
    } catch (_) {}
    _loadedAirspaces.clear();
    _latestProximity = AirspaceProximityState.clear;
    _proximityController.add(AirspaceProximityState.clear);
    _alertController.add(AirspaceAlertLevel.clear);
    notifyListeners();
  }

  /// Evaluates proximity for an incoming telemetry point.
  Future<void> processFlightPoint(FlightPoint point) async {
    if (_loadedAirspaces.isEmpty) {
      if (_latestProximity != AirspaceProximityState.clear) {
        _latestProximity = AirspaceProximityState.clear;
        _proximityController.add(AirspaceProximityState.clear);
        _alertController.add(AirspaceAlertLevel.clear);
        notifyListeners();
      }
      return;
    }

    double terrainElevation = 0.0;
    if (_elevationService != null) {
      try {
        final el = await _elevationService.getElevation(
          point.latitude,
          point.longitude,
        );
        if (el != null) {
          terrainElevation = el;
        }
      } catch (_) {}
    }

    final input = NativeAirspaceEvaluationInput(
      latitude: point.latitude,
      longitude: point.longitude,
      altitudeMsl: point.altitude,
      groundspeedMps: point.speed / 3.6,
      trackHeadingDeg: point.heading,
      glideRatio: 8.0,
      qnhHpa: _activeQnhHpa,
      terrainElevationMsl: terrainElevation,
      timestampMs: point.timestamp.millisecondsSinceEpoch,
    );

    try {
      var out = await _native.airspaceEvaluate(input);

      // In-memory fallback if platform channel returned clear but we are inside a loaded polygon
      if (out.alertLevel == 0 && _loadedAirspaces.isNotEmpty) {
        for (final a in _loadedAirspaces) {
          if (_pointInPolygon(point.latitude, point.longitude, a.polygon)) {
            final isInsideV =
                point.altitude >= a.floorMslM && point.altitude <= a.ceilingMslM;
            final dV = point.altitude < a.floorMslM
                ? a.floorMslM - point.altitude
                : point.altitude > a.ceilingMslM
                    ? point.altitude - a.ceilingMslM
                    : 0.0;
            final lvl = isInsideV
                ? 3
                : (dV < 75.0 ? 2 : (dV < 150.0 ? 1 : 0));
            if (lvl > out.alertLevel) {
              out = NativeAirspaceEvaluationOutput(
                alertLevel: lvl,
                horizontalSeparationM: 0.0,
                verticalSeparationM: dV,
                total3dDistanceM: dV,
                isInsideHorizontal: true,
                isInsideVertical: isInsideV,
                floorMslM: a.floorMslM,
                ceilingMslM: a.ceilingMslM,
                forwardIntersectionDistanceM: -1.0,
                forwardIntersectionTimeS: -1.0,
                willPenetrateGlideSlope: false,
              );
            }
          }
        }
      }

      final level = AirspaceAlertLevel.fromInt(out.alertLevel);

      // Find top airspace name if any
      String topName = '';
      String topClass = '';
      if (_loadedAirspaces.isNotEmpty) {
        topName = _loadedAirspaces.first.name;
        topClass = _loadedAirspaces.first.airspaceClass;
      }

      final newState = AirspaceProximityState(
        alertLevel: level,
        airspaceName: topName,
        airspaceClass: topClass,
        horizontalSeparationM: out.horizontalSeparationM,
        verticalSeparationM: out.verticalSeparationM,
        total3dDistanceM: out.total3dDistanceM,
        isInsideHorizontal: out.isInsideHorizontal,
        isInsideVertical: out.isInsideVertical,
        floorMslM: out.floorMslM,
        ceilingMslM: out.ceilingMslM,
        forwardIntersectionDistanceM: out.forwardIntersectionDistanceM,
        forwardIntersectionTimeS: out.forwardIntersectionTimeS,
        willPenetrateGlideSlope: out.willPenetrateGlideSlope,
      );

      _latestProximity = newState;
      _proximityController.add(newState);
      _alertController.add(level);
      notifyListeners();
    } catch (e) {
      debugPrint('AirspaceService: Evaluation error: $e');
    }
  }

  /// Calculates forward intersecting airspace blocks along a flight heading.
  List<ForwardAirspaceBlock> getForwardAirspaces({
    required double lat,
    required double lon,
    required double altitudeMsl,
    required double headingDeg,
    double lookaheadDistanceM = 10000.0,
    double glideRatio = 8.0,
  }) {
    if (_loadedAirspaces.isEmpty) return [];

    final headingRad = headingDeg * math.pi / 180.0;
    const earthR = 6371000.0;
    final blocks = <ForwardAirspaceBlock>[];

    // Sample along heading
    const sampleStepM = 200.0;
    final numSteps = (lookaheadDistanceM / sampleStepM).ceil();

    for (final airspace in _loadedAirspaces) {
      double? entryDist;
      double? exitDist;
      double entryAlt = altitudeMsl;
      bool penetrates = false;

      for (var i = 0; i <= numSteps; i++) {
        final dist = i * sampleStepM;
        final dLatDeg = (dist * math.cos(headingRad) / earthR) * 180.0 / math.pi;
        final cosLat = math.cos(lat * math.pi / 180.0).abs().clamp(0.01, 1.0);
        final dLonDeg =
            (dist * math.sin(headingRad) / (earthR * cosLat)) * 180.0 / math.pi;

        final sampleLat = lat + dLatDeg;
        final sampleLon = lon + dLonDeg;
        final sampleAlt = altitudeMsl - (dist / glideRatio);

        if (_pointInPolygon(sampleLat, sampleLon, airspace.polygon)) {
          entryDist ??= dist;
          if (entryDist == dist) {
            entryAlt = sampleAlt;
          }
          exitDist = dist;

          if (sampleAlt >= airspace.floorMslM &&
              sampleAlt <= airspace.ceilingMslM) {
            penetrates = true;
          }
        }
      }

      if (entryDist != null && exitDist != null) {
        blocks.add(ForwardAirspaceBlock(
          airspace: airspace,
          entryDistanceM: entryDist,
          exitDistanceM: exitDist,
          entryAltitudeM: entryAlt,
          floorMslM: airspace.floorMslM,
          ceilingMslM: airspace.ceilingMslM,
          willPenetrate: penetrates,
        ));
      }
    }

    blocks.sort((a, b) => a.entryDistanceM.compareTo(b.entryDistanceM));
    return blocks;
  }

  static bool _pointInPolygon(
    double lat,
    double lon,
    List<({double lat, double lon})> polygon,
  ) {
    if (polygon.length < 3) return false;
    var inside = false;
    final n = polygon.length;
    for (var i = 0; i < n; i++) {
      final j = i == 0 ? n - 1 : i - 1;
      final xi = polygon[i].lon;
      final yi = polygon[i].lat;
      final xj = polygon[j].lon;
      final yj = polygon[j].lat;

      final intersect = ((yi > lat) != (yj > lat)) &&
          (lon < (xj - xi) * (lat - yi) / (yj - yi) + xi);
      if (intersect) inside = !inside;
    }
    return inside;
  }

  static List<AirspaceModel> _parseOpenAirToModels(String text) {
    final airspaces = <AirspaceModel>[];
    String currentClass = 'OTHER';
    String currentName = '';
    String floorStr = 'GND';
    String ceilingStr = 'UNL';
    double floorM = 0.0;
    double ceilM = 3000.0;
    final points = <({double lat, double lon})>[];

    void commitCurrent() {
      if (points.length >= 3) {
        airspaces.add(AirspaceModel(
          id: 'airspace-${airspaces.length + 1}',
          name: currentName.isEmpty
              ? 'Airspace ${airspaces.length + 1}'
              : currentName,
          airspaceClass: currentClass,
          floorLabel: floorStr,
          ceilingLabel: ceilingStr,
          floorMslM: floorM,
          ceilingMslM: ceilM,
          polygon: List.from(points),
        ));
      }
      points.clear();
      currentName = '';
      currentClass = 'OTHER';
      floorStr = 'GND';
      ceilingStr = 'UNL';
      floorM = 0.0;
      ceilM = 3000.0;
    }

    for (final rawLine in text.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('*')) continue;

      final parts = line.split(RegExp(r'\s+'));
      if (parts.isEmpty) continue;
      final tag = parts.first.toUpperCase();
      final payload = parts.skip(1).join(' ').trim();

      switch (tag) {
        case 'AC':
          if (points.isNotEmpty) commitCurrent();
          currentClass = payload.toUpperCase();
          break;
        case 'AN':
          currentName = payload;
          break;
        case 'AL':
          floorStr = payload;
          floorM = _parseVerticalLimitMeters(payload);
          break;
        case 'AH':
          ceilingStr = payload;
          ceilM = _parseVerticalLimitMeters(payload);
          break;
        case 'DP':
          final coord = _parseCoordinate(payload);
          if (coord != null) {
            points.add(coord);
          }
          break;
        case 'DC':
          // Circle radius in NM
          final rNm = double.tryParse(payload) ?? 5.0;
          if (points.isNotEmpty) {
            final center = points.last;
            points.clear();
            points.addAll(_discretizeCircle(center.lat, center.lon, rNm));
          }
          break;
      }
    }
    if (points.isNotEmpty) commitCurrent();

    return airspaces;
  }

  static double _parseVerticalLimitMeters(String text) {
    final upper = text.toUpperCase().trim();
    if (upper == 'GND' || upper == 'SFC') return 0.0;
    if (upper == 'UNL' || upper == 'UNLIMITED') return 15000.0;

    if (upper.startsWith('FL')) {
      final num = double.tryParse(upper.replaceAll('FL', '').trim()) ?? 100.0;
      return num * 100.0 * 0.3048;
    }

    final match = RegExp(r'(\d+)\s*(FT|M)?').firstMatch(upper);
    if (match != null) {
      final val = double.tryParse(match.group(1) ?? '') ?? 1000.0;
      final unit = match.group(2) ?? 'FT';
      if (unit == 'M') return val;
      return val * 0.3048;
    }

    return 1000.0;
  }

  static ({double lat, double lon})? _parseCoordinate(String text) {
    final parts = text.trim().split(RegExp(r'\s+'));
    if (parts.length >= 4) {
      final latStr = '${parts[0]} ${parts[1]}';
      final lonStr = '${parts[2]} ${parts[3]}';
      final lat = _parseSingleDms(latStr, isLat: true);
      final lon = _parseSingleDms(lonStr, isLat: false);
      if (lat != null && lon != null) {
        return (lat: lat, lon: lon);
      }
    } else if (parts.length >= 2) {
      final lat = _parseSingleDms(parts[0], isLat: true);
      final lon = _parseSingleDms(parts[1], isLat: false);
      if (lat != null && lon != null) {
        return (lat: lat, lon: lon);
      }
    }
    return null;
  }

  static double? _parseSingleDms(String token, {required bool isLat}) {
    final upper = token.toUpperCase().trim();
    final sign = (upper.contains('S') || upper.contains('W')) ? -1.0 : 1.0;
    final clean = upper.replaceAll(RegExp(r'[NSEW\s]'), '').trim();

    final colonParts = clean.split(':');
    if (colonParts.length == 3) {
      final d = double.tryParse(colonParts[0]) ?? 0.0;
      final m = double.tryParse(colonParts[1]) ?? 0.0;
      final s = double.tryParse(colonParts[2]) ?? 0.0;
      return sign * (d + m / 60.0 + s / 3600.0);
    } else if (colonParts.length == 2) {
      final d = double.tryParse(colonParts[0]) ?? 0.0;
      final m = double.tryParse(colonParts[1]) ?? 0.0;
      return sign * (d + m / 60.0);
    }
    final val = double.tryParse(clean);
    return val != null ? sign * val : null;
  }

  static List<({double lat, double lon})> _discretizeCircle(
    double cLat,
    double cLon,
    double rNm,
  ) {
    const numSteps = 24;
    final rMeters = rNm * 1852.0;
    const earthR = 6371000.0;
    final pts = <({double lat, double lon})>[];

    for (var i = 0; i < numSteps; i++) {
      final bearing = i * (2.0 * math.pi / numSteps);
      final dLat = (rMeters * math.cos(bearing) / earthR) * 180.0 / math.pi;
      final cosLat = math.cos(cLat * math.pi / 180.0).abs().clamp(0.01, 1.0);
      final dLon =
          (rMeters * math.sin(bearing) / (earthR * cosLat)) * 180.0 / math.pi;
      pts.add((lat: cLat + dLat, lon: cLon + dLon));
    }
    if (pts.isNotEmpty) pts.add(pts.first);
    return pts;
  }

  static const String _dachOpenAirFixture = r'''
* Innsbruck CTR
AC CTR
AN INNSBRUCK CTR
AL GND
AH 5000ft MSL
DP 47:18:00 N 011:10:00 E
DP 47:18:00 N 011:35:00 E
DP 47:14:00 N 011:35:00 E
DP 47:14:00 N 011:10:00 E

* Salzburg Airport CTR
AC CTR
AN LOWS SALZBURG CTR
AL GND
AH 4500 FT MSL
DP 47:47:35 N 013:00:15 E
DC 4.3

* Munich TMA
AC C
AN MUENCHEN TMA 1
AL 4500ft MSL
AH FL 100
DP 48:20:00 N 011:40:00 E
DP 48:30:00 N 012:00:00 E
DP 48:15:00 N 012:15:00 E
DP 48:05:00 N 011:55:00 E
''';

  @override
  void dispose() {
    detachFlightTrackingService();
    detachFlightReplayService();
    _proximityController.close();
    _alertController.close();
    super.dispose();
  }
}
