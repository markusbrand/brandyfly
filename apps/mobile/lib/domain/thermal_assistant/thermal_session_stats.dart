/// Immutable representation of thermal circling session performance metrics.
library;

class ThermalSessionStats {
  const ThermalSessionStats({
    required this.entryAltitudeM,
    required this.currentAltitudeM,
    required this.altitudeGainM,
    required this.averageClimbMs,
    required this.duration,
    required this.turnCount,
    required this.peakClimbMs,
    this.isLive = true,
  });

  static const ThermalSessionStats empty = ThermalSessionStats(
    entryAltitudeM: 0.0,
    currentAltitudeM: 0.0,
    altitudeGainM: 0.0,
    averageClimbMs: 0.0,
    duration: Duration.zero,
    turnCount: 0,
    peakClimbMs: 0.0,
    isLive: false,
  );

  /// Altitude (MSL in meters) when circling began.
  final double entryAltitudeM;

  /// Current altitude (MSL in meters).
  final double currentAltitudeM;

  /// Net altitude gained since entering the thermal (current - entry).
  final double altitudeGainM;

  /// Average climb rate across the active or completed thermal session (m/s).
  final double averageClimbMs;

  /// Elapsed duration spent circling in this thermal.
  final Duration duration;

  /// Estimated number of complete turns flown in this thermal.
  final int turnCount;

  /// Maximum instantaneous climb rate encountered during the thermal session.
  final double peakClimbMs;

  /// True when the pilot is currently circling in this thermal;
  /// false when retained as the frozen "LAST THERMAL" during glide.
  final bool isLive;

  ThermalSessionStats copyWith({
    double? entryAltitudeM,
    double? currentAltitudeM,
    double? altitudeGainM,
    double? averageClimbMs,
    Duration? duration,
    int? turnCount,
    double? peakClimbMs,
    bool? isLive,
  }) {
    return ThermalSessionStats(
      entryAltitudeM: entryAltitudeM ?? this.entryAltitudeM,
      currentAltitudeM: currentAltitudeM ?? this.currentAltitudeM,
      altitudeGainM: altitudeGainM ?? this.altitudeGainM,
      averageClimbMs: averageClimbMs ?? this.averageClimbMs,
      duration: duration ?? this.duration,
      turnCount: turnCount ?? this.turnCount,
      peakClimbMs: peakClimbMs ?? this.peakClimbMs,
      isLive: isLive ?? this.isLive,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ThermalSessionStats &&
          runtimeType == other.runtimeType &&
          entryAltitudeM == other.entryAltitudeM &&
          currentAltitudeM == other.currentAltitudeM &&
          altitudeGainM == other.altitudeGainM &&
          averageClimbMs == other.averageClimbMs &&
          duration == other.duration &&
          turnCount == other.turnCount &&
          peakClimbMs == other.peakClimbMs &&
          isLive == other.isLive;

  @override
  int get hashCode => Object.hash(
        entryAltitudeM,
        currentAltitudeM,
        altitudeGainM,
        averageClimbMs,
        duration,
        turnCount,
        peakClimbMs,
        isLive,
      );

  @override
  String toString() =>
      'ThermalSessionStats(gain: ${altitudeGainM.toStringAsFixed(1)}m, '
      'avg: ${averageClimbMs.toStringAsFixed(2)}m/s, '
      'duration: ${duration.inSeconds}s, '
      'turns: $turnCount, '
      'peak: ${peakClimbMs.toStringAsFixed(1)}m/s, '
      'isLive: $isLive)';
}
