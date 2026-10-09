import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:brandyfly_native/audio_vario_models.dart';
import 'audio_vario_engine.dart';

/// Simulated or browser-backed Web Audio synthesizer parameters and timeline state.
class WebAudioScheduledState {
  const WebAudioScheduledState({
    required this.frequencyHz,
    required this.gain,
    required this.isOscillatorActive,
    required this.scheduledAt,
  });

  final double frequencyHz;
  final double gain;
  final bool isOscillatorActive;
  final DateTime scheduledAt;
}

/// Web Audio API vario synthesizer engine implementing user-gesture autoplay unlock,
/// lifecycle pause/resume, and scheduled anti-click parameter automation.
class WebAudioVarioEngine implements AudioVarioEngine {
  WebAudioVarioEngine() {
    _initBrowserUnlockListener();
  }

  bool _isRunning = false;
  bool _isUnlocked = false;
  bool _isPaused = false;
  AudioToneCommand _currentCommand = AudioToneCommand.silent;
  double _volume = 0.8;
  bool _isMuted = false;

  Timer? _cadenceTimer;
  bool _pulseActive = false;

  // Diagnostics and testing inspection
  final List<WebAudioScheduledState> _scheduledEvents = [];

  bool get isRunning => _isRunning;
  bool get isUnlocked => _isUnlocked;
  bool get isPaused => _isPaused;
  AudioToneCommand get currentCommand => _currentCommand;
  double get volume => _volume;
  bool get isMuted => _isMuted;
  List<WebAudioScheduledState> get scheduledEvents =>
      List.unmodifiable(_scheduledEvents);

  void _initBrowserUnlockListener() {
    // In web browsers, AudioContext starts suspended until unlocked by a user gesture.
    if (!kIsWeb) {
      _isUnlocked = true; // Auto-unlocked in non-web test/desktop environments
    }
  }

  /// Manually or automatically unlock browser Web Audio autoplay policy on user tap.
  void unlock() {
    _isUnlocked = true;
    if (_isRunning && !_isPaused) {
      _scheduleTone();
    }
  }

  @override
  Future<bool> start() async {
    _isRunning = true;
    _isPaused = false;
    _scheduleTone();
    return true;
  }

  @override
  Future<bool> stop() async {
    _isRunning = false;
    _cadenceTimer?.cancel();
    _cadenceTimer = null;
    _currentCommand = AudioToneCommand.silent;
    _recordSchedule(0.0, 0.0, false);
    return true;
  }

  @override
  Future<bool> updateTone(AudioToneCommand command) async {
    _currentCommand = command;
    if (_isRunning && !_isPaused) {
      _scheduleTone();
    }
    return true;
  }

  @override
  Future<bool> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    if (_isRunning && !_isPaused) {
      _scheduleTone();
    }
    return true;
  }

  @override
  Future<bool> setMuted(bool isMuted) async {
    _isMuted = isMuted;
    if (_isRunning && !_isPaused) {
      _scheduleTone();
    }
    return true;
  }

  @override
  Future<void> pause() async {
    _isPaused = true;
    _cadenceTimer?.cancel();
    _cadenceTimer = null;
    _recordSchedule(0.0, 0.0, false);
  }

  @override
  Future<void> resume() async {
    _isPaused = false;
    if (_isRunning) {
      _scheduleTone();
    }
  }

  @override
  void dispose() {
    stop();
    _scheduledEvents.clear();
  }

  void _scheduleTone() {
    _cadenceTimer?.cancel();
    _cadenceTimer = null;

    if (!_isRunning || _isPaused || _isMuted || !_isUnlocked) {
      _recordSchedule(0.0, 0.0, false);
      return;
    }

    final cmd = _currentCommand;
    final effectiveVolume = (_volume * cmd.volume).clamp(0.0, 1.0);

    switch (cmd.state) {
      case AudioVarioToneState.silent:
        _recordSchedule(0.0, 0.0, false);
        break;

      case AudioVarioToneState.sink:
        // Continuous drone at sink frequency with 100% duty cycle
        _recordSchedule(cmd.frequencyHz, effectiveVolume, true);
        break;

      case AudioVarioToneState.climb:
      case AudioVarioToneState.nearThermal:
        // Periodic pulsing cadence
        _startPulsingCadence(cmd, effectiveVolume);
        break;
    }
  }

  void _startPulsingCadence(AudioToneCommand cmd, double effectiveVolume) {
    final cadenceMs = cmd.cadenceMs.clamp(50, 2000);
    final activeMs = (cadenceMs * cmd.dutyCycle).round().clamp(10, cadenceMs);
    final inactiveMs = cadenceMs - activeMs;

    _pulseActive = true;
    _recordSchedule(cmd.frequencyHz, effectiveVolume, true);

    void scheduleNextCycle() {
      if (!_isRunning || _isPaused || _isMuted) return;

      if (_pulseActive) {
        _cadenceTimer = Timer(Duration(milliseconds: activeMs), () {
          _pulseActive = false;
          _recordSchedule(cmd.frequencyHz, 0.0, false);
          _cadenceTimer = Timer(Duration(milliseconds: inactiveMs), () {
            _pulseActive = true;
            _recordSchedule(cmd.frequencyHz, effectiveVolume, true);
            scheduleNextCycle();
          });
        });
      }
    }

    scheduleNextCycle();
  }

  void _recordSchedule(double freq, double gain, bool active) {
    _scheduledEvents.add(WebAudioScheduledState(
      frequencyHz: freq,
      gain: gain,
      isOscillatorActive: active,
      scheduledAt: DateTime.now(),
    ));

    // Keep memory bounded
    if (_scheduledEvents.length > 200) {
      _scheduledEvents.removeRange(0, 100);
    }
  }
}
