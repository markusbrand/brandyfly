import 'dart:async';
import '../../models/flight_model.dart';
import '../igc_parser_service.dart';
import 'telemetry_source.dart';
import 'telemetry_types.dart';

/// Telemetry provider that streams pre-recorded IGC flight logs at paced intervals with multiplier controls.
class IgcReplayTelemetrySource implements ITelemetrySource {
  IgcReplayTelemetrySource({
    FlightModel? flight,
    String? rawIgcContent,
    IGCParserService? igcParser,
    int initialSpeedMultiplier = 1,
  })  : _igcParser = igcParser ?? const IGCParserService(),
        _speedMultiplier = initialSpeedMultiplier {
    if (flight != null) {
      _flight = flight;
    } else if (rawIgcContent != null) {
      _flight = _igcParser.parseIgc(rawIgcContent);
    }
  }

  final IGCParserService _igcParser;
  FlightModel? _flight;
  int _currentIndex = 0;
  int _speedMultiplier = 1;
  bool _isRunning = false;
  bool _isPaused = false;
  Timer? _timer;

  final _telemetryController = StreamController<TelemetrySnapshot>.broadcast();
  final _rawSensorController = StreamController<dynamic>.broadcast();

  @override
  TelemetrySourceType get sourceType => TelemetrySourceType.igcReplay;

  @override
  String get name => 'IgcReplayTelemetrySource(${_flight?.title ?? "Unknown"})';

  @override
  Stream<TelemetrySnapshot> get telemetryStream => _telemetryController.stream;

  @override
  Stream<dynamic> get rawSensorStream => _rawSensorController.stream;

  @override
  bool get isRunning => _isRunning;

  @override
  bool get isPaused => _isPaused;

  int get speedMultiplier => _speedMultiplier;
  int get currentIndex => _currentIndex;
  int get totalPoints => _flight?.points.length ?? 0;
  FlightModel? get flight => _flight;

  void loadFlight(FlightModel flight) {
    stop();
    _flight = flight;
    _currentIndex = 0;
  }

  void loadIgcContent(String igcContent) {
    stop();
    _flight = _igcParser.parseIgc(igcContent);
    _currentIndex = 0;
  }

  void setSpeedMultiplier(int multiplier) {
    _speedMultiplier = multiplier.clamp(1, 10);
    if (_isRunning && !_isPaused) {
      _scheduleNextPoint();
    }
  }

  void cycleSpeedMultiplier() {
    const multipliers = [1, 2, 5, 10];
    final idx = multipliers.indexOf(_speedMultiplier);
    if (idx == -1 || idx >= multipliers.length - 1) {
      _speedMultiplier = multipliers.first;
    } else {
      _speedMultiplier = multipliers[idx + 1];
    }
    if (_isRunning && !_isPaused) {
      _scheduleNextPoint();
    }
  }

  @override
  Future<void> initialize() async {
    _currentIndex = 0;
  }

  @override
  Future<void> start() async {
    if (_flight == null || _flight!.points.isEmpty) return;
    if (_isRunning && !_isPaused) return;

    _isRunning = true;
    _isPaused = false;
    _emitCurrentPoint();
    _scheduleNextPoint();
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
    _isRunning = false;
    _isPaused = false;
    _timer?.cancel();
    _timer = null;
    _currentIndex = 0;
  }

  void seekTo(int index) {
    if (_flight == null || _flight!.points.isEmpty) return;
    _currentIndex = index.clamp(0, _flight!.points.length - 1);
    _emitCurrentPoint();
    if (_isRunning && !_isPaused) {
      _scheduleNextPoint();
    }
  }

  void seekToRatio(double ratio) {
    if (_flight == null || _flight!.points.isEmpty) return;
    final target = (ratio * (_flight!.points.length - 1)).round();
    seekTo(target);
  }

  void _scheduleNextPoint() {
    _timer?.cancel();
    if (_flight == null || _currentIndex >= _flight!.points.length - 1) {
      _isRunning = false;
      _isPaused = false;
      return;
    }

    final cur = _flight!.points[_currentIndex];
    final next = _flight!.points[_currentIndex + 1];
    final rawDtMs = next.timestamp.difference(cur.timestamp).inMilliseconds.abs();
    final effectiveDtMs = (rawDtMs > 0 ? rawDtMs : 1000);
    final intervalMs = (effectiveDtMs / _speedMultiplier).round().clamp(10, 5000);

    _timer = Timer(Duration(milliseconds: intervalMs), () {
      if (!_isRunning || _isPaused) return;
      _currentIndex++;
      _emitCurrentPoint();
      _scheduleNextPoint();
    });
  }

  void _emitCurrentPoint() {
    if (_flight == null || _flight!.points.isEmpty) return;
    final point = _flight!.points[_currentIndex];
    final snapshot = TelemetrySnapshot.fromFlightPoint(point);

    _telemetryController.add(snapshot);
    _rawSensorController.add({
      'source': 'igc_replay',
      'flight_id': _flight!.id,
      'index': _currentIndex,
      'timestamp': point.timestamp.toIso8601String(),
      'latitude': point.latitude,
      'longitude': point.longitude,
      'altitude': point.altitude,
      'vario': point.vario,
      'speed': point.speed,
      'heading': point.heading,
    });
  }

  /// Steps replay one step synchronously for testing without timers.
  TelemetrySnapshot? stepSynchronously() {
    if (_flight == null || _currentIndex >= _flight!.points.length - 1) return null;
    _currentIndex++;
    _emitCurrentPoint();
    final point = _flight!.points[_currentIndex];
    return TelemetrySnapshot.fromFlightPoint(point);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _telemetryController.close();
    _rawSensorController.close();
  }
}
