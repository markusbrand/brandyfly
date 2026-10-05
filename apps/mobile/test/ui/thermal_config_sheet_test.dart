import 'package:brandyfly/models/ui_config.dart';
import 'package:brandyfly/services/screen_manager_service.dart';
import 'package:brandyfly/widgets/layout/layout_strategy_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Map config sheet edits thermal season, time of day and opacity',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final manager = ScreenManagerService();
      manager.addScreen('Thermal Config Screen');
      manager.addWidget(WidgetType.map);
      manager.toggleEditMode(true);
      final id = manager.activeScreen.widgets
          .firstWhere((w) => w.type == WidgetType.map)
          .id;
      manager.selectWidget(id);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LayoutStrategyContainer(
              screenManager: manager,
              telemetryData: const {'altitude': 1500.0},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(Key('btn_config_$id')));
      await tester.pumpAndSettle();

      // Options are visible while the heatmap toggle is on (default).
      expect(find.byKey(const Key('thermal_heatmap_options')), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('thermal_season_jul')));
      await tester.tap(find.byKey(const Key('thermal_season_jul')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('thermal_time_morning')));
      await tester.pumpAndSettle();

      // Drag the opacity slider to its minimum (10 %) and back up a bit.
      final slider = find.byKey(const Key('thermal_opacity_slider'));
      await tester.ensureVisible(slider);
      await tester.drag(slider, const Offset(-1000, 0));
      await tester.pumpAndSettle();
      expect(find.text('Heatmap opacity: 10 %'), findsOneWidget);
      final sliderRect = tester.getRect(slider);
      // Tap ~at 30 % of the 10..100 % track.
      await tester.tapAt(
        Offset(
          sliderRect.left + 24 + (sliderRect.width - 48) * (2 / 9),
          sliderRect.center.dy,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Heatmap opacity: 30 %'), findsOneWidget);

      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      final updated = manager.activeScreen.widgets.firstWhere(
        (w) => w.id == id,
      );
      expect(updated.effectiveMapThermalSeason, ThermalSeason.jul);
      expect(updated.effectiveMapThermalTimeOfDay, ThermalTimeOfDay.morning);
      expect(updated.effectiveMapThermalOpacity, closeTo(0.3, 1e-9));
    },
  );

  testWidgets('thermal options are hidden when the heatmap is switched off', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final manager = ScreenManagerService();
    manager.addScreen('Thermal Toggle Screen');
    manager.addWidget(WidgetType.map);
    manager.toggleEditMode(true);
    final id = manager.activeScreen.widgets
        .firstWhere((w) => w.type == WidgetType.map)
        .id;
    manager.selectWidget(id);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LayoutStrategyContainer(
            screenManager: manager,
            telemetryData: const {'altitude': 1500.0},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('btn_config_$id')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Thermal Updraft Hotspots'));
    await tester.tap(find.text('Thermal Updraft Hotspots'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('thermal_heatmap_options')), findsNothing);

    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    final updated = manager.activeScreen.widgets.firstWhere((w) => w.id == id);
    expect(updated.effectiveMapShowThermals, isFalse);
  });
}
