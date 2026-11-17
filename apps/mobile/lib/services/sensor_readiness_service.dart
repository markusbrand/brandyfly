import 'dart:async';

import 'package:brandyfly_native/brandyfly_native.dart';
import 'package:flutter/foundation.dart';

import '../data/repositories/telemetry_repository.dart';
import '../domain/models/sensor_readiness.dart';
import 'telemetry/telemetry_types.dart';

/// Asynchronous native capability probe function (injectable for tests).
typedef SensorCapabilityProbe = Future<NativeSensorCapabilities> Function();

/// Evaluates and publishes live flight sensor readiness for the application shell.
///
/// Combines platform hardware/permission capability probes with live
/// [TelemetryRepository] snapshots and external Bluetooth vario link state.
class SensorReadinessService extends ChangeNotifier {
  SensorReadinessService({
    required TelemetryRepository telemetryRepository,
    SensorCapabilityProbe? probeCapabilities,
    BrandyflyNative native = const BrandyflyNative(),
    bool isMockFlightMode = false,
    this.stalenessThreshold =
        SensorReadinessEvaluator.defaultStalenessThreshold,
    DateTime Function()? clock,
    bool enableWatchdog = true,
  })  : _telemetryRepository = telemetryRepository,
        _probeCapabilities =
            probeCapabilities ?? (() => native.getSensorCapabilities()),
        _clock = clock ?? DateTime.now {
    _input = LiveSensorInput(
      isMockFlightMode: isMockFlightMode,
      isReplayActive: telemetryRepository.isReplayActive,
    );
    _state = SensorReadinessEvaluator.evaluate(
      capabilities: _capabilities,
      input: _input,
      now: _clock(),
      stalenessThreshold: stalenessThreshold,
    );
    _telemetryRepository.telemetry.addListener(_onTelemetryChanged);
    _telemetryRepository.replayActive.addListener(_onReplayChanged);
    _onTelemetryChanged();
    if (enableWatchdog) {
      _watchdogTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => _reevaluate(),
      );
    }
  }

  final TelemetryRepository _telemetryRepository;
  final SensorCapabilityProbe _probeCapabilities;
  final Duration stalenessThreshold;
  final DateTime Function() _clock;

  SensorCapabilities _capabilities = SensorCapabilities.unknown;
  late LiveSensorInput _input;
  late SensorReadinessState _state;
  Timer? _watchdogTimer;
  bool _disposed = false;

  SensorReadinessState get state => _state;
  SensorCapabilities get capabilities => _capabilities;

  /// Probes device sensor hardware and OS permission capabilities.
  Future<void> refreshCapabilities() async {
    if (_disposed) return;
    try {
      final nativeCaps = await _probeCapabilities();
      if (_disposed) return;
      _capabilities = SensorCapabilities(
        hasBarometer: nativeCaps.hasBarometer,
        hasGps: nativeCaps.hasGps,
        locationEnabled: nativeCaps.locationEnabled,
        locationPermissionGranted: nativeCaps.locationPermissionGranted,
        bluetoothAvailable: nativeCaps.bluetoothAvailable,
        isCapabilityKnown: nativeCaps.isCapabilityKnown,
      );
      _reevaluate();
    } catch (_) {
      // Preserve last known capabilities if a platform probe fails unexpectedly.
    }
  }

  /// Updates external Bluetooth vario connection status (e.g. SkyDrop 1 / BLE).
  void updateExternalVarioState(
    ExternalVarioConnectionState connectionState, {
    bool isExternalSource = true,
  }) {
    if (_disposed) return;
    final isDisconnected =
        connectionState == ExternalVarioConnectionState.disconnected ||
            connectionState == ExternalVarioConnectionState.reconnecting ||
            connectionState == ExternalVarioConnectionState.error;

    if (isDisconnected && isExternalSource) {
      _input = _input.copyWith(
        isExternalVarioSource: true,
        externalVarioState: connectionState,
        hasBaroSample: false,
        lastBaroSampleAt: null,
      );
    } else {
      _input = _input.copyWith(
        isExternalVarioSource: isExternalSource,
        externalVarioState: connectionState,
      );
    }
    _reevaluate();
  }

  /// Updates whether local mock/synthetic flight simulation mode is active.
  void setMockFlightMode(bool enabled) {
    if (_disposed || _input.isMockFlightMode == enabled) return;
    _input = _input.copyWith(isMockFlightMode: enabled);
    _reevaluate();
  }

  /// Forces an immediate staleness & readiness check (useful in deterministic tests).
  @visibleForTesting
  void checkReadinessNow() => _reevaluate();

  void _onReplayChanged() {
    if (_disposed) return;
    final isReplay = _telemetryRepository.isReplayActive;
    if (_input.isReplayActive != isReplay) {
      _input = _input.copyWith(isReplayActive: isReplay);
      _reevaluate();
    }
  }

  void _onTelemetryChanged() {
    if (_disposed) return;
    final snap = _telemetryRepository.telemetry.value;
    final isReplay = _telemetryRepository.isReplayActive;

    if (isReplay || _input.isMockFlightMode) {
      _input = _input.copyWith(isReplayActive: isReplay);
      _reevaluate();
      return;
    }

    final sourceType = _telemetryRepository.attachedSourceType;
    final isExternal =
        sourceType == TelemetrySourceType.ble || _input.isExternalVarioSource;

    if (!snap.hasSource) {
      _input = _input.copyWith(
        isReplayActive: false,
        hasLiveSource: false,
        isExternalVarioSource: isExternal,
        hasBaroSample: false,
        lastBaroSampleAt: null,
        hasGpsSample: false,
        lastGpsSampleAt: null,
        isSampleValid: false,
        isSampleStale: false,
      );
      _reevaluate();
      return;
    }

    final now = _clock();
    final isValid = _telemetryRepository.latestSnapshotValid;
    final isFresh = isValid && !snap.isStale;
    final hasBaro = _telemetryRepository.latestPressureHpa != null ||
        sourceType == TelemetrySourceType.ble ||
        (sourceType == TelemetrySourceType.internalSensor &&
            _capabilities.hasBarometer);
    final hasGps =
        LiveSensorInput.isValidGpsCoordinates(snap.latitude, snap.longitude);

    final nextExtState = (sourceType == TelemetrySourceType.ble &&
            isFresh &&
            _input.externalVarioState == ExternalVarioConnectionState.none)
        ? ExternalVarioConnectionState.connected
        : _input.externalVarioState;

    _input = _input.copyWith(
      isReplayActive: false,
      hasLiveSource: true,
      isExternalVarioSource: isExternal,
      externalVarioState: nextExtState,
      hasBaroSample: isFresh ? hasBaro : _input.hasBaroSample,
      lastBaroSampleAt:
          (isFresh && hasBaro) ? now : _input.lastBaroSampleAt,
      hasGpsSample: isFresh ? hasGps : _input.hasGpsSample,
      lastGpsSampleAt: (isFresh && hasGps) ? now : _input.lastGpsSampleAt,
      isSampleValid: isValid,
      isSampleStale: snap.isStale,
    );
    _reevaluate();
  }

  void _reevaluate() {
    if (_disposed) return;
    final next = SensorReadinessEvaluator.evaluate(
      capabilities: _capabilities,
      input: _input,
      now: _clock(),
      stalenessThreshold: stalenessThreshold,
    );
    if (next != _state) {
      _state = next;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _watchdogTimer?.cancel();
    _telemetryRepository.telemetry.removeListener(_onTelemetryChanged);
    _telemetryRepository.replayActive.removeListener(_onReplayChanged);
    super.dispose();
  }
}
