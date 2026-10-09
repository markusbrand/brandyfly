import 'package:brandyfly/services/telemetry/synthetic_telemetry_source.dart';
import 'package:brandyfly/services/telemetry/telemetry_types.dart';
import 'package:brandyfly/widgets/flight/synthetic_flight_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('wind and manoeuvre controls drive the synthetic source', (
    tester,
  ) async {
    final src = SyntheticTelemetrySource();
    addTearDown(src.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SyntheticFlightControls(source: src)),
      ),
    );

    expect(src.windSpeedKmh, 0);
    expect(find.byKey(const Key('sim_wind_speed')), findsNothing);
    await tester.tap(find.byKey(const Key('sim_controls_toggle')));
    await tester.pump();
    await tester.drag(
      find.byKey(const Key('sim_wind_speed')),
      const Offset(200, 0),
    );
    await tester.pump();
    expect(src.windSpeedKmh, greaterThan(0));

    final before = src.windFromDeg;
    await tester.drag(
      find.byKey(const Key('sim_wind_dir')),
      const Offset(120, 0),
    );
    await tester.pump();
    expect(src.windFromDeg, isNot(before));
    expect(find.textContaining('Sim wind:'), findsOneWidget);

    await tester.tap(find.byKey(const Key('sim_maneuver_thermalClimb360')));
    await tester.pump();
    expect(src.activeManeuver, FlightManeuver.thermalClimb360);
  });
}
