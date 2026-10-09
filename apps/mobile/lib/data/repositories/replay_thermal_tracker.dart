import '../../domain/thermal_assistant/thermal_assistant_engine.dart';
import '../../models/flight_model.dart';

/// Thermal assistant state for flight replay.
///
/// Feeds every recorded point in order, so the state at any replay index is
/// exactly that of a continuous replay from the start of the flight. Deep
/// copies of the engine are kept as checkpoints every [checkpointInterval]
/// of flight time; a backward seek restores the latest checkpoint at or
/// before the target and replays at most [checkpointInterval] of points.
class ReplayThermalTracker {
  ReplayThermalTracker({this.checkpointInterval = const Duration(seconds: 55)});

  final Duration checkpointInterval;

  ThermalAssistantEngine _engine = ThermalAssistantEngine();
  List<FlightPoint>? _points;
  int _fedIndex = -1;
  int _maxRevision = 0;

  /// Checkpoints keyed by the last fed index (ascending); -1 = fresh engine.
  final List<(int, ThermalAssistantEngine)> _checkpoints = [];
  DateTime? _lastCheckpointTime;

  /// Points fed by the last [advanceTo] call (for cost verification).
  int lastFedCount = 0;

  /// Number of stored checkpoints.
  int get checkpointCount => _checkpoints.length;

  ThermalAssistantState get state => _engine.state;

  /// Discards all state (e.g. when replay is stopped).
  void clear() {
    _points = null;
    _engine = ThermalAssistantEngine();
    _fedIndex = -1;
    _checkpoints.clear();
    _lastCheckpointTime = null;
  }

  /// Returns the thermal assistant state after processing [points] up to and
  /// including [index].
  ThermalAssistantState advanceTo(List<FlightPoint> points, int index) {
    lastFedCount = 0;
    if (!identical(points, _points)) {
      clear();
      _points = points;
      _checkpoints.add((-1, _engine.clone()));
    }
    if (points.isEmpty) return _engine.state;
    final target = index.clamp(0, points.length - 1);

    if (target < _fedIndex) {
      // Restore the latest checkpoint at or before the target.
      var i = _checkpoints.length - 1;
      while (i > 0 && _checkpoints[i].$1 > target) {
        i--;
      }
      final (cpIndex, cpEngine) = _checkpoints[i];
      _maxRevision = _maxRevision > _engine.state.revision
          ? _maxRevision
          : _engine.state.revision;
      _engine = cpEngine.clone()..bumpRevisionPast(_maxRevision);
      _fedIndex = cpIndex;
    }

    while (_fedIndex < target) {
      _fedIndex++;
      final p = points[_fedIndex];
      _engine.update(
        ThermalSample(
          timestampMs: p.timestamp.millisecondsSinceEpoch,
          position: GeoPosition(p.latitude, p.longitude),
          headingDeg: p.heading,
          climbRateMs: p.vario,
        ),
      );
      lastFedCount++;
      _maybeCheckpoint(p.timestamp);
    }
    return _engine.state;
  }

  void _maybeCheckpoint(DateTime t) {
    // Only extend checkpoints beyond the furthest one already stored.
    if (_fedIndex <= _checkpoints.last.$1) return;
    final last = _lastCheckpointTime;
    if (last == null) {
      _lastCheckpointTime = t;
      return;
    }
    if (t.difference(last) >= checkpointInterval) {
      _checkpoints.add((_fedIndex, _engine.clone()));
      _lastCheckpointTime = t;
    }
  }
}
