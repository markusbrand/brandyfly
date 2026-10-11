/// UI-facing thermal assistant engine.
///
/// Wraps the parity-tested [ThermalAssistant] and adds presentation state
/// that is not part of the Rust reference: a bounded circling track window,
/// wind estimate age/staleness, and a change revision for cheap rebuilds.
library;

import 'dart:collection';

import 'thermal_assistant.dart';
import 'thermal_session_stats.dart';
import 'thermal_types.dart';

export 'thermal_assistant.dart' show ThermalSample, interruptionGapMs;
export 'thermal_session_stats.dart';
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
    this.session,
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

  /// Performance statistics of the live circling thermal or frozen last thermal.
  final ThermalSessionStats? session;

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

  double? _sessionEntryAlt;
  int? _sessionStartMs;
  double _sessionPeakClimb = 0.0;
  double _sessionAccumTurnDeg = 0.0;
  double? _prevHeadingDeg;
  ThermalSessionStats? _currentSession;
  ThermalSessionStats? _lastCompletedSession;

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
    .._publishedTrack = _publishedTrack
    .._sessionEntryAlt = _sessionEntryAlt
    .._sessionStartMs = _sessionStartMs
    .._sessionPeakClimb = _sessionPeakClimb
    .._sessionAccumTurnDeg = _sessionAccumTurnDeg
    .._prevHeadingDeg = _prevHeadingDeg
    .._currentSession = _currentSession
    .._lastCompletedSession = _lastCompletedSession;

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
      session: _state.session,
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
    _sessionEntryAlt = null;
    _sessionStartMs = null;
    _sessionPeakClimb = 0.0;
    _sessionAccumTurnDeg = 0.0;
    _prevHeadingDeg = null;
    _currentSession = null;
    _lastCompletedSession = null;
    _revision++;
    _state = ThermalAssistantState(
      mode: const FlightModeState.gliding(),
      revision: _revision,
    );
  }

  ThermalAssistantState update(ThermalSample sample) {
    if (sample.stale) return _state;

    final wasCircling = _state.isCircling;
    final t = sample.timestampMs;
    final last = _lastValidMs;
    if (last != null && t - last > interruptionGapMs) {
      _track.clear();
      _lastTrackMs = null;
      if (wasCircling && _currentSession != null) {
        _lastCompletedSession = _currentSession!.copyWith(isLive: false);
      }
      _currentSession = null;
      _sessionEntryAlt = null;
      _sessionStartMs = null;
      _prevHeadingDeg = null;
    }
    _lastValidMs = t;

    final out = _assistant.update(sample);
    if (wasCircling && !out.state.isCircling) {
      _track.clear();
      _lastTrackMs = null;
      if (_currentSession != null) {
        _lastCompletedSession = _currentSession!.copyWith(isLive: false);
      }
      _currentSession = null;
      _sessionEntryAlt = null;
      _sessionStartMs = null;
      _prevHeadingDeg = null;
    }

    if (!wasCircling && out.state.isCircling) {
      _sessionEntryAlt = sample.altitudeM;
      _sessionStartMs = t;
      _sessionPeakClimb = sample.climbRateMs;
      _sessionAccumTurnDeg = 270.0;
      _prevHeadingDeg = sample.headingDeg;
      _currentSession = ThermalSessionStats(
        entryAltitudeM: sample.altitudeM,
        currentAltitudeM: sample.altitudeM,
        altitudeGainM: 0.0,
        averageClimbMs: sample.climbRateMs,
        duration: Duration.zero,
        turnCount: 1,
        peakClimbMs: sample.climbRateMs,
        isLive: true,
      );
    } else if (out.state.isCircling) {
      if (_prevHeadingDeg != null) {
        var diff = (sample.headingDeg - _prevHeadingDeg!).remainder(360.0);
        if (diff > 180.0) diff -= 360.0;
        if (diff < -180.0) diff += 360.0;
        _sessionAccumTurnDeg += diff.abs();
      }
      _prevHeadingDeg = sample.headingDeg;
      if (sample.climbRateMs > _sessionPeakClimb) {
        _sessionPeakClimb = sample.climbRateMs;
      }
      final entryAlt = _sessionEntryAlt ?? sample.altitudeM;
      final startMs = _sessionStartMs ?? t;
      final durationMs = t - startMs;
      final gain = sample.altitudeM - entryAlt;
      final avg = durationMs >= 1000
          ? gain / (durationMs / 1000.0)
          : sample.climbRateMs;
      final turns = (_sessionAccumTurnDeg / 360.0).floor().clamp(1, 999);
      _currentSession = ThermalSessionStats(
        entryAltitudeM: entryAlt,
        currentAltitudeM: sample.altitudeM,
        altitudeGainM: gain,
        averageClimbMs: avg,
        duration: Duration(milliseconds: durationMs),
        turnCount: turns,
        peakClimbMs: _sessionPeakClimb,
        isLive: true,
      );
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

    final session = _currentSession ?? _lastCompletedSession;
    final changed =
        !identical(track, _publishedTrack) ||
        out.state != _state.mode ||
        wind != _state.wind ||
        session != _state.session;
    _publishedTrack = track;
    if (changed) _revision++;

    _state = ThermalAssistantState(
      timestamp: now,
      mode: out.state,
      wind: wind,
      core: out.core?.center,
      track: track,
      revision: _revision,
      session: session,
    );
    return _state;
  }
}
