import 'dart:math' as math;
import 'dart:ui' show Offset;

import '../../../../domain/thermal_assistant/thermal_assistant_engine.dart';
import 'thermal_map_widget.dart';

/// Converts thermal assistant state into pilot-relative canvas data for
/// [ThermalMapWidget] (1 unit = 1 m, dx east, dy south).
///
/// Memoizes on the state revision, pilot position and history window so a
/// rebuild without new track data does not re-project the track.
class ThermalMapAdapter {
  static const double _rEarth = 6371000.0;

  int? _revision;
  double? _lat;
  double? _lon;
  int? _historySeconds;
  List<ThermalPoint> _points = const [];
  Offset? _core;

  List<ThermalPoint> get points => _points;
  Offset? get core => _core;

  /// Projects [state] relative to the pilot at ([pilotLat], [pilotLon]).
  void update(
    ThermalAssistantState state, {
    required double? pilotLat,
    required double? pilotLon,
    required int historySeconds,
  }) {
    if (_revision == state.revision &&
        _lat == pilotLat &&
        _lon == pilotLon &&
        _historySeconds == historySeconds) {
      return;
    }
    _revision = state.revision;
    _lat = pilotLat;
    _lon = pilotLon;
    _historySeconds = historySeconds;

    final track = state.track;
    final refLat =
        pilotLat ?? (track.isNotEmpty ? track.last.position.lat : null);
    final refLon =
        pilotLon ?? (track.isNotEmpty ? track.last.position.lon : null);
    if (refLat == null || refLon == null) {
      _points = const [];
      _core = null;
      return;
    }

    final cosLat = math.cos(refLat * math.pi / 180.0);
    Offset project(GeoPosition p) {
      final east = (p.lon - refLon) * math.pi / 180.0 * _rEarth * cosLat;
      final north = (p.lat - refLat) * math.pi / 180.0 * _rEarth;
      return Offset(east, -north);
    }

    final now = state.timestamp;
    final cutoff = now?.subtract(Duration(seconds: historySeconds));
    final points = <ThermalPoint>[];
    for (final s in track) {
      if (cutoff != null && s.timestamp.isBefore(cutoff)) continue;
      final o = project(s.position);
      points.add(
        ThermalPoint(
          dx: o.dx,
          dy: o.dy,
          climbRateMs: s.climbRateMs,
          timestamp: s.timestamp,
        ),
      );
    }
    _points = List.unmodifiable(points);
    final core = state.core;
    _core = core != null ? project(core) : null;
  }
}
