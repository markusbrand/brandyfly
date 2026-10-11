import 'package:brandyfly/domain/models/size_tier.dart';
import 'package:brandyfly/domain/models/ui_config.dart';
import 'package:brandyfly/ui/features/instruments/views/vario_lift_sink_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrapWidget(Widget child, {double width = 80, double height = 240}) {
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

  group('VarioLiftSinkBar Dual-Indicator', () {
    testWidgets('renders averager needle and reference notches in verticalEdgeBar', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWidget(
          const VarioLiftSinkBar(
            climbRateMs: 3.2,
            averageClimbMs: 1.8,
            showAverager: true,
            style: LiftSinkBarStyle.verticalEdgeBar,
            tier: SizeTier.regular,
          ),
        ),
      );

      // Verify instantaneous climb text
      expect(find.text('+3.2'), findsOneWidget);

      // Verify averager readout in regular tier
      expect(find.byKey(const Key('vario_edge_bar_averager_text')), findsOneWidget);
      expect(find.text('ø+1.8'), findsOneWidget);

      // Verify averager needle marker is present
      expect(find.byKey(const Key('vario_averager_needle')), findsOneWidget);

      // Verify reference threshold notches are present
      expect(find.byKey(const Key('vario_notch_lift_threshold')), findsOneWidget);
      expect(find.byKey(const Key('vario_notch_sink_warning')), findsOneWidget);
    });

    testWidgets('hides averager needle when showAverager is false', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWidget(
          const VarioLiftSinkBar(
            climbRateMs: 2.0,
            averageClimbMs: 1.5,
            showAverager: false,
            style: LiftSinkBarStyle.verticalEdgeBar,
          ),
        ),
      );

      expect(find.byKey(const Key('vario_averager_needle')), findsNothing);
      expect(find.byKey(const Key('vario_edge_bar_averager_text')), findsNothing);
    });

    testWidgets('compact tier hides secondary digital text but preserves needle and notches', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWidget(
          const VarioLiftSinkBar(
            climbRateMs: 1.5,
            averageClimbMs: 0.8,
            showAverager: true,
            style: LiftSinkBarStyle.verticalEdgeBar,
            tier: SizeTier.compact,
          ),
          width: 50,
          height: 100,
        ),
      );

      expect(find.text('+1.5'), findsOneWidget);
      expect(find.byKey(const Key('vario_edge_bar_averager_text')), findsNothing);
      expect(find.byKey(const Key('vario_averager_needle')), findsOneWidget);
    });

    testWidgets('analogDial displays digital averager readout', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWidget(
          const VarioLiftSinkBar(
            climbRateMs: 2.2,
            averageClimbMs: 1.4,
            showAverager: true,
            style: LiftSinkBarStyle.analogDial,
            tier: SizeTier.regular,
          ),
          width: 150,
          height: 150,
        ),
      );

      expect(find.text('2.20 m/s'), findsOneWidget);
      expect(find.byKey(const Key('vario_dial_averager_text')), findsOneWidget);
      expect(find.text('ø +1.4 m/s'), findsOneWidget);
    });
  });
}
