import 'dart:async';
import 'dart:math' as math;
import 'telemetry_source.dart';
import 'telemetry_types.dart';

/// Procedural synthetic flight telemetry source generating standard paragliding flight phases.
class SyntheticTelemetrySource implements ITelemetrySource {
  SyntheticTelemetrySource({
    this.seed = 42,
    this.frequencyHz = 10,
    FlightManeuver initialManeuver = FlightManeuver.steadyGlide,
    this.initialAltitude = 1500.0,
    this.initialLatitude = 47.5246,
    this.initialLongitude = 13.6917,
    this.initialHeading = 120.0,
  }) : _maneuver = initialManeuver {
    _resetState();
  }

  final int seed;
  final int frequencyHz;
  final double initialAltitude;
  final double initialLatitude;
  final double initialLongitude;
  final double initialHeading;

  FlightManeuver _maneuver;
  Timer? _timer;
  bool _isRunning = false;
  bool _isPaused = false;

  late double _altitude;
  late double _latitude;
  late double _longitude;
  late double _heading;
  double _phaseElapsedSeconds = 0.0;
  DateTime _currentSimTime = DateTime.now();

  final _telemetryController = StreamController<TelemetrySnapshot>.broadcast();
  final _rawSensorController = StreamController<dynamic>.broadcast();

  @override
  TelemetrySourceType get sourceType => TelemetrySourceType.synthetic;

  @override
  String get name => 'SyntheticTelemetrySource(${_maneuver.name})';

  @override
  Stream<TelemetrySnapshot> get telemetryStream => _telemetryController.stream;

  @override
  Stream<dynamic> get rawSensorStream => _rawSensorController.stream;

  @override
  bool get isRunning => _isRunning;

  @override
  bool get isPaused => _isPaused;

  FlightManeuver get activeManeuver => _maneuver;
  double get currentAltitude => _altitude;
  double get currentLatitude => _latitude;
  double get currentLongitude => _longitude;
  double get currentHeading => _heading;

  void setManeuver(FlightManeuver maneuver) {
    _maneuver = maneuver;
    _phaseElapsedSeconds = 0.0;
  }

  void _resetState() {
    _altitude = initialAltitude + ((seed % 50) * 2.0);
    _latitude = initialLatitude + ((seed % 10) * 0.001);
    _longitude = initialLongitude + ((seed % 10) * 0.001);
    _heading = initialHeading + (seed % 30);
    _phaseElapsedSeconds = 0.0;
    _currentSimTime = DateTime.now();
  }

  @override
  Future<void> initialize() async {
    _resetState();
  }

  @override
  Future<void> start() async {
    if (_isRunning && !_isPaused) return;
    _isRunning = true;
    _isPaused = false;
    _startTimer();
  }

  @override
  Future<void> pause() async {
    _isPaused = true;
    _isRunning = false;
    _timer?.cancel();
    _timer = null;
  }

  @override
  Future<void> stop() async {
    _isPaused = false;
    _isRunning = false;
    _timer?.cancel();
    _timer = null;
    _resetState();
  }

  void _startTimer() {
    _timer?.cancel();
    final intervalMs = (1000 / frequencyHz).round().clamp(10, 1000);
    _timer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
      _tick(intervalMs / 1000.0);
    });
  }

  TelemetrySnapshot _tick(double dtSeconds) {
    _phaseElapsedSeconds += dtSeconds;
    _currentSimTime = _currentSimTime.add(Duration(milliseconds: (dtSeconds * 1000).round()));

    double climbRate;
    double speedKmh;
    double turnRateDegPerSec;

    switch (_maneuver) {
      case FlightManeuver.steadyGlide:
        speedKmh = 38.0 + ((seed % 5) * 0.8);
        climbRate = -1.2 - ((seed % 3) * 0.1);
        turnRateDegPerSec = 0.0;
        break;

      case FlightManeuver.thermalClimb360:
        // 360 deg turn in 20 seconds = 18 deg/s
        turnRateDegPerSec = 18.0;
        climbRate = 2.5 + 0.1 * math.sin(_phaseElapsedSeconds * 2.0);
        speedKmh = 36.0;
        break;

      case FlightManeuver.sinkRecovery:
        if (_phaseElapsedSeconds < 5.0) {
          climbRate = -3.5;
          speedKmh = 43.2; // 12 m/s
        } else if (_phaseElapsedSeconds < 10.0) {
          final progress = (_phaseElapsedSeconds - 5.0) / 5.0;
          climbRate = -3.5 + progress * 2.3; // -3.5 -> -1.2
          speedKmh = 43.2 - progress * 5.4;
        } else {
          climbRate = -1.2;
          speedKmh = 37.8;
        }
        turnRateDegPerSec = 0.0;
        break;
    }

    _altitude += climbRate * dtSeconds;
    _heading = (_heading + turnRateDegPerSec * dtSeconds) % 360.0;
    if (_heading < 0.0) _heading += 360.0;

    final speedMps = speedKmh / 3.6;
    final distMeters = speedMps * dtSeconds;
    final bearingRad = _heading * math.pi / 180.0;

    final deltaLat = (distMeters * math.cos(bearingRad)) / 111139.0;
    final deltaLon = (distMeters * math.sin(bearingRad)) /
        (111139.0 * math.cos(_latitude * math.pi / 180.0).clamp(0.1, 1.0));

    _latitude += deltaLat;
    _longitude += deltaLon;

    // Barometric pressure formula: P = 1013.25 * (1 - alt/44330)^5.25588
    final pressureHpa = 1013.25 * math.pow((1.0 - (_altitude / 44330.0)).clamp(0.01, 1.0), 5.25588);

    final snapshot = TelemetrySnapshot(
      timestamp: _currentSimTime,
      altitude: double.parse(_altitude.toStringAsFixed(1)),
      pressureHpa: double.parse(pressureHpa.toStringAsFixed(2)),
      vario: double.parse(climbRate.toStringAsFixed(2)),
      speed: double.parse(speedKmh.toStringAsFixed(1)),
      heading: double.parse(_heading.toStringAsFixed(1)),
      latitude: _latitude,
      longitude: _longitude,
      gnssAltitude: double.parse((_altitude + 5.0).toStringAsFixed(1)),
      hag: (_altitude - 800.0).clamp(0.0, 9999.0),
      windDirectionDeg: ((_heading + 180.0) % 360.0),
      windSpeedKmh: 12.0,
      isStale: false,
      isValid: true,
    );

    _telemetryController.add(snapshot);
    _rawSensorController.add({
      'source': 'synthetic',
      'maneuver': _maneuver.name,
      'timestamp': _currentSimTime.toIso8601String(),
      'pressure_hpa': pressureHpa,
      'altitude_m': _altitude,
      'speed_kmh': speedKmh,
      'climb_rate_mps': climbRate,
      'bearing_deg': _heading,
    });
    return snapshot;
  }

  /// Helper to step simulation synchronously for unit testing without waiting for timers.
  TelemetrySnapshot stepSynchronously(double dtSeconds) {
    return _tick(dtSeconds);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _telemetryController.close();
    _rawSensorController.close();
  }
}
