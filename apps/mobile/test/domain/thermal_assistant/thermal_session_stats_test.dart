import 'package:brandyfly/domain/thermal_assistant/thermal_session_stats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ThermalSessionStats', () {
    test('default empty values', () {
      expect(ThermalSessionStats.empty.isLive, isFalse);
      expect(ThermalSessionStats.empty.altitudeGainM, 0.0);
      expect(ThermalSessionStats.empty.averageClimbMs, 0.0);
      expect(ThermalSessionStats.empty.turnCount, 0);
      expect(ThermalSessionStats.empty.duration, Duration.zero);
    });

    test('instantiation and copyWith', () {
      const stats = ThermalSessionStats(
        entryAltitudeM: 1000.0,
        currentAltitudeM: 1350.0,
        altitudeGainM: 350.0,
        averageClimbMs: 2.1,
        duration: Duration(minutes: 2, seconds: 45),
        turnCount: 8,
        peakClimbMs: 4.2,
        isLive: true,
      );

      expect(stats.altitudeGainM, 350.0);
      expect(stats.averageClimbMs, 2.1);
      expect(stats.turnCount, 8);
      expect(stats.peakClimbMs, 4.2);
      expect(stats.isLive, isTrue);

      final frozen = stats.copyWith(isLive: false);
      expect(frozen.isLive, isFalse);
      expect(frozen.altitudeGainM, 350.0);
      expect(frozen.turnCount, 8);
    });

    test('value equality and hashCode', () {
      const a = ThermalSessionStats(
        entryAltitudeM: 1200.0,
        currentAltitudeM: 1400.0,
        altitudeGainM: 200.0,
        averageClimbMs: 1.5,
        duration: Duration(seconds: 130),
        turnCount: 6,
        peakClimbMs: 3.0,
        isLive: true,
      );

      const b = ThermalSessionStats(
        entryAltitudeM: 1200.0,
        currentAltitudeM: 1400.0,
        altitudeGainM: 200.0,
        averageClimbMs: 1.5,
        duration: Duration(seconds: 130),
        turnCount: 6,
        peakClimbMs: 3.0,
        isLive: true,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
