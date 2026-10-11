import 'package:brandyfly/domain/models/size_tier.dart';
import 'package:brandyfly/domain/thermal_assistant/thermal_session_stats.dart';
import 'package:brandyfly/ui/features/instruments/views/thermal_stats_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrapWidget(Widget child, {double width = 160, double height = 120}) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            height: height,
            child: child,
          ),
        ),
      ),
    );
  }

  group('ThermalStatsWidget', () {
    testWidgets('renders live thermal session with gain, avg, turns, time, and peak', (
      tester,
    ) async {
      const stats = ThermalSessionStats(
        entryAltitudeM: 1000.0,
        currentAltitudeM: 1420.0,
        altitudeGainM: 420.0,
        averageClimbMs: 2.3,
        duration: Duration(minutes: 3, seconds: 5),
        turnCount: 11,
        peakClimbMs: 4.8,
        isLive: true,
      );

      await tester.pumpWidget(
        wrapWidget(
          const ThermalStatsWidget(
            stats: stats,
            tier: SizeTier.regular,
          ),
        ),
      );

      expect(find.text('LIVE THERMAL'), findsOneWidget);
      expect(find.text('11 turns'), findsOneWidget);
      expect(find.text('+420m'), findsOneWidget);
      expect(find.text('+2.3'), findsOneWidget);
      expect(find.text('3:05'), findsOneWidget);
      expect(find.text('+4.8'), findsOneWidget);
    });

    testWidgets('renders frozen last thermal session during glide', (
      tester,
    ) async {
      const stats = ThermalSessionStats(
        entryAltitudeM: 1000.0,
        currentAltitudeM: 1350.0,
        altitudeGainM: 350.0,
        averageClimbMs: 1.9,
        duration: Duration(minutes: 2, seconds: 40),
        turnCount: 8,
        peakClimbMs: 3.5,
        isLive: false,
      );

      await tester.pumpWidget(
        wrapWidget(
          const ThermalStatsWidget(
            stats: stats,
            tier: SizeTier.regular,
          ),
        ),
      );

      expect(find.text('LAST THERMAL'), findsOneWidget);
      expect(find.text('8 turns'), findsOneWidget);
      expect(find.text('+350m'), findsOneWidget);
      expect(find.text('+1.9'), findsOneWidget);
    });

    testWidgets('compact tier displays gain and avg climb', (tester) async {
      const stats = ThermalSessionStats(
        entryAltitudeM: 1200.0,
        currentAltitudeM: 1510.0,
        altitudeGainM: 310.0,
        averageClimbMs: 2.1,
        duration: Duration(minutes: 2, seconds: 15),
        turnCount: 7,
        peakClimbMs: 4.0,
        isLive: true,
      );

      await tester.pumpWidget(
        wrapWidget(
          const ThermalStatsWidget(
            stats: stats,
            tier: SizeTier.compact,
          ),
          width: 80,
          height: 60,
        ),
      );

      expect(find.text('+310m'), findsOneWidget);
      expect(find.text('ø+2.1'), findsOneWidget);
      expect(find.text('LIVE THERMAL'), findsOneWidget);
      expect(find.text('7 turns'), findsNothing); // Secondary details hidden
    });

    testWidgets('tiny tier displays gain value only', (tester) async {
      const stats = ThermalSessionStats(
        entryAltitudeM: 1000.0,
        currentAltitudeM: 1250.0,
        altitudeGainM: 250.0,
        averageClimbMs: 2.0,
        duration: Duration(minutes: 1, seconds: 30),
        turnCount: 5,
        peakClimbMs: 3.2,
        isLive: true,
      );

      await tester.pumpWidget(
        wrapWidget(
          const ThermalStatsWidget(
            stats: stats,
            tier: SizeTier.tiny,
          ),
          width: 38,
          height: 38,
        ),
      );

      expect(find.text('+250'), findsOneWidget);
      expect(find.text('LIVE THERMAL'), findsNothing);
      expect(find.text('ø+2.0'), findsNothing);
    });

    testWidgets('handles null or empty stats gracefully with idle state', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWidget(
          const ThermalStatsWidget(
            stats: null,
            tier: SizeTier.regular,
          ),
        ),
      );

      expect(find.text('IDLE'), findsOneWidget);
      expect(find.text('--'), findsNWidgets(3)); // GAIN, AVG, PEAK
      expect(find.text('--:--'), findsOneWidget); // TIME
    });
  });
}
