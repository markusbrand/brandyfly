import 'package:brandyfly/models/flight_model.dart';
import 'package:brandyfly/services/flight_tracking_service.dart';
import 'package:brandyfly/services/telemetry/synthetic_telemetry_source.dart';
import 'package:brandyfly/services/telemetry/telemetry_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Telemetry Provider Lifecycle and Switching Tests', () {
    test('SyntheticTelemetrySource initializes, starts, pauses, stops correctly', () async {
      final source = SyntheticTelemetrySource(
        seed: 42,
        frequencyHz: 10,
        initialManeuver: FlightManeuver.steadyGlide,
      );

      expect(source.sourceType, TelemetrySourceType.synthetic);
      expect(source.isRunning, isFalse);
      expect(source.isPaused, isFalse);

      await source.initialize();
      expect(source.currentAltitude, greaterThan(1400.0));

      final snapshots = <TelemetrySnapshot>[];
      final sub = source.telemetryStream.listen(snapshots.add);

      await source.start();
      expect(source.isRunning, isTrue);
      expect(source.isPaused, isFalse);

      // Trigger synchronous ticks
      source.stepSynchronously(1.0);
      await pumpEventQueue();
      expect(snapshots.length, 1);
      expect(snapshots.first.vario, closeTo(-1.2, 0.5));
      expect(snapshots.first.speed, closeTo(38.0, 5.0));

      await source.pause();
      expect(source.isRunning, isFalse);
      expect(source.isPaused, isTrue);

      await source.stop();
      expect(source.isRunning, isFalse);
      expect(source.isPaused, isFalse);

      await sub.cancel();
      source.dispose();
    });

    test('FlightTrackingService seamlessly attaches and switches telemetry sources', () async {
      final trackingService = FlightTrackingService();
      expect(trackingService.state, FlightState.groundPreflight);
      expect(trackingService.telemetrySource, isNull);

      final source1 = SyntheticTelemetrySource(
        seed: 1,
        frequencyHz: 10,
        initialManeuver: FlightManeuver.steadyGlide,
      );
      final source2 = SyntheticTelemetrySource(
        seed: 2,
        frequencyHz: 10,
        initialManeuver: FlightManeuver.thermalClimb360,
      );

      // 1. Attach source1
      trackingService.attachTelemetrySource(source1);
      expect(trackingService.telemetrySource, equals(source1));

      // Emit flight points that trigger takeoff (speed >= 15 km/h for sustained 3s)
      final now = DateTime.now();
      for (var i = 0; i < 5; i++) {
        trackingService.processPoint(FlightPoint(
          timestamp: now.add(Duration(seconds: i)),
          latitude: 47.52,
          longitude: 13.69,
          altitude: 1500.0 + i * 2.0,
          speed: 38.0,
          vario: 2.0,
          heading: 120.0,
        ));
      }

      expect(trackingService.state, FlightState.flying);
      expect(trackingService.activeFlightPoints.length, greaterThan(0));

      // 2. Switch to source2 while flying
      trackingService.attachTelemetrySource(source2);
      expect(trackingService.telemetrySource, equals(source2));
      // Flight state and collected points are preserved during source switch!
      expect(trackingService.state, FlightState.flying);

      // Process event from source2
      source2.stepSynchronously(1.0);
      expect(trackingService.state, FlightState.flying);

      // Detach source
      trackingService.detachTelemetrySource();
      expect(trackingService.telemetrySource, isNull);
      expect(trackingService.state, FlightState.flying);

      source1.dispose();
      source2.dispose();
      trackingService.dispose();
    });
  });
}
