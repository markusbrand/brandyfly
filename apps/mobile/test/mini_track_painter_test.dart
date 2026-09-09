import 'package:brandyfly/models/flight_model.dart';
import 'package:brandyfly/widgets/flight/mini_track_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MiniTrackPainter Test', () {
    testWidgets('renders CustomPaint with MiniTrackPainter without errors', (
      WidgetTester tester,
    ) async {
      final points = [
        FlightPoint(
          timestamp: DateTime.now(),
          latitude: 46.5,
          longitude: 8.5,
          altitudeMeters: 1000,
          speedKmh: 30,
          climbRateMs: 1.5,
        ),
        FlightPoint(
          timestamp: DateTime.now().add(const Duration(seconds: 10)),
          latitude: 46.6,
          longitude: 8.6,
          altitudeMeters: 1200,
          speedKmh: 35,
          climbRateMs: 2.0,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 100,
              child: CustomPaint(painter: MiniTrackPainter(points)),
            ),
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsWidgets);
    });

    test('shouldRepaint returns correct result', () {
      final points1 = [
        FlightPoint(
          timestamp: DateTime.now(),
          latitude: 46.5,
          longitude: 8.5,
          altitudeMeters: 1000,
          speedKmh: 30,
          climbRateMs: 1.5,
        ),
      ];

      final points2 = [
        FlightPoint(
          timestamp: DateTime.now(),
          latitude: 46.5,
          longitude: 8.5,
          altitudeMeters: 1000,
          speedKmh: 30,
          climbRateMs: 1.5,
        ),
      ];

      final painter1 = MiniTrackPainter(points1);
      final painter2 = MiniTrackPainter(points1);
      final painter3 = MiniTrackPainter(points2);

      expect(painter1.shouldRepaint(painter2), isFalse);
      expect(painter1.shouldRepaint(painter3), isTrue);
    });
  });
}
