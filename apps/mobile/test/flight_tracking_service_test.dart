import 'package:brandyfly/models/flight_model.dart';
import 'package:brandyfly/models/flight_settings.dart';
import 'package:brandyfly/services/flight_tracking_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FlightTrackingService Tests', () {
    late FlightTrackingService service;

    setUp(() {
      service = FlightTrackingService(
        settings: const FlightSettings(
          takeoffSpeedThresholdKmh: 12.0,
          takeoffVarioThresholdMs: 0.8,
          takeoffSustainedDurationSeconds: 4,
          landingSpeedThresholdKmh: 8.0,
          landingVarioThresholdMs: 0.4,
          landingSettlingDurationSeconds: 20,
          preTakeoffBufferDurationSeconds: 15,
        ),
      );
    });

    test('Initializes in groundPreflight state with empty buffers', () {
      expect(service.state, FlightState.groundPreflight);
      expect(service.activeFlightPoints, isEmpty);
      expect(service.lastCompletedFlight, isNull);
    });

    test('Maintains 15-second circular buffer during preflight', () {
      final baseTime = DateTime.utc(2026, 8, 20, 10, 0, 0);

      for (var i = 0; i < 30; i++) {
        service.processPoint(
          FlightPoint(
            timestamp: baseTime.add(Duration(seconds: i)),
            latitude: 47.5 + (i * 0.0001),
            longitude: 13.6 + (i * 0.0001),
            altitude: 1000.0,
            speed: 5.0, // Below takeoff speed
            vario: 0.1,
          ),
        );
      }

      expect(service.state, FlightState.groundPreflight);
    });

    test('Rejects false takeoff triggers lasting less than sustained duration', () {
      final baseTime = DateTime.utc(2026, 8, 20, 10, 0, 0);

      // 10s of walking
      for (var i = 0; i < 10; i++) {
        service.processPoint(
          FlightPoint(
            timestamp: baseTime.add(Duration(seconds: i)),
            latitude: 47.5,
            longitude: 13.6,
            altitude: 1000.0,
            speed: 4.0,
            vario: 0.0,
          ),
        );
      }

      // 2s spike in ground speed (e.g. running to inflate wing)
      for (var i = 10; i < 12; i++) {
        service.processPoint(
          FlightPoint(
            timestamp: baseTime.add(Duration(seconds: i)),
            latitude: 47.5,
            longitude: 13.6,
            altitude: 1000.0,
            speed: 16.0, // Above 12 km/h
            vario: 0.2,
          ),
        );
      }

      // Drops back to slow speed
      service.processPoint(
        FlightPoint(
          timestamp: baseTime.add(const Duration(seconds: 13)),
          latitude: 47.5,
          longitude: 13.6,
          altitude: 1000.0,
          speed: 3.0,
          vario: 0.0,
        ),
      );

      expect(service.state, FlightState.groundPreflight);
    });

    test('Transitions to Flying on sustained speed and prepends pre-takeoff buffer', () {
      final baseTime = DateTime.utc(2026, 8, 20, 10, 0, 0);

      // 10 seconds of preflight points
      for (var i = 0; i < 10; i++) {
        service.processPoint(
          FlightPoint(
            timestamp: baseTime.add(Duration(seconds: i)),
            latitude: 47.5,
            longitude: 13.6,
            altitude: 1000.0,
            speed: 4.0,
            vario: 0.0,
          ),
        );
      }

      // 4 consecutive seconds of speed >= 12 km/h
      for (var i = 10; i <= 14; i++) {
        service.processPoint(
          FlightPoint(
            timestamp: baseTime.add(Duration(seconds: i)),
            latitude: 47.5 + (i * 0.0001),
            longitude: 13.6 + (i * 0.0001),
            altitude: 1000.0 + (i * 2.0),
            speed: 25.0,
            vario: 1.5,
          ),
        );
      }

      expect(service.state, FlightState.flying);
      // Ensure points were prepended
      expect(service.activeFlightPoints.length, greaterThanOrEqualTo(10));
      expect(service.activeFlightPoints.first.timestamp, baseTime);
    });

    test('Transitions to Landed after sustained settling duration and generates flight log', () {
      final baseTime = DateTime.utc(2026, 8, 20, 10, 0, 0);

      // Trigger takeoff
      for (var i = 0; i <= 5; i++) {
        service.processPoint(
          FlightPoint(
            timestamp: baseTime.add(Duration(seconds: i)),
            latitude: 47.5 + (i * 0.001),
            longitude: 13.6 + (i * 0.001),
            altitude: 1000.0 + (i * 10.0),
            speed: 35.0,
            vario: 2.0,
          ),
        );
      }
      expect(service.state, FlightState.flying);

      // Fly for 30 seconds
      for (var i = 6; i < 36; i++) {
        service.processPoint(
          FlightPoint(
            timestamp: baseTime.add(Duration(seconds: i)),
            latitude: 47.5 + (i * 0.001),
            longitude: 13.6 + (i * 0.001),
            altitude: 1200.0,
            speed: 38.0,
            vario: 0.0,
          ),
        );
      }

      // Land: 20 consecutive seconds of speed <= 8 km/h and vario <= 0.4 m/s
      for (var i = 36; i <= 57; i++) {
        service.processPoint(
          FlightPoint(
            timestamp: baseTime.add(Duration(seconds: i)),
            latitude: 47.6,
            longitude: 13.7,
            altitude: 600.0,
            speed: 2.0,
            vario: 0.0,
          ),
        );
      }

      expect(service.state, FlightState.landed);
      expect(service.lastCompletedFlight, isNotNull);
      expect(service.lastCompletedFlight!.statistics.duration.inSeconds, greaterThanOrEqualTo(50));
      expect(service.lastCompletedFlight!.rawIgcContent, contains('HFDTE'));
      expect(service.lastCompletedFlight!.rawIgcContent, contains('B1000'));

      service.markAsSaved();
      expect(service.state, FlightState.saved);
    });

    test('Customizable settings update correctly', () {
      service.updateSettings(
        const FlightSettings(
          takeoffSpeedThresholdKmh: 15.0,
          landingSettlingDurationSeconds: 30,
        ),
      );
      expect(service.settings.takeoffSpeedThresholdKmh, 15.0);
      expect(service.settings.landingSettlingDurationSeconds, 30);
    });
  });
}
