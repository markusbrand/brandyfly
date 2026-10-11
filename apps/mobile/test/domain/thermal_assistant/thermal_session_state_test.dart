import 'package:brandyfly/domain/thermal_assistant/thermal_assistant_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ThermalAssistantEngine session tracking', () {
    test('transitions from gliding to circling and tracks gain, turns, and peak', () {
      final engine = ThermalAssistantEngine();
      expect(engine.state.session, isNull);

      // Feed straight flight (heading 0 deg) for 10 seconds at 1000m
      int t = 1000;
      for (int i = 0; i < 10; i++) {
        engine.update(
          ThermalSample(
            timestampMs: t,
            position: const GeoPosition(47.0, 13.0),
            headingDeg: 0.0,
            climbRateMs: -1.0,
            altitudeM: 1000.0,
          ),
        );
        t += 1000;
      }
      expect(engine.state.isCircling, isFalse);
      expect(engine.state.session, isNull);

      // Start continuous turn: 30 deg/sec to complete 360 deg in 12s, climbing from 1000m to 1036m
      double heading = 0.0;
      double alt = 1000.0;
      for (int i = 0; i < 12; i++) {
        heading = (heading + 30.0) % 360.0;
        alt += 3.0;
        engine.update(
          ThermalSample(
            timestampMs: t,
            position: const GeoPosition(47.0, 13.0),
            headingDeg: heading,
            climbRateMs: 3.0,
            altitudeM: alt,
          ),
        );
        t += 1000;
      }

      // Circling detector triggers once turn >= 270 deg
      expect(engine.state.isCircling, isTrue);
      final session = engine.state.session;
      expect(session, isNotNull);
      expect(session!.isLive, isTrue);
      expect(session.peakClimbMs, 3.0);
      expect(session.turnCount, greaterThanOrEqualTo(1));

      // Continue circling for another full turn with stronger lift (+4.5 m/s)
      for (int i = 0; i < 12; i++) {
        heading = (heading + 30.0) % 360.0;
        alt += 4.5;
        engine.update(
          ThermalSample(
            timestampMs: t,
            position: const GeoPosition(47.0, 13.0),
            headingDeg: heading,
            climbRateMs: 4.5,
            altitudeM: alt,
          ),
        );
        t += 1000;
      }

      final activeSession = engine.state.session;
      expect(activeSession, isNotNull);
      expect(activeSession!.peakClimbMs, 4.5);
      expect(activeSession.turnCount, greaterThanOrEqualTo(2));
      expect(activeSession.altitudeGainM, greaterThan(30.0));
      expect(activeSession.averageClimbMs, greaterThan(2.0));

      // Straighten out for 10 seconds to transition back to gliding
      for (int i = 0; i < 10; i++) {
        alt -= 1.0;
        engine.update(
          ThermalSample(
            timestampMs: t,
            position: const GeoPosition(47.0, 13.0),
            headingDeg: heading, // constant heading
            climbRateMs: -1.0,
            altitudeM: alt,
          ),
        );
        t += 1000;
      }

      // Mode is back to gliding
      expect(engine.state.isCircling, isFalse);

      // Session is preserved as frozen LAST THERMAL
      final frozen = engine.state.session;
      expect(frozen, isNotNull);
      expect(frozen!.isLive, isFalse);
      expect(frozen.turnCount, greaterThanOrEqualTo(2));
      expect(frozen.peakClimbMs, 4.5);
    });
  });
}
