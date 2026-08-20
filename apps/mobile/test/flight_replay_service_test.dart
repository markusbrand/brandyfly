import 'package:brandyfly/models/flight_model.dart';
import 'package:brandyfly/services/flight_replay_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FlightReplayService Tests', () {
    late FlightModel flight;
    late FlightReplayService replay;

    setUp(() {
      final base = DateTime.utc(2026, 8, 20, 10, 0, 0);
      final points = List.generate(
        100,
        (i) => FlightPoint(
          timestamp: base.add(Duration(seconds: i)),
          latitude: 47.5 + (i * 0.001),
          longitude: 13.6 + (i * 0.001),
          altitude: 1000.0 + (i * 5.0),
          speed: 35.0 + (i % 5),
          vario: 1.5,
          heading: (i * 3.0) % 360,
        ),
      );

      flight = FlightModel(
        id: 'test_flight',
        title: 'Test Replay Flight',
        date: base,
        points: points,
        statistics: const FlightStatistics(
          duration: Duration(seconds: 99),
          maxAltitude: 1495.0,
          minAltitude: 1000.0,
          maxClimbRate: 1.5,
          maxSinkRate: 0.0,
          totalDistanceKm: 12.0,
          averageSpeedKmh: 37.0,
          averageGlideRatio: 8.5,
        ),
      );

      replay = FlightReplayService(flight: flight);
    });

    test('Initializes correctly with flight points and zero index', () {
      expect(replay.totalPoints, 100);
      expect(replay.currentIndex, 0);
      expect(replay.isPlaying, isFalse);
      expect(replay.speedMultiplier, 1);
      expect(replay.progressRatio, 0.0);
    });

    test('Advances steps and seeks to ratio accurately', () {
      replay.advance(10);
      expect(replay.currentIndex, 10);
      expect(replay.progressRatio, closeTo(0.101, 0.01));

      replay.seekToRatio(0.5);
      expect(replay.currentIndex, 50);

      final telemetry = replay.currentTelemetry;
      expect(telemetry['altitude'], 1250.0);
      expect(telemetry['speed'], greaterThan(30.0));
      expect(telemetry['history'], isNotEmpty);
    });

    test('Speed multiplier cycles 1x -> 2x -> 3x -> 4x -> 5x -> 6x -> 7x -> 8x -> 1x', () {
      expect(replay.speedMultiplier, 1);
      for (var s = 2; s <= 8; s++) {
        replay.cycleSpeedMultiplier();
        expect(replay.speedMultiplier, s);
      }
      // Tap at 8x cycles back to 1x
      replay.cycleSpeedMultiplier();
      expect(replay.speedMultiplier, 1);
    });

    test('Play/pause controls toggle playback state', () {
      replay.play();
      expect(replay.isPlaying, isTrue);
      replay.pause();
      expect(replay.isPlaying, isFalse);
      replay.togglePlayPause();
      expect(replay.isPlaying, isTrue);
    });
  });
}
