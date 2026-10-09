import 'dart:math' as math;
import 'package:brandyfly_native/audio_vario_models.dart';

/// Configuration thresholds for the acoustic vario tone mapping engine.
class ToneMappingConfig {
  const ToneMappingConfig({
    this.climbThresholdMs = 0.2,
    this.sinkThresholdMs = -1.5,
    this.snifferEnabled = false,
    this.snifferLowerBoundMs = -0.3,
    this.snifferUpperBoundMs = 0.1,
    this.masterVolume = 0.8,
    this.isMuted = false,
    this.watchdogTimeoutMs = 250,
  });

  final double climbThresholdMs;
  final double sinkThresholdMs;
  final bool snifferEnabled;
  final double snifferLowerBoundMs;
  final double snifferUpperBoundMs;
  final double masterVolume;
  final bool isMuted;
  final int watchdogTimeoutMs;

  ToneMappingConfig copyWith({
    double? climbThresholdMs,
    double? sinkThresholdMs,
    bool? snifferEnabled,
    double? snifferLowerBoundMs,
    double? snifferUpperBoundMs,
    double? masterVolume,
    bool? isMuted,
    int? watchdogTimeoutMs,
  }) {
    return ToneMappingConfig(
      climbThresholdMs: climbThresholdMs ?? this.climbThresholdMs,
      sinkThresholdMs: sinkThresholdMs ?? this.sinkThresholdMs,
      snifferEnabled: snifferEnabled ?? this.snifferEnabled,
      snifferLowerBoundMs: snifferLowerBoundMs ?? this.snifferLowerBoundMs,
      snifferUpperBoundMs: snifferUpperBoundMs ?? this.snifferUpperBoundMs,
      masterVolume: masterVolume ?? this.masterVolume,
      isMuted: isMuted ?? this.isMuted,
      watchdogTimeoutMs: watchdogTimeoutMs ?? this.watchdogTimeoutMs,
    );
  }
}

/// Pure mathematical mapping from vertical speed (m/s) to acoustic synthesizer tone parameters.
class ToneMappingEngine {
  ToneMappingEngine({ToneMappingConfig? config})
      : _config = config ?? const ToneMappingConfig();

  ToneMappingConfig _config;

  ToneMappingConfig get config => _config;

  void updateConfig(ToneMappingConfig newConfig) {
    _config = newConfig;
  }

  /// Computes the [AudioToneCommand] for a given vertical velocity in m/s.
  AudioToneCommand evaluateVario(double verticalSpeedMs) {
    if (_config.isMuted || _config.masterVolume <= 0.001) {
      return AudioToneCommand.silent.copyWith(isMuted: _config.isMuted);
    }

    // 1. Climb Mode: v >= climbThresholdMs
    if (verticalSpeedMs >= _config.climbThresholdMs) {
      return _computeClimbTone(verticalSpeedMs);
    }

    // 2. Sink Mode: v <= sinkThresholdMs
    if (verticalSpeedMs <= _config.sinkThresholdMs) {
      return _computeSinkTone(verticalSpeedMs);
    }

    // 3. Near-Thermal / Sniffer Mode: -0.3 m/s <= v <= +0.1 m/s
    if (_config.snifferEnabled &&
        verticalSpeedMs >= _config.snifferLowerBoundMs &&
        verticalSpeedMs <= _config.snifferUpperBoundMs) {
      return _computeSnifferTone(verticalSpeedMs);
    }

    // 4. Deadband / Silent
    return AudioToneCommand(
      state: AudioVarioToneState.silent,
      frequencyHz: 0.0,
      cadenceMs: 0,
      dutyCycle: 0.0,
      volume: 0.0,
      isMuted: false,
    );
  }

  AudioToneCommand _computeClimbTone(double v) {
    // Frequency: 450 Hz at +0.2 m/s up to 1800 Hz at +8.0 m/s
    final clampedVForFreq = v.clamp(0.2, 8.0);
    final freqFrac = (clampedVForFreq - 0.2) / (8.0 - 0.2);
    final frequency = 450.0 + freqFrac * (1800.0 - 450.0);

    // Pulse rate: 2.0 Hz at +0.2 m/s up to 12.0 Hz at +6.0 m/s
    final clampedVForRate = v.clamp(0.2, 6.0);
    final rateFrac = (clampedVForRate - 0.2) / (6.0 - 0.2);
    final pulseRateHz = 2.0 + rateFrac * (12.0 - 2.0);
    final cadenceMs = (1000.0 / pulseRateHz).round().clamp(80, 500);

    // Duty cycle: 50% to 60%
    final dutyCycle = 0.50 + 0.10 * rateFrac;

    return AudioToneCommand(
      state: AudioVarioToneState.climb,
      frequencyHz: frequency,
      cadenceMs: cadenceMs,
      dutyCycle: dutyCycle,
      volume: _config.masterVolume,
      isMuted: false,
    );
  }

  AudioToneCommand _computeSinkTone(double v) {
    // Continuous drone (100% duty cycle)
    // Decreases from 300 Hz at -1.5 m/s down to 180 Hz as sink intensifies
    final absSink = v.abs();
    final excessSink = math.max(0.0, absSink - _config.sinkThresholdMs.abs());
    final frequency = math.max(180.0, 300.0 - excessSink * 34.3);

    return AudioToneCommand(
      state: AudioVarioToneState.sink,
      frequencyHz: frequency,
      cadenceMs: 1000,
      dutyCycle: 1.0,
      volume: _config.masterVolume,
      isMuted: false,
    );
  }

  AudioToneCommand _computeSnifferTone(double v) {
    // Low-volume buzzing tone: 400-450 Hz, 500 ms period (2 Hz), 18% duty cycle
    final frac = ((v - _config.snifferLowerBoundMs) /
            (_config.snifferUpperBoundMs - _config.snifferLowerBoundMs))
        .clamp(0.0, 1.0);
    final frequency = 400.0 + frac * 50.0;

    return AudioToneCommand(
      state: AudioVarioToneState.nearThermal,
      frequencyHz: frequency,
      cadenceMs: 500,
      dutyCycle: 0.18,
      volume: (_config.masterVolume * 0.35).clamp(0.0, 1.0),
      isMuted: false,
    );
  }
}
