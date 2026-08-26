import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/flight_model.dart';
import '../models/flight_settings.dart';
import 'igc_parser_service.dart';
import 'telemetry/telemetry_source.dart';
import 'telemetry/telemetry_types.dart';

class FlightTrackingService extends ChangeNotifier {
  FlightTrackingService({
    FlightSettings? settings,
    IGCParserService? igcParser,
    ITelemetrySource? telemetrySource,
  })  : _settings = settings ?? const FlightSettings(),
        _igcParser = igcParser ?? const IGCParserService() {
    if (telemetrySource != null) {
      attachTelemetrySource(telemetrySource);
    }
  }

  FlightSettings _settings;
  final IGCParserService _igcParser;
  ITelemetrySource? _telemetrySource;
  StreamSubscription<TelemetrySnapshot>? _telemetrySub;

  FlightState _state = FlightState.groundPreflight;
  final List<FlightPoint> _preTakeoffBuffer = [];
  final List<FlightPoint> _activeFlightPoints = [];

  DateTime? _takeoffConditionStartTime;
  DateTime? _landingConditionStartTime;
  FlightModel? _lastCompletedFlight;

  // Streams for reactive listeners
  final _stateController = StreamController<FlightState>.broadcast();
  final _pointController = StreamController<FlightPoint>.broadcast();
  final _flightCompletedController = StreamController<FlightModel>.broadcast();

  FlightState get state => _state;
  FlightSettings get settings => _settings;
  ITelemetrySource? get telemetrySource => _telemetrySource;
  List<FlightPoint> get activeFlightPoints => List.unmodifiable(_activeFlightPoints);
  FlightModel? get lastCompletedFlight => _lastCompletedFlight;

  Stream<FlightState> get stateStream => _stateController.stream;
  Stream<FlightPoint> get pointStream => _pointController.stream;
  Stream<FlightModel> get flightCompletedStream => _flightCompletedController.stream;

  void attachTelemetrySource(ITelemetrySource source) {
    detachTelemetrySource();
    _telemetrySource = source;
    _telemetrySub = source.telemetryStream.listen((snapshot) {
      processTelemetrySnapshot(snapshot);
    });
    notifyListeners();
  }

  void detachTelemetrySource() {
    _telemetrySub?.cancel();
    _telemetrySub = null;
    _telemetrySource = null;
    notifyListeners();
  }

  void processTelemetrySnapshot(TelemetrySnapshot snapshot) {
    processPoint(snapshot.toFlightPoint());
  }

  void updateSettings(FlightSettings newSettings) {
    _settings = newSettings;
    notifyListeners();
  }

  void reset() {
    _state = FlightState.groundPreflight;
    _preTakeoffBuffer.clear();
    _activeFlightPoints.clear();
    _takeoffConditionStartTime = null;
    _landingConditionStartTime = null;
    _lastCompletedFlight = null;
    _stateController.add(_state);
    notifyListeners();
  }

  void processPoint(FlightPoint point) {
    switch (_state) {
      case FlightState.groundPreflight:
        _handlePreflightPoint(point);
        break;
      case FlightState.flying:
        _handleFlyingPoint(point);
        break;
      case FlightState.landed:
      case FlightState.saved:
        // Do nothing until reset or manual start
        break;
    }
  }

  void _handlePreflightPoint(FlightPoint point) {
    // 1. Maintain circular buffer (15s window)
    _preTakeoffBuffer.add(point);
    final cutoff = point.timestamp.subtract(
      Duration(seconds: _settings.preTakeoffBufferDurationSeconds),
    );
    _preTakeoffBuffer.removeWhere((p) => p.timestamp.isBefore(cutoff));

    // 2. Evaluate takeoff condition
    final speedTrigger = point.speed >= _settings.takeoffSpeedThresholdKmh;
    final varioTrigger = point.vario.abs() >= _settings.takeoffVarioThresholdMs;
    final hagReinforcement = point.hag != null && point.hag! > _settings.takeoffHagThresholdM;

    final isTakeoffConditionMet = speedTrigger || varioTrigger || hagReinforcement;

    if (isTakeoffConditionMet) {
      _takeoffConditionStartTime ??= point.timestamp;
      final sustainedDuration = point.timestamp.difference(_takeoffConditionStartTime!);

      if (sustainedDuration.inSeconds >= _settings.takeoffSustainedDurationSeconds) {
        // Takeoff confirmed! Transition to Flying state
        _state = FlightState.flying;
        _activeFlightPoints.clear();
        _activeFlightPoints.addAll(_preTakeoffBuffer);
        _takeoffConditionStartTime = null;
        _landingConditionStartTime = null;
        _stateController.add(_state);
        notifyListeners();
      }
    } else {
      // Condition interrupted before sustained duration
      _takeoffConditionStartTime = null;
    }
  }

  void _handleFlyingPoint(FlightPoint point) {
    _activeFlightPoints.add(point);
    _pointController.add(point);

    // Evaluate landing condition: groundspeed <= 8 km/h AND |vario| <= 0.4 m/s
    final speedLanded = point.speed <= _settings.landingSpeedThresholdKmh;
    final varioLanded = point.vario.abs() <= _settings.landingVarioThresholdMs;

    if (speedLanded && varioLanded) {
      _landingConditionStartTime ??= point.timestamp;
      final settlingDuration = point.timestamp.difference(_landingConditionStartTime!);

      if (settlingDuration.inSeconds >= _settings.landingSettlingDurationSeconds) {
        // Landing confirmed!
        _finalizeFlight(point.timestamp);
      }
    } else {
      // Pilot still moving or climbing/sinking
      _landingConditionStartTime = null;
    }

    notifyListeners();
  }

  void _finalizeFlight(DateTime landingTime) {
    _state = FlightState.landed;
    final stats = IGCParserService.computeStatistics(_activeFlightPoints);
    final startTime = _activeFlightPoints.isNotEmpty
        ? _activeFlightPoints.first.timestamp
        : landingTime;

    final flightId = 'flight_${startTime.millisecondsSinceEpoch}';
    final title = 'Flight ${startTime.toLocal().toString().substring(0, 16)}';

    var completed = FlightModel(
      id: flightId,
      title: title,
      date: startTime,
      points: List.from(_activeFlightPoints),
      statistics: stats,
      category: FlightCategory.myFlights,
      uploadStatus: UploadStatus.notUploaded,
    );

    final igcString = _igcParser.generateIgc(completed);
    completed = completed.copyWith(rawIgcContent: igcString);

    _lastCompletedFlight = completed;
    _stateController.add(_state);
    _flightCompletedController.add(completed);
    notifyListeners();
  }

  void markAsSaved() {
    _state = FlightState.saved;
    _stateController.add(_state);
    notifyListeners();
  }

  @override
  void dispose() {
    _telemetrySub?.cancel();
    _stateController.close();
    _pointController.close();
    _flightCompletedController.close();
    super.dispose();
  }
}
