import 'package:brandyfly/data/repositories/telemetry_repository.dart';
import 'package:brandyfly/domain/navigation/geodesic_navigation.dart';
import 'package:brandyfly/models/flight_model.dart';
import 'package:brandyfly/models/flight_settings.dart';
import 'package:brandyfly/services/flight_replay_service.dart';
import 'package:brandyfly/services/flight_tracking_service.dart';
import 'package:brandyfly/services/telemetry/telemetry_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GeodesicNavigation', () {
    test('computes distance between known coordinates accurately', () {
      // Krippenstein launch (approx 47.525, 13.693) to Hallstatt (approx 47.562, 13.649)
      final dist = GeodesicNavigation.distanceMeters(47.525, 13.693, 47.562, 13.649);
      expect(dist, greaterThan(4500));
      expect(dist, lessThan(6000));
    });

    test('computes true bearing accurately', () {
      // Due north
      final bearingNorth = GeodesicNavigation.bearingDegrees(47.0, 13.0, 48.0, 13.0);
      expect(bearingNorth, closeTo(0.0, 0.5));

      // Due east
      final bearingEast = GeodesicNavigation.bearingDegrees(47.0, 13.0, 47.0, 14.0);
      expect(bearingEast, closeTo(90.0, 1.0));
    });

    test('computes required glide ratio with bounds safety', () {
      // 1000m horizontal distance, 200m altitude margin -> glide ratio 5.0
      expect(GeodesicNavigation.requiredGlide(1000.0, 200.0), closeTo(5.0, 0.01));

      // 15m or less distance -> returns null
      expect(GeodesicNavigation.requiredGlide(15.0, 100.0), isNull);
      expect(GeodesicNavigation.requiredGlide(10.0, 100.0), isNull);

      // 0m or negative altitude margin (below target) -> returns null
      expect(GeodesicNavigation.requiredGlide(1000.0, 0.0), isNull);
      expect(GeodesicNavigation.requiredGlide(1000.0, -50.0), isNull);
    });
  });

  group('TelemetryRepository - Flight Timing and RTL', () {
    late FlightReplayService replayService;
    late FlightTrackingService trackingService;
    late TelemetryRepository repository;

    setUp(() {
      replayService = FlightReplayService();
      trackingService = FlightTrackingService(
        settings: const FlightSettings(
          takeoffSpeedThresholdKmh: 12.0,
          takeoffVarioThresholdMs: 0.8,
          takeoffSustainedDurationSeconds: 2,
          landingSpeedThresholdKmh: 8.0,
          landingVarioThresholdMs: 0.4,
          landingSettlingDurationSeconds: 10,
          preTakeoffBufferDurationSeconds: 5,
        ),
      );
      repository = TelemetryRepository(
        replayService: replayService,
        trackingService: trackingService,
      );
    });

    tearDown(() {
      repository.dispose();
      trackingService.dispose();
      replayService.dispose();
    });

    test('emits null flight duration and RTL when in preflight standby', () {
      final initial = repository.telemetry.value;
      expect(initial.takeoffTime, isNull);
      expect(initial.flightDuration, isNull);
      expect(initial.takeoffLocation, isNull);
      expect(initial.takeoffAltitude, isNull);
      expect(initial.rtlDistanceMeters, isNull);
      expect(initial.rtlBearingDegrees, isNull);
      expect(initial.rtlRequiredGlide, isNull);
      expect(initial.rtlAltitudeMarginMeters, isNull);

      // Feed preflight snapshot
      repository.onSnapshot(
        TelemetrySnapshot(
          timestamp: DateTime.utc(2026, 8, 20, 10, 0, 0),
          altitude: 1200.0,
          vario: 0.0,
          speed: 2.0,
          heading: 0.0,
          latitude: 47.52,
          longitude: 13.68,
        ),
      );

      final telemetry = repository.telemetry.value;
      expect(telemetry.hasSource, isTrue);
      expect(telemetry.takeoffTime, isNull);
      expect(telemetry.flightDuration, isNull);
      expect(telemetry.rtlDistanceMeters, isNull);
    });

    test('populates flight timing and RTL metrics once takeoff is triggered', () {
      final baseTime = DateTime.utc(2026, 8, 20, 10, 0, 0);

      // Simulate ground preflight
      for (var i = 0; i < 5; i++) {
        final t = baseTime.add(Duration(seconds: i));
        final pt = FlightPoint(
          timestamp: t,
          latitude: 47.5250,
          longitude: 13.6930,
          altitude: 1500.0,
          speed: 3.0,
          vario: 0.0,
          heading: 45.0,
        );
        trackingService.processPoint(pt);
        repository.onSnapshot(
          TelemetrySnapshot(
            timestamp: t,
            altitude: pt.altitude,
            vario: pt.vario,
            speed: pt.speed,
            heading: pt.heading,
            latitude: pt.latitude,
            longitude: pt.longitude,
          ),
        );
      }

      // Simulate sustained takeoff conditions (3s > 2s sustained threshold)
      for (var i = 5; i < 8; i++) {
        final t = baseTime.add(Duration(seconds: i));
        final pt = FlightPoint(
          timestamp: t,
          latitude: 47.5255,
          longitude: 13.6935,
          altitude: 1520.0,
          speed: 25.0,
          vario: 1.5,
          heading: 45.0,
        );
        trackingService.processPoint(pt);
        repository.onSnapshot(
          TelemetrySnapshot(
            timestamp: t,
            altitude: pt.altitude,
            vario: pt.vario,
            speed: pt.speed,
            heading: pt.heading,
            latitude: pt.latitude,
            longitude: pt.longitude,
          ),
        );
      }

      expect(trackingService.state, FlightState.flying);
      final takeoffPoint = trackingService.takeoffPoint;
      expect(takeoffPoint, isNotNull);

      // Advance flight by 60 seconds away from launch and climbing
      final flightTime = baseTime.add(const Duration(seconds: 68));
      repository.onSnapshot(
        TelemetrySnapshot(
          timestamp: flightTime,
          altitude: 1800.0, // 300m above takeoff
          vario: 1.2,
          speed: 38.0,
          heading: 60.0,
          latitude: 47.5350,
          longitude: 13.7050,
        ),
      );

      final telemetry = repository.telemetry.value;
      expect(telemetry.takeoffTime, isNotNull);
      expect(telemetry.flightDuration, isNotNull);
      expect(telemetry.flightDuration!.inSeconds, greaterThanOrEqualTo(60));
      expect(telemetry.takeoffLocation, isNotNull);
      expect(telemetry.takeoffAltitude, 1500.0);
      expect(telemetry.rtlDistanceMeters, greaterThan(1000.0));
      expect(telemetry.rtlBearingDegrees, isNotNull);
      expect(telemetry.rtlAltitudeMarginMeters, closeTo(300.0, 1.0));
      expect(telemetry.rtlRequiredGlide, isNotNull);
      expect(telemetry.rtlRequiredGlide!, greaterThan(0.0));
    });

    test('sets rtlRequiredGlide to null when sinking below takeoff elevation', () {
      final baseTime = DateTime.utc(2026, 8, 20, 10, 0, 0);

      // Trigger takeoff
      for (var i = 0; i < 4; i++) {
        final t = baseTime.add(Duration(seconds: i));
        final pt = FlightPoint(
          timestamp: t,
          latitude: 47.5250,
          longitude: 13.6930,
          altitude: 1500.0,
          speed: 25.0,
          vario: 1.5,
          heading: 45.0,
        );
        trackingService.processPoint(pt);
        repository.onSnapshot(
          TelemetrySnapshot(
            timestamp: t,
            altitude: pt.altitude,
            vario: pt.vario,
            speed: pt.speed,
            heading: pt.heading,
            latitude: pt.latitude,
            longitude: pt.longitude,
          ),
        );
      }

      // Aircraft descends below takeoff altitude (1400m vs 1500m launch)
      final flightTime = baseTime.add(const Duration(seconds: 30));
      repository.onSnapshot(
        TelemetrySnapshot(
          timestamp: flightTime,
          altitude: 1400.0,
          vario: -1.5,
          speed: 35.0,
          heading: 45.0,
          latitude: 47.5300,
          longitude: 13.7000,
        ),
      );

      final telemetry = repository.telemetry.value;
      expect(telemetry.rtlAltitudeMarginMeters, closeTo(-100.0, 1.0));
      expect(telemetry.rtlRequiredGlide, isNull);
      expect(telemetry.rtlDistanceMeters, greaterThan(500.0));
    });

    test('computes deterministic flight timing and RTL during IGC flight replay', () {
      final baseTime = DateTime.utc(2026, 8, 20, 12, 0, 0);
      final recordedPoints = [
        FlightPoint(
          timestamp: baseTime,
          latitude: 47.5250,
          longitude: 13.6930,
          altitude: 1500.0,
          speed: 20.0,
          vario: 1.0,
          heading: 45.0,
        ),
        FlightPoint(
          timestamp: baseTime.add(const Duration(seconds: 30)),
          latitude: 47.5300,
          longitude: 13.7000,
          altitude: 1650.0,
          speed: 36.0,
          vario: 1.5,
          heading: 45.0,
        ),
        FlightPoint(
          timestamp: baseTime.add(const Duration(seconds: 60)),
          latitude: 47.5350,
          longitude: 13.7050,
          altitude: 1800.0,
          speed: 38.0,
          vario: 2.0,
          heading: 45.0,
        ),
      ];

      final flight = FlightModel(
        id: 'test-flight-1',
        title: 'Test Flight',
        date: baseTime,
        points: recordedPoints,
        statistics: const FlightStatistics(
          duration: Duration(seconds: 60),
          maxAltitude: 1800.0,
          minAltitude: 1500.0,
          maxClimbRate: 2.0,
          maxSinkRate: 0.0,
          totalDistanceKm: 2.0,
          averageSpeedKmh: 35.0,
          averageGlideRatio: 8.0,
        ),
      );

      repository.setReplayActive(true);
      replayService.loadFlight(flight);

      // Initial point
      final initial = repository.telemetry.value;
      expect(initial.takeoffTime, baseTime);
      expect(initial.flightDuration, Duration.zero);
      expect(initial.takeoffAltitude, 1500.0);
      expect(initial.rtlDistanceMeters, 0.0); // within 15m
      expect(initial.rtlRequiredGlide, isNull);

      // Advance replay to step 2 (30 seconds in)
      replayService.advance(1);
      final step1 = repository.telemetry.value;
      expect(step1.flightDuration, const Duration(seconds: 30));
      expect(step1.rtlDistanceMeters, greaterThan(500.0));
      expect(step1.rtlAltitudeMarginMeters, closeTo(150.0, 1.0));
      expect(step1.rtlRequiredGlide, isNotNull);
      expect(step1.rtlBearingDegrees, isNotNull);

      // Advance replay to final step (60 seconds in)
      replayService.advance(1);
      final step2 = repository.telemetry.value;
      expect(step2.flightDuration, const Duration(seconds: 60));
      expect(step2.rtlAltitudeMarginMeters, closeTo(300.0, 1.0));
      expect(step2.rtlRequiredGlide, isNotNull);
    });
  });
}
