import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/models/cockpit_telemetry.dart';
import '../../models/flight_model.dart';
import '../../services/elevation_service.dart';
import '../../services/flight_replay_service.dart';
import '../../services/flight_tracking_service.dart';
import '../../services/telemetry/telemetry_source.dart';
import '../../services/telemetry/telemetry_types.dart';

/// Converts the app's telemetry sources (replay, attached live/synthetic
/// source, idle defaults) into one typed [CockpitTelemetry] stream for the UI.
///
/// Emits exactly one notification per source tick. Replay data passes through
/// unchanged so deterministic replay output is preserved.
class TelemetryRepository {
  TelemetryRepository({
    required this._replayService,
    this._trackingService,
    this.elevationService,
    CockpitTelemetry idleTelemetry = const CockpitTelemetry(),
    this.historyLength = 60,
  }) : _idle = idleTelemetry,
       _telemetry = ValueNotifier<CockpitTelemetry>(idleTelemetry) {
    _replayService.addListener(_onReplayChanged);
    _trackingService?.addListener(_onTrackingChanged);
    _emitIdle();
  }

  final FlightReplayService _replayService;
  final FlightTrackingService? _trackingService;
  final ElevationService? elevationService;
  final CockpitTelemetry _idle;
  final int historyLength;
  final ValueNotifier<CockpitTelemetry> _telemetry;

  StreamSubscription<TelemetrySnapshot>? _sourceSub;
  CockpitTelemetry? _liveSample;
  final List<double> _liveHistory = [];
  List<double> _liveHistorySnapshot = const [];
  DateTime? _lastHistorySample;

  double? _lastHag;
  int _elevationQuerySeq = 0;

  /// Altitude history is sampled at most once per [historyInterval] so a
  /// 10-50 Hz source does not allocate a new history list on every tick.
  static const Duration historyInterval = Duration(seconds: 1);
  bool _replayActive = false;
  bool _disposed = false;

  ValueListenable<CockpitTelemetry> get telemetry => _telemetry;

  bool get isReplayActive => _replayActive;

  /// Switches between replay telemetry and live/idle telemetry.
  void setReplayActive(bool active) {
    if (_replayActive == active) return;
    _replayActive = active;
    if (active) {
      _onReplayChanged();
    } else {
      _emitLiveOrIdle();
    }
  }

  /// Uses [source] (synthetic, BLE, internal sensors) for live telemetry.
  void attachSource(ITelemetrySource source) {
    _sourceSub?.cancel();
    _sourceSub = source.telemetryStream.listen(onSnapshot);
  }

  void detachSource() {
    _sourceSub?.cancel();
    _sourceSub = null;
    _liveSample = null;
    _liveHistory.clear();
    _liveHistorySnapshot = const [];
    _lastHistorySample = null;
    _lastHag = null;
    _elevationQuerySeq++;
    _emitLiveOrIdle();
  }

  /// Feeds one live sensor snapshot (exposed for tests and native bridges).
  @visibleForTesting
  void onSnapshot(TelemetrySnapshot s) {
    if (_disposed) return;
    final last = _lastHistorySample;
    if (last == null || s.timestamp.difference(last) >= historyInterval) {
      _lastHistorySample = s.timestamp;
      _liveHistory.add(s.altitude);
      if (_liveHistory.length > historyLength) _liveHistory.removeAt(0);
      _liveHistorySnapshot = List<double>.unmodifiable(_liveHistory);
    }

    double? hag = s.hag;
    if (hag != null) {
      _lastHag = hag;
    } else if (elevationService != null) {
      // 1. Immediate synchronous cache lookup (< 1ms)
      final cachedGroundElev = elevationService!.getCachedElevation(s.latitude, s.longitude);
      if (cachedGroundElev != null) {
        _lastHag = s.altitude - cachedGroundElev;
        hag = _lastHag;
      } else {
        // 2. Cache miss: hold previous HAG to avoid flickering (Task 18)
        hag = _lastHag;
        final querySeq = ++_elevationQuerySeq;
        final alt = s.altitude;
        elevationService!.getElevation(s.latitude, s.longitude).then((groundElev) {
          if (_disposed || querySeq != _elevationQuerySeq) return;
          if (groundElev != null) {
            _lastHag = alt - groundElev;
          } else {
            _lastHag = null;
          }
          if (_liveSample != null && !_replayActive) {
            _liveSample = _liveSample!.copyWith(hag: _lastHag);
            _emitLiveOrIdle();
          }
        });
      }
    } else {
      hag = _lastHag;
    }

    _liveSample = CockpitTelemetry(
      altitude: s.altitude,
      speed: s.speed,
      glide: _idle.glide,
      hag: hag,
      climb: s.vario,
      windDir: s.windDirectionDeg ?? ((s.heading + 180.0) % 360.0),
      windSpeed: s.windSpeedKmh ?? _idle.windSpeed,
      latitude: s.latitude,
      longitude: s.longitude,
      heading: s.heading,
      history: _liveHistorySnapshot,
      isStale: s.isStale || !s.isValid,
    );
    if (!_replayActive) _emitLiveOrIdle();
  }

  void _onReplayChanged() {
    if (_disposed || !_replayActive) return;
    _telemetry.value = CockpitTelemetry.fromMap(_replayService.currentTelemetry);
  }

  void _onTrackingChanged() {
    if (_disposed || _replayActive) return;
    _emitLiveOrIdle();
  }

  void _emitLiveOrIdle() {
    if (_disposed) return;
    final live = _liveSample;
    final flightPoints = _activeFlightPoints;
    _telemetry.value = live != null
        ? live.copyWith(flightPoints: flightPoints)
        : _idle.copyWith(flightPoints: flightPoints);
  }

  void _emitIdle() => _emitLiveOrIdle();

  List<FlightPoint>? get _activeFlightPoints =>
      _trackingService?.activeFlightPoints;

  void dispose() {
    _disposed = true;
    _sourceSub?.cancel();
    _replayService.removeListener(_onReplayChanged);
    _trackingService?.removeListener(_onTrackingChanged);
    _telemetry.dispose();
  }
}
