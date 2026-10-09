/// UI-facing thermal assistant engine.
///
/// Wraps the parity-tested [ThermalAssistant] and adds presentation state
/// that is not part of the Rust reference: a bounded circling track window,
/// wind estimate age/staleness, and a change revision for cheap rebuilds.
library;

import 'dart:collection';

import 'thermal_assistant.dart';
import 'thermal_types.dart';

export 'thermal_assistant.dart' show ThermalSample, interruptionGapMs;
export 'thermal_types.dart';

/// Wind estimate published to the cockpit.
class WindEstimate {
  const WindEstimate({
    required this.directionDeg,
    required this.speedKmh,
    required this.updatedAt,
    required this.isStale,
  });

  /// Meteorological direction the wind comes from (0-360).
  final double directionDeg;
  final double speedKmh;

  /// Time of the last refinement.
  final DateTime updatedAt;

  /// True when the last refinement is older than
  /// [ThermalAssistantEngine.windStaleAfter].
  final bool isStale;

  Duration ageAt(DateTime now) => now.difference(updatedAt);

  @override
  bool operator ==(Object other) =>
      other is WindEstimate &&
      other.directionDeg == directionDeg &&
      other.speedKmh == speedKmh &&
      other.updatedAt == updatedAt &&
      other.isStale == isStale;

  @override
  int get hashCode => Object.hash(directionDeg, speedKmh, updatedAt, isStale);
}

/// One recorded track sample for the thermal map.
class ThermalTrackSample {
  const ThermalTrackSample({
    required this.timestamp,
    required this.position,
    required this.climbRateMs,
  });

  final DateTime timestamp;
  final GeoPosition position;
  final double climbRateMs;
}

/// Immutable thermal assistant state published with each telemetry tick.
class ThermalAssistantState {
  const ThermalAssistantState({
    required this.mode,
    this.timestamp,
    this.wind,
    this.core,
    this.track = const [],
    this.revision = 0,
  });

  static const ThermalAssistantState idle = ThermalAssistantState(
    mode: FlightModeState.gliding(),
  );

  final DateTime? timestamp;
  final FlightModeState mode;
  final WindEstimate? wind;

  /// Estimated thermal core (ground position), only while circling.
  final GeoPosition? core;

  /// Circling track window (oldest first); empty while gliding.
  final List<ThermalTrackSample> track;

  /// Incremented whenever published content changes.
  final int revision;

  bool get isCircling => mode.isCircling;
}

class ThermalAssistantEngine {
  ThermalAssistantEngine();

  /// Maximum retained track window.
  static const Duration maxTrackDuration = Duration(seconds: 300);

  /// Minimum spacing between retained track samples (≤ 1 Hz, ~20 bubbles
  /// per turn - denser trails render as an unreadable solid band).
  static const int trackSampleIntervalMs = 1000;

  /// Wind estimates older than this are marked stale.
  static const Duration windStaleAfter = Duration(minutes: 15);

  ThermalAssistant _assistant = ThermalAssistant();
  final Queue<ThermalTrackSample> _track = Queue<ThermalTrackSample>();
  int? _lastValidMs;
  int? _lastTrackMs;
  int _revision = 0;
  ThermalAssistantState _state = ThermalAssistantState.idle;
  List<ThermalTrackSample> _publishedTrack = const [];

  ThermalAssistantState get state => _state;

  /// Independent deep copy of the full engine state (used for replay
  /// checkpoints). Track samples are immutable and shared.
  ThermalAssistantEngine clone() => ThermalAssistantEngine()
    .._assistant = _assistant.clone()
    .._track.addAll(_track)
    .._lastValidMs = _lastValidMs
    .._lastTrackMs = _lastTrackMs
    .._revision = _revision
    .._state = _state
    .._publishedTrack = _publishedTrack;

  /// Ensures the next published revision is greater than [revision], so UI
  /// selectors rebuild after the engine is replaced by a restored copy.
  void bumpRevisionPast(int revision) {
    if (_revision > revision) return;
    _revision = revision + 1;
    _state = ThermalAssistantState(
      timestamp: _state.timestamp,
      mode: _state.mode,
      wind: _state.wind,
      core: _state.core,
      track: _state.track,
      revision: _revision,
    );
  }

  /// Samples retained by the core calculator (bounded to 60 s).
  int get coreSampleCount => _assistant.coreSampleCount;

  /// Samples retained for the track window (bounded to [maxTrackDuration]).
  int get trackSampleCount => _track.length;

  /// Clears all state including the wind estimate.
  void reset() {
    _assistant = ThermalAssistant();
    _track.clear();
    _lastValidMs = null;
    _lastTrackMs = null;
    _publishedTrack = const [];
    _revision++;
    _state = ThermalAssistantState(
      mode: const FlightModeState.gliding(),
      revision: _revision,
    );
  }

  ThermalAssistantState update(ThermalSample sample) {
    if (sample.stale) return _state;

    final t = sample.timestampMs;
    final last = _lastValidMs;
    if (last != null && t - last > interruptionGapMs) {
      _track.clear();
      _lastTrackMs = null;
    }
    _lastValidMs = t;

    final wasCircling = _state.isCircling;
    final out = _assistant.update(sample);
    if (wasCircling && !out.state.isCircling) {
      _track.clear();
      _lastTrackMs = null;
    }

    var trackChanged = false;
    final lastTrack = _lastTrackMs;
    if (lastTrack == null || t - lastTrack >= trackSampleIntervalMs) {
      _track.addLast(
        ThermalTrackSample(
          timestamp: DateTime.fromMillisecondsSinceEpoch(t, isUtc: true),
          position: sample.position,
          climbRateMs: sample.climbRateMs,
        ),
      );
      _lastTrackMs = t;
      trackChanged = true;
    }
    final cutoff = t - maxTrackDuration.inMilliseconds;
    while (_track.isNotEmpty &&
        _track.first.timestamp.millisecondsSinceEpoch < cutoff) {
      _track.removeFirst();
      trackChanged = true;
    }

    final now = DateTime.fromMillisecondsSinceEpoch(t, isUtc: true);
    WindEstimate? wind;
    final w = out.wind;
    final updatedMs = out.windUpdatedMs;
    if (w != null && updatedMs != null) {
      final updatedAt = DateTime.fromMillisecondsSinceEpoch(
        updatedMs,
        isUtc: true,
      );
      wind = WindEstimate(
        directionDeg: w.directionDeg,
        speedKmh: w.speedKmh,
        updatedAt: updatedAt,
        isStale: now.difference(updatedAt) > windStaleAfter,
      );
    }

    final List<ThermalTrackSample> track;
    if (!out.state.isCircling) {
      track = const [];
    } else if (trackChanged || _publishedTrack.isEmpty) {
      track = List.unmodifiable(_track);
    } else {
      track = _publishedTrack;
    }

    final changed =
        !identical(track, _publishedTrack) ||
        out.state != _state.mode ||
        wind != _state.wind;
    _publishedTrack = track;
    if (changed) _revision++;

    _state = ThermalAssistantState(
      timestamp: now,
      mode: out.state,
      wind: wind,
      core: out.core?.center,
      track: track,
      revision: _revision,
    );
    return _state;
  }
}
