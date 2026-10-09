import 'package:brandyfly/data/repositories/telemetry_repository.dart';
import 'package:brandyfly/domain/models/size_tier.dart';
import 'package:brandyfly/domain/models/ui_config.dart';
import 'package:brandyfly/services/flight_replay_service.dart';
import 'package:brandyfly/services/screen_auto_switch_controller.dart';
import 'package:brandyfly/services/screen_manager_service.dart';
import 'package:brandyfly/services/telemetry/synthetic_telemetry_source.dart';
import 'package:brandyfly/services/telemetry/telemetry_types.dart';
import 'package:brandyfly/ui/features/flight_canvas/views/widget_slot.dart';
import 'package:brandyfly/ui/features/instruments/views/thermal_map_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mock flight: 15 km/h wind, glide -> thermal -> glide, through the real
/// repository, thermal assistant, auto-switch controller and cockpit widgets.
void main() {
  testWidgets('mock flight couples thermal assistant end to end', (
    tester,
  ) async {
    final replay = FlightReplayService();
    final repo = TelemetryRepository(replayService: replay);
    final screens = ScreenManagerService();
    final src = SyntheticTelemetrySource(
      frequencyHz: 10,
      windFromDeg: 250,
      windSpeedKmh: 15,
    );
    late DateTime simNow;
    final autoSwitch = ScreenAutoSwitchController(
      screens: () => screens,
      telemetry: repo.telemetry,
      clock: () => simNow,
    )..start();
    addTearDown(() {
      autoSwitch.dispose();
      src.dispose();
      screens.dispose();
      repo.dispose();
      replay.dispose();
    });

    void fly(FlightManeuver m, int seconds) {
      src.setManeuver(m);
      for (var i = 0; i < seconds * 10; i++) {
        final s = src.stepSynchronously(0.1);
        simNow = s.timestamp;
        repo.onSnapshot(s);
      }
    }

    const thermalMap = WidgetPlacementModel(
      id: 'tm',
      type: WidgetType.thermalMap,
      x: 0,
      y: 0,
      w: 8,
      h: 8,
      thermalMapStyle: ThermalMapStyle.burnairCore,
    );
    const wind = WidgetPlacementModel(
      id: 'wd',
      type: WidgetType.windDirection,
      x: 0,
      y: 0,
      w: 4,
      h: 2,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              SizedBox(
                width: 400,
                height: 400,
                child: FlightWidgetContent(
                  model: thermalMap,
                  telemetry: repo.telemetry,
                  tier: SizeTier.regular,
                ),
              ),
              SizedBox(
                width: 200,
                height: 80,
                child: FlightWidgetContent(
                  model: wind,
                  telemetry: repo.telemetry,
                  tier: SizeTier.regular,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // 1. Glide: no circling, no wind, no live bubbles, no preview.
    fly(FlightManeuver.steadyGlide, 30);
    await tester.pump();
    expect(screens.activeScreen.id, 'normal_flight');
    expect(find.byKey(const Key('wind_no_estimate')), findsOneWidget);
    var map = tester.widget<ThermalMapWidget>(find.byType(ThermalMapWidget));
    expect(map.preview, isFalse);
    expect(map.trackPoints, isEmpty);

    // 2. Thermal: auto-switch, live track + core, wind after two turns.
    fly(FlightManeuver.thermalClimb360, 70);
    await tester.pump();
    expect(repo.telemetry.value.thermal.isCircling, isTrue);
    expect(screens.activeScreen.id, 'thermaling');
    map = tester.widget<ThermalMapWidget>(find.byType(ThermalMapWidget));
    expect(map.trackPoints, isNotEmpty);
    expect(map.coreOffset, isNotNull);
    expect(map.windDirDeg, closeTo(250, 10));
    expect(map.windSpeedKmh, closeTo(15, 4));
    expect(find.byKey(const Key('wind_no_estimate')), findsNothing);
    expect(find.textContaining('km/h'), findsWidgets);

    // 3. Glide again: back to the previous screen; wind retained.
    fly(FlightManeuver.steadyGlide, 15);
    await tester.pump();
    expect(repo.telemetry.value.thermal.isCircling, isFalse);
    expect(screens.activeScreen.id, 'normal_flight');
    map = tester.widget<ThermalMapWidget>(find.byType(ThermalMapWidget));
    expect(map.trackPoints, isEmpty);
    expect(map.windDirDeg, isNotNull);
  });
}
