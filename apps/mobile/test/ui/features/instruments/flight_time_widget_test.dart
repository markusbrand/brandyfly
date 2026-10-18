import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brandyfly/domain/models/size_tier.dart';
import 'package:brandyfly/ui/features/instruments/views/flight_time_widget.dart';

void main() {
  group('FlightTimeWidget unit and widget tests', () {
    test('formatDuration formats mm:ss and hh:mm:ss correctly', () {
      expect(FlightTimeWidget.formatDuration(null), '00:00');
      expect(FlightTimeWidget.formatDuration(Duration.zero), '00:00');
      expect(
        FlightTimeWidget.formatDuration(const Duration(seconds: 45)),
        '00:45',
      );
      expect(
        FlightTimeWidget.formatDuration(const Duration(minutes: 12, seconds: 34)),
        '12:34',
      );
      expect(
        FlightTimeWidget.formatDuration(
          const Duration(hours: 1, minutes: 23, seconds: 45),
        ),
        '1:23:45',
      );
      expect(
        FlightTimeWidget.formatDuration(
          const Duration(hours: 4, minutes: 5, seconds: 9),
        ),
        '4:05:09',
      );
    });

    testWidgets('renders standby mode when pre-takeoff', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: 120,
                child: FlightTimeWidget(
                  tier: SizeTier.regular,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('00:00'), findsOneWidget);
      expect(find.text('STANDBY'), findsOneWidget);
      expect(find.text('TAKEOFF --:--'), findsOneWidget);
    });

    testWidgets('renders regular tier with flight duration and takeoff time', (
      tester,
    ) async {
      final takeoff = DateTime(2026, 6, 15, 14, 30);
      final clock = DateTime(2026, 6, 15, 15, 15, 42);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 250,
                height: 150,
                child: FlightTimeWidget(
                  flightDuration: const Duration(minutes: 45, seconds: 42),
                  takeoffTime: takeoff,
                  localTime: clock,
                  tier: SizeTier.regular,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('45:42'), findsOneWidget);
      expect(find.text('AIRBORNE'), findsOneWidget);
      expect(find.text('TIME 15:15:42'), findsOneWidget);
      expect(find.text('TAKEOFF 14:30'), findsOneWidget);
    });

    testWidgets('renders compact tier correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 140,
                height: 60,
                child: FlightTimeWidget(
                  flightDuration: Duration(hours: 1, minutes: 10, seconds: 5),
                  takeoffTime: null,
                  tier: SizeTier.compact,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1:10:05'), findsOneWidget);
      expect(find.text('FLIGHT TIME'), findsOneWidget);
    });

    testWidgets('renders tiny tier without labels or secondary clocks', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 60,
                height: 30,
                child: FlightTimeWidget(
                  flightDuration: Duration(minutes: 32, seconds: 10),
                  tier: SizeTier.tiny,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('32:10'), findsOneWidget);
      expect(find.text('FLIGHT TIME'), findsNothing);
      expect(find.text('STANDBY'), findsNothing);
    });

    testWidgets('renders stale state indicator when isStale is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 250,
                height: 150,
                child: FlightTimeWidget(
                  flightDuration: const Duration(minutes: 20, seconds: 0),
                  takeoffTime: DateTime(2026, 6, 15, 14, 0),
                  isStale: true,
                  tier: SizeTier.regular,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('STALE'), findsOneWidget);
    });
  });
}
