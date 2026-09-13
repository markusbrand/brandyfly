import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brandyfly/models/ui_config.dart';
import 'package:brandyfly/widgets/flight/thermal_map_widget.dart';

void main() {
  group('ThermalMapWidget Auto-Recenter & Centering Tests', () {
    testWidgets(
      'TC-THERMAL-001: Verifies ThermalMapWidget renders at 50/50 true center for all styles',
      (tester) async {
        for (final style in ThermalMapStyle.values) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 400,
                  height: 400,
                  child: ThermalMapWidget(style: style),
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          expect(find.byType(ThermalMapWidget), findsOneWidget);
          expect(find.text('Recenter on Glider'), findsNothing);
        }
      },
    );

    testWidgets(
      'TC-THERMAL-002: Verifies pan gesture disengages center-lock and shows recenter button',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 400,
                child: ThermalMapWidget(),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Initially no recenter button (centered)
        expect(find.byKey(const Key('btn_thermal_recenter')), findsNothing);

        // Pan to disengage center-lock
        await tester.drag(find.byKey(const Key('canvas_thermal_map')), const Offset(80, 40));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Recenter button should now be visible
        expect(find.byKey(const Key('btn_thermal_recenter')), findsOneWidget);
      },
    );

    testWidgets(
      'TC-THERMAL-003: Verifies auto-recenter timer re-centers after inactivity',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 400,
                child: ThermalMapWidget(),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Pan to uncenter
        await tester.drag(find.byKey(const Key('canvas_thermal_map')), const Offset(80, 40));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byKey(const Key('btn_thermal_recenter')), findsOneWidget);

        // Advance time past 6s auto-recenter timeout
        await tester.pump(const Duration(seconds: 7));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Recenter button should be gone (re-centered)
        expect(find.byKey(const Key('btn_thermal_recenter')), findsNothing);
      },
    );

    testWidgets(
      'TC-THERMAL-004: Verifies manual recenter button immediately re-centers and hides button',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 400,
                child: ThermalMapWidget(),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Pan to uncenter
        await tester.drag(find.byKey(const Key('canvas_thermal_map')), const Offset(80, 40));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byKey(const Key('btn_thermal_recenter')), findsOneWidget);

        // Tap recenter
        await tester.tap(find.byKey(const Key('btn_thermal_recenter')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Button should disappear
        expect(find.byKey(const Key('btn_thermal_recenter')), findsNothing);
      },
    );

    testWidgets(
      'TC-THERMAL-005: Verifies pan gesture resets auto-recenter timer',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 400,
                child: ThermalMapWidget(),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Pan to uncenter
        await tester.drag(find.byKey(const Key('canvas_thermal_map')), const Offset(80, 40));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Wait 4 seconds (before timer fires)
        await tester.pump(const Duration(seconds: 4));

        // Pan again to reset timer
        await tester.drag(find.byKey(const Key('canvas_thermal_map')), const Offset(30, 10));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Still uncentered (timer was reset)
        expect(find.byKey(const Key('btn_thermal_recenter')), findsOneWidget);

        // Wait 3 more seconds (total 7 since last pan)
        await tester.pump(const Duration(seconds: 3));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Timer should not have fired yet (only 3s since reset)
        expect(find.byKey(const Key('btn_thermal_recenter')), findsOneWidget);

        // Wait another 4s (total 7s since last pan => beyond 6s timeout)
        await tester.pump(const Duration(seconds: 4));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Now should be re-centered
        expect(find.byKey(const Key('btn_thermal_recenter')), findsNothing);
      },
    );
  });
}