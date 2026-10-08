import 'package:flutter_test/flutter_test.dart';
import 'package:brandyfly/models/flight_model.dart';
import 'package:brandyfly/models/flight_settings.dart';
import 'package:brandyfly/services/airspace_service.dart';
import 'package:brandyfly/services/flight_tracking_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AirspaceService Tests', () {
    late AirspaceService airspaceService;

    setUp(() {
      airspaceService = AirspaceService();
    });

    tearDown(() {
      airspaceService.dispose();
    });

    test('Initial state is clear and empty', () {
      expect(airspaceService.loadedAirspaces, isEmpty);
      expect(airspaceService.activeAlertLevel, AirspaceAlertLevel.clear);
      expect(airspaceService.latestProximity.alertLevel, AirspaceAlertLevel.clear);
    });

    test('Load DACH fixture loads airspaces and updates state', () async {
      final count = await airspaceService.loadDachFixture();
      expect(count, greaterThanOrEqualTo(3));
      expect(airspaceService.loadedAirspaces, isNotEmpty);

      final first = airspaceService.loadedAirspaces.first;
      expect(first.name, contains('CTR'));
      expect(first.polygon.length, greaterThanOrEqualTo(4));
    });

    test('Clear airspaces resets state to clear', () async {
      await airspaceService.loadDachFixture();
      expect(airspaceService.loadedAirspaces, isNotEmpty);

      await airspaceService.clearAirspaces();
      expect(airspaceService.loadedAirspaces, isEmpty);
      expect(airspaceService.activeAlertLevel, AirspaceAlertLevel.clear);
    });

    test('Loads custom OpenAir text with comments and multiple zones', () async {
      const openAirData = '''
* Comment header
AC R
AN TEST RESTRICTED
AL 1000FT AGL
AH FL 100
DP 47:30:00 N 011:00:00 E
DP 47:35:00 N 011:00:00 E
DP 47:35:00 N 011:10:00 E
DP 47:30:00 N 011:10:00 E
''';

      final count = await airspaceService.loadOpenAirText(openAirData);
      expect(count, 1);
      expect(airspaceService.loadedAirspaces.length, 1);
      expect(airspaceService.loadedAirspaces.first.name, 'TEST RESTRICTED');
      expect(airspaceService.loadedAirspaces.first.airspaceClass, 'R');
    });

    test('Calculates forward airspace blocks along heading', () async {
      await airspaceService.loadDachFixture();

      // Heading 90 (East) towards Innsbruck CTR
      final blocks = airspaceService.getForwardAirspaces(
        lat: 47.26,
        lon: 11.00,
        altitudeMsl: 1000.0,
        headingDeg: 90.0,
        lookaheadDistanceM: 15000.0,
        glideRatio: 8.0,
      );

      expect(blocks, isNotEmpty);
      expect(blocks.first.entryDistanceM, greaterThan(0));
    });

    test('Reactive proximityStream and alertStream emit on point processing', () async {
      await airspaceService.loadDachFixture();

      final states = <AirspaceProximityState>[];
      final alerts = <AirspaceAlertLevel>[];

      final sub1 = airspaceService.proximityStream.listen(states.add);
      final sub2 = airspaceService.alertStream.listen(alerts.add);

      final point = FlightPoint(
        latitude: 47.26,
        longitude: 11.25,
        altitude: 1000.0,
        timestamp: DateTime.now(),
        speed: 12.0,
        heading: 90.0,
        vario: 0.5,
      );

      await airspaceService.processFlightPoint(point);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(states, isNotEmpty);
      expect(alerts, isNotEmpty);

      await sub1.cancel();
      await sub2.cancel();
    });

    test('Integration with FlightTrackingService processes streamed points', () async {
      await airspaceService.loadDachFixture();
      final trackingService = FlightTrackingService(
        settings: const FlightSettings(
          takeoffSpeedThresholdKmh: 5.0,
          takeoffSustainedDurationSeconds: 0,
        ),
      );
      airspaceService.attachFlightTrackingService(trackingService);

      final alerts = <AirspaceAlertLevel>[];
      final sub = airspaceService.alertStream.listen(alerts.add);

      // Point 1: triggers takeoff
      final t0 = DateTime.now();
      trackingService.processPoint(FlightPoint(
        latitude: 47.26,
        longitude: 11.25,
        altitude: 1000.0,
        timestamp: t0,
        speed: 20.0,
        heading: 90.0,
        vario: 1.0,
      ));

      // Point 2: processed in flying state
      trackingService.processPoint(FlightPoint(
        latitude: 47.26,
        longitude: 11.25,
        altitude: 1000.0,
        timestamp: t0.add(const Duration(seconds: 1)),
        speed: 20.0,
        heading: 90.0,
        vario: 1.0,
      ));

      // Wait a tick for event delivery
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(alerts, isNotEmpty);

      await sub.cancel();
      airspaceService.detachFlightTrackingService();
      trackingService.dispose();
    });

    test('Error recovery: corrupt OpenAir data returns 0 and does not throw', () async {
      final count = await airspaceService.loadOpenAirText('INVALID RANDOM CORRUPT TEXT');
      expect(count, 0);
      expect(airspaceService.loadedAirspaces, isEmpty);
    });
  });
}
