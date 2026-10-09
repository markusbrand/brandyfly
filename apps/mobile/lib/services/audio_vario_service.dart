import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:brandyfly_native/audio_vario_models.dart';
import '../models/flight_settings.dart';
import 'audio/audio_vario_engine.dart';
import 'audio/tone_mapping_engine.dart';
import 'audio/web_audio_synthesizer.dart';
import 'flight_tracking_service.dart';

/// Coordinates real-time flight telemetry updates with platform audio synthesis engines.
class AudioVarioService extends ChangeNotifier {
  AudioVarioService({
    AudioVarioEngine? engine,
    ToneMappingEngine? toneEngine,
    FlightSettings? initialSettings,
  })  : _engine = engine ?? (kIsWeb ? WebAudioVarioEngine() : NativeAudioVarioEngine()),
        _toneEngine = toneEngine ?? ToneMappingEngine() {
    if (initialSettings != null) {
      updateSettings(initialSettings);
    }
  }

  final AudioVarioEngine _engine;
  final ToneMappingEngine _toneEngine;

  bool _isRunning = false;
  bool _isMuted = false;
  bool _disposed = false;
  double _volume = 0.8;
  AudioToneCommand _currentTone = AudioToneCommand.silent;

  Timer? _watchdogTimer;
  StreamSubscription? _trackingSubscription;

  bool get isRunning => _isRunning;
  bool get isMuted => _isMuted;
  double get volume => _volume;
  AudioToneCommand get currentTone => _currentTone;
  ToneMappingConfig get config => _toneEngine.config;
  AudioVarioEngine get engine => _engine;

  /// Starts the acoustic vario synthesizer engine.
  Future<bool> start() async {
    if (_isRunning) return true;
    final started = await _engine.start();
    if (started) {
      _isRunning = true;
      await _engine.setVolume(_volume);
      await _engine.setMuted(_isMuted);
      if (!_disposed) {
        notifyListeners();
      }
    }
    return started;
  }

  /// Stops the acoustic vario synthesizer engine and clears watchdog.
  Future<bool> stop() async {
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
    _currentTone = AudioToneCommand.silent;
    final stopped = await _engine.stop();
    _isRunning = false;
    if (!_disposed) {
      notifyListeners();
    }
    return stopped;
  }

  /// Ingests a vertical speed telemetry update (m/s) and modulates audio output.
  void processVario(double varioMps) {
    if (!_isRunning) return;

    _resetWatchdog();

    final cmd = _toneEngine.evaluateVario(varioMps);
    if (cmd != _currentTone) {
      _currentTone = cmd;
      _engine.updateTone(cmd);
      if (!_disposed) {
        notifyListeners();
      }
    }
  }

  /// Toggles mute state on/off.
  Future<void> toggleMute() async {
    await setMuted(!_isMuted);
  }

  /// Sets mute state explicitly.
  Future<void> setMuted(bool muted) async {
    if (_isMuted == muted) return;
    _isMuted = muted;
    _toneEngine.updateConfig(_toneEngine.config.copyWith(isMuted: muted));
    await _engine.setMuted(muted);
    if (muted) {
      _currentTone = AudioToneCommand.silent.copyWith(isMuted: true);
      await _engine.updateTone(_currentTone);
    }
    if (!_disposed) {
      notifyListeners();
    }
  }

  /// Sets master volume [0.0, 1.0].
  Future<void> setVolume(double vol) async {
    final clamped = vol.clamp(0.0, 1.0);
    if ((_volume - clamped).abs() < 0.001) return;
    _volume = clamped;
    _toneEngine.updateConfig(_toneEngine.config.copyWith(masterVolume: clamped));
    await _engine.setVolume(clamped);
    if (!_disposed) {
      notifyListeners();
    }
  }

  /// Synchronizes acoustic vario configuration with pilot flight preferences.
  void updateSettings(FlightSettings settings) {
    _volume = settings.varioVolume.clamp(0.0, 1.0);
    _isMuted = !settings.varioAudioEnabled;

    _toneEngine.updateConfig(_toneEngine.config.copyWith(
      climbThresholdMs: settings.varioClimbThresholdMs,
      sinkThresholdMs: settings.varioSinkThresholdMs,
      snifferEnabled: settings.varioSnifferEnabled,
      masterVolume: _volume,
      isMuted: _isMuted,
    ));

    _engine.setVolume(_volume);
    _engine.setMuted(_isMuted);

    if (_isMuted) {
      _currentTone = AudioToneCommand.silent.copyWith(isMuted: true);
      _engine.updateTone(_currentTone);
    }
    if (!_disposed) {
      notifyListeners();
    }
  }

  VoidCallback? _trackingSettingsListener;

  /// Connects to [FlightTrackingService] to automatically synthesize flight audio.
  void attachTrackingService(FlightTrackingService trackingService) {
    detachTrackingService();
    updateSettings(trackingService.settings);

    _trackingSubscription = trackingService.varioStream.listen((vario) {
      processVario(vario);
    });

    _trackingSettingsListener = () {
      updateSettings(trackingService.settings);
    };
    trackingService.addListener(_trackingSettingsListener!);
  }

  /// Detaches from [FlightTrackingService].
  void detachTrackingService() {
    _trackingSubscription?.cancel();
    _trackingSubscription = null;
    _trackingSettingsListener = null;
  }

  /// Responds to app lifecycle transitions (e.g. backgrounding, foregrounding).
  void handleAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        _engine.pause();
        break;
      case AppLifecycleState.resumed:
        _engine.resume();
        break;
      case AppLifecycleState.detached:
        stop();
        break;
    }
  }

  void _resetWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer(
      Duration(milliseconds: _toneEngine.config.watchdogTimeoutMs),
      _onWatchdogTimeout,
    );
  }

  void _onWatchdogTimeout() {
    if (!_isRunning) return;
    if (_currentTone.state != AudioVarioToneState.silent) {
      _currentTone = AudioToneCommand.silent;
      _engine.updateTone(_currentTone);
      if (!_disposed) {
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
    detachTrackingService();
    _engine.stop();
    _engine.dispose();
    super.dispose();
  }
}
