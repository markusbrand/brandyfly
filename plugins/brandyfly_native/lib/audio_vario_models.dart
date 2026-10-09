import 'package:flutter/foundation.dart';

/// Acoustic tone states produced by the audio vario synthesis engine.
enum AudioVarioToneState {
  silent,
  climb,
  sink,
  nearThermal,
}

/// Unified command dispatched to the platform or web audio synthesizer.
@immutable
class AudioToneCommand {
  const AudioToneCommand({
    required this.state,
    required this.frequencyHz,
    required this.cadenceMs,
    required this.dutyCycle,
    this.volume = 0.8,
    this.isMuted = false,
  });

  /// The active acoustic mode.
  final AudioVarioToneState state;

  /// Synthesizer target frequency in Hertz.
  final double frequencyHz;

  /// Total period in milliseconds for pulsing tones.
  final int cadenceMs;

  /// Active sound portion of cadence (0.0 to 1.0). 1.0 is continuous tone.
  final double dutyCycle;

  /// Master volume scaling from 0.0 (silent) to 1.0 (full scale).
  final double volume;

  /// Immediate mute flag.
  final bool isMuted;

  /// Silent tone command.
  static const AudioToneCommand silent = AudioToneCommand(
    state: AudioVarioToneState.silent,
    frequencyHz: 0.0,
    cadenceMs: 0,
    dutyCycle: 0.0,
    volume: 0.0,
    isMuted: false,
  );

  Map<String, Object?> toMap() => {
    'state': state.name,
    'frequencyHz': frequencyHz,
    'cadenceMs': cadenceMs,
    'dutyCycle': dutyCycle,
    'volume': volume,
    'isMuted': isMuted,
  };

  factory AudioToneCommand.fromMap(Map<String, Object?> map) {
    final stateStr = map['state'] as String? ?? 'silent';
    final state = AudioVarioToneState.values.firstWhere(
      (s) => s.name == stateStr,
      orElse: () => AudioVarioToneState.silent,
    );
    return AudioToneCommand(
      state: state,
      frequencyHz: (map['frequencyHz'] as num?)?.toDouble() ?? 0.0,
      cadenceMs: (map['cadenceMs'] as num?)?.toInt() ?? 0,
      dutyCycle: (map['dutyCycle'] as num?)?.toDouble() ?? 0.0,
      volume: (map['volume'] as num?)?.toDouble() ?? 0.8,
      isMuted: (map['isMuted'] as bool?) ?? false,
    );
  }

  AudioToneCommand copyWith({
    AudioVarioToneState? state,
    double? frequencyHz,
    int? cadenceMs,
    double? dutyCycle,
    double? volume,
    bool? isMuted,
  }) {
    return AudioToneCommand(
      state: state ?? this.state,
      frequencyHz: frequencyHz ?? this.frequencyHz,
      cadenceMs: cadenceMs ?? this.cadenceMs,
      dutyCycle: dutyCycle ?? this.dutyCycle,
      volume: volume ?? this.volume,
      isMuted: isMuted ?? this.isMuted,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioToneCommand &&
          runtimeType == other.runtimeType &&
          state == other.state &&
          (frequencyHz - other.frequencyHz).abs() < 0.01 &&
          cadenceMs == other.cadenceMs &&
          (dutyCycle - other.dutyCycle).abs() < 0.01 &&
          (volume - other.volume).abs() < 0.01 &&
          isMuted == other.isMuted;

  @override
  int get hashCode => Object.hash(
    state,
    frequencyHz.round(),
    cadenceMs,
    (dutyCycle * 100).round(),
    (volume * 100).round(),
    isMuted,
  );

  @override
  String toString() {
    return 'AudioToneCommand(state: $state, freq: ${frequencyHz.toStringAsFixed(1)}Hz, cadence: ${cadenceMs}ms, duty: ${dutyCycle.toStringAsFixed(2)}, vol: ${volume.toStringAsFixed(2)}, muted: $isMuted)';
  }
}
