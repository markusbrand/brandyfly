import 'package:brandyfly/models/ui_config.dart';
import 'package:brandyfly/services/screen_manager_service.dart';
import 'package:brandyfly/services/telemetry/synthetic_telemetry_source.dart';
import 'package:brandyfly/services/telemetry/telemetry_types.dart';
import 'package:brandyfly/widgets/layout/layout_strategy_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Synthetic Telemetry UI Widget Tests', () {
    testWidgets('Dashboard UI renders and updates against synthetic steady glide stream', (tester) async {
      final config = UIConfig(
        navBarStyle: NavBarStyle.translucentDrawer,
        activeScreenId: 'screen_test',
        screens: [
          FlightScreenModel(
            id: 'screen_test',
            name: 'Test Screen',
            layoutStrategy: LayoutStrategyStyle.freeformHud,
            widgets: [
              WidgetPlacementModel(
                id: 'w_vario',
                type: WidgetType.varioBar,
                x: 0,
                y: 0,
                w: 1,
                h: 4,
              ),
              WidgetPlacementModel(
                id: 'w_alt',
                type: WidgetType.altitude,
                x: 1,
                y: 0,
                w: 2,
                h: 2,
              ),
              WidgetPlacementModel(
                id: 'w_spd',
                type: WidgetType.speed,
                x: 1,
                y: 2,
                w: 2,
                h: 2,
              ),
            ],
          ),
        ],
      );

      final screenManager = ScreenManagerService(initialConfig: config);

      final source = SyntheticTelemetrySource(
        seed: 42,
        initialManeuver: FlightManeuver.steadyGlide,
      );
      await source.initialize();

      final latestSnapshot = source.stepSynchronously(1.0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LayoutStrategyContainer(
              screenManager: screenManager,
              telemetryData: latestSnapshot.toTelemetryMap(),
            ),
          ),
        ),
      );

      expect(find.byType(LayoutStrategyContainer), findsOneWidget);
      expect(find.textContaining('ALTITUDE'), findsWidgets);
      expect(find.textContaining('SPEED'), findsWidgets);

      source.dispose();
      screenManager.dispose();
    });

    testWidgets('360-degree thermaling turn updates climb bar and wind display', (tester) async {
      final config = UIConfig(
        navBarStyle: NavBarStyle.translucentDrawer,
        activeScreenId: 'screen_thermal',
        screens: [
          FlightScreenModel(
            id: 'screen_thermal',
            name: 'Thermal Screen',
            layoutStrategy: LayoutStrategyStyle.sidebarDashboard,
            widgets: [
              WidgetPlacementModel(
                id: 'w_vario',
                type: WidgetType.varioBar,
                x: 0,
                y: 0,
                w: 1,
                h: 4,
              ),
              WidgetPlacementModel(
                id: 'w_wind',
                type: WidgetType.windDirection,
                x: 1,
                y: 0,
                w: 2,
                h: 2,
              ),
            ],
          ),
        ],
      );

      final screenManager = ScreenManagerService(initialConfig: config);

      final source = SyntheticTelemetrySource(
        seed: 7,
        initialManeuver: FlightManeuver.thermalClimb360,
      );
      await source.initialize();

      late TelemetrySnapshot snapshot;
      // Advance 5 seconds into thermal climb (+2.5 m/s)
      for (var i = 0; i < 5; i++) {
        snapshot = source.stepSynchronously(1.0);
      }

      expect(snapshot.vario, greaterThan(2.0));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LayoutStrategyContainer(
              screenManager: screenManager,
              telemetryData: snapshot.toTelemetryMap(),
            ),
          ),
        ),
      );

      expect(find.byType(LayoutStrategyContainer), findsOneWidget);
      expect(find.textContaining('WIND'), findsWidgets);

      source.dispose();
      screenManager.dispose();
    });
  });
}
