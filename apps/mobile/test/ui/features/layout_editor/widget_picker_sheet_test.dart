import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brandyfly/domain/models/widget_type.dart';
import 'package:brandyfly/domain/models/ui_config.dart';
import 'package:brandyfly/domain/models/widget_catalog.dart';
import 'package:brandyfly/services/screen_manager_service.dart';
import 'package:brandyfly/ui/features/layout_editor/views/widget_picker_sheet.dart';
import 'package:brandyfly/ui/features/layout_editor/views/inspector_panel.dart';

void main() {
  group('WidgetPickerSheet flightTime and returnGlide entries', () {
    testWidgets('shows Flight Time widget and adds it with default catalog dimensions', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final manager = ScreenManagerService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WidgetPickerSheet(screenManager: manager),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final itemFinder = find.widgetWithText(ListTile, 'Flight Time');
      await tester.scrollUntilVisible(itemFinder, 100);
      expect(itemFinder, findsOneWidget);
      expect(
        find.text('Displays airborne duration, clock & takeoff time'),
        findsOneWidget,
      );

      final addButton = find.descendant(
        of: itemFinder,
        matching: find.widgetWithText(ElevatedButton, 'Add'),
      );
      await tester.tap(addButton);
      await tester.pumpAndSettle();

      final added = manager.activeScreen.widgets.last;
      expect(added.type, WidgetType.flightTime);
      expect(added.w, 4);
      expect(added.h, 4);
    });

    testWidgets('shows Return Glide (RTL) widget and adds it with default catalog dimensions', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final manager = ScreenManagerService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WidgetPickerSheet(screenManager: manager),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final itemFinder = find.widgetWithText(ListTile, 'Return Glide (RTL)');
      await tester.scrollUntilVisible(itemFinder, 100);
      expect(itemFinder, findsOneWidget);
      expect(
        find.text('Required glide ratio, launch distance & altitude margin'),
        findsOneWidget,
      );

      final addButton = find.descendant(
        of: itemFinder,
        matching: find.widgetWithText(ElevatedButton, 'Add'),
      );
      await tester.tap(addButton);
      await tester.pumpAndSettle();

      final added = manager.activeScreen.widgets.last;
      expect(added.type, WidgetType.returnGlide);
      expect(added.w, 6);
      expect(added.h, 4);
    });

    testWidgets('WidgetInspectorPanel exposes size presets for flightTime and returnGlide', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final manager = ScreenManagerService();
      final ftModel = WidgetPlacementModel(
        id: 'ft_1',
        type: WidgetType.flightTime,
        x: 0,
        y: 0,
        w: 4,
        h: 4,
      );

      manager.toggleEditMode(true);
      manager.editMode.select(ftModel.id);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WidgetInspectorPanel(
              model: ftModel,
              screenManager: manager,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('btn_inspector_preset_s')), findsOneWidget);
      expect(find.byKey(const Key('btn_inspector_preset_m')), findsOneWidget);
      expect(find.byKey(const Key('btn_inspector_preset_l')), findsOneWidget);
      expect(find.byKey(const Key('btn_inspector_preset_full')), findsOneWidget);
    });
  });
}
