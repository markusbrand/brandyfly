import 'package:flutter_test/flutter_test.dart';
import 'package:brandyfly/models/ui_config.dart';
import 'package:brandyfly/services/screen_manager_service.dart';

void main() {
  group('ScreenManagerService Tests', () {
    test('initializes with default config and state', () {
      final manager = ScreenManagerService();
      expect(manager.config.navBarStyle, NavBarStyle.translucentDrawer);
      expect(
        manager.activeScreen.layoutStrategy,
        LayoutStrategyStyle.sidebarDashboard,
      );
      expect(manager.isEditMode, false);
      expect(manager.isNavBarVisible, false);
      expect(manager.activeScreen.id, 'normal_flight');
    });

    test('toggles navigation bar and edit mode state', () {
      final manager = ScreenManagerService();
      manager.toggleNavBar(true);
      expect(manager.isNavBarVisible, true);

      manager.toggleEditMode(true);
      expect(manager.isEditMode, true);
      expect(
        manager.isNavBarVisible,
        false,
      ); // Nav bar hides when edit mode opens
    });

    test('updates shell preferences and screen properties', () {
      final manager = ScreenManagerService();

      manager.setNavBarStyle(NavBarStyle.floatingPill);
      expect(manager.config.navBarStyle, NavBarStyle.floatingPill);

      manager.setSettingsStyle(SettingsStyle.cardDashboard);
      expect(manager.config.settingsStyle, SettingsStyle.cardDashboard);

      manager.setThermalingStyle(ThermalingStyle.focusMode);
      expect(manager.config.thermalingStyle, ThermalingStyle.focusMode);

      manager.setScreenLayoutStrategy('normal_flight', LayoutStrategyStyle.freeformHud);
      expect(
        manager.activeScreen.layoutStrategy,
        LayoutStrategyStyle.freeformHud,
      );

      manager.setScreenAutoSwitchTrigger('normal_flight', ScreenAutoSwitchTrigger.onGlideStraight);
      expect(
        manager.activeScreen.autoSwitchTrigger,
        ScreenAutoSwitchTrigger.onGlideStraight,
      );
    });

    test('updates individual widget styling without affecting global config', () {
      final manager = ScreenManagerService();
      final widgetId = manager.activeScreen.widgets.first.id;
      final original = manager.activeScreen.widgets.first;

      final updated = original.copyWith(
        numericStyle: NumericWidgetStyle.retroDigital,
      );
      manager.updateWidgetPlacement(updated);

      final current = manager.activeScreen.widgets.firstWhere((w) => w.id == widgetId);
      expect(current.numericStyle, NumericWidgetStyle.retroDigital);
      expect(current.effectiveNumericStyle, NumericWidgetStyle.retroDigital);
    });

    test('adds map widget with full-screen initial dimensions', () {
      final manager = ScreenManagerService();
      manager.addWidget(WidgetType.map);

      final added = manager.activeScreen.widgets.first;
      expect(added.type, WidgetType.map);
      expect(added.x, 0);
      expect(added.y, 0);
      expect(added.w, 8);
      expect(added.h, 8);
      expect(added.effectiveMapStyle, MapWidgetStyle.topoContours);
    });

    test('adds, switches, and removes flight screens', () {
      final manager = ScreenManagerService();
      final initialCount = manager.config.screens.length;

      manager.addScreen(
        'Cross Country',
        layoutStrategy: LayoutStrategyStyle.snapToGrid,
        autoSwitchTrigger: ScreenAutoSwitchTrigger.onGlideStraight,
      );
      expect(manager.config.screens.length, initialCount + 1);
      expect(manager.activeScreen.name, 'Cross Country');
      expect(manager.activeScreen.layoutStrategy, LayoutStrategyStyle.snapToGrid);
      expect(manager.activeScreen.autoSwitchTrigger, ScreenAutoSwitchTrigger.onGlideStraight);

      manager.setActiveScreen('normal_flight');
      expect(manager.activeScreen.name, 'Normal Flight Screen');

      manager.removeScreen('thermaling');
      expect(manager.config.screens.any((s) => s.id == 'thermaling'), false);
    });

    test('removing an inactive screen preserves active screen and widget selection', () {
      final manager = ScreenManagerService();
      manager.addScreen('Cross Country');
      expect(manager.activeScreen.name, 'Cross Country');
      final activeId = manager.activeScreen.id;

      // Select a widget if one exists or add and select one
      manager.addWidget(WidgetType.altitude);
      final widgetId = manager.activeScreen.widgets.first.id;
      manager.toggleEditMode(true);
      manager.selectWidget(widgetId);
      expect(manager.selectedWidgetId, widgetId);

      // Remove inactive screen 'thermaling'
      manager.removeScreen('thermaling');
      expect(manager.config.screens.any((s) => s.id == 'thermaling'), false);
      expect(manager.activeScreen.id, activeId);
      expect(manager.selectedWidgetId, widgetId);

      // Removing non-existent screen is a safe no-op
      manager.removeScreen('invalid_non_existent_id');
      expect(manager.activeScreen.id, activeId);
      expect(manager.selectedWidgetId, widgetId);
    });

    test('adds and removes flight widgets', () {
      final manager = ScreenManagerService();
      final initialWidgetCount = manager.activeScreen.widgets.length;

      manager.addWidget(WidgetType.hag);
      expect(manager.activeScreen.widgets.length, initialWidgetCount + 1);

      final addedId = manager.activeScreen.widgets.last.id;
      manager.removeWidget(addedId);
      expect(manager.activeScreen.widgets.length, initialWidgetCount);
    });

    test('repositions and resizes widgets with bounds clamping', () {
      final manager = ScreenManagerService();
      final widgetId = manager.activeScreen.widgets.firstWhere((w) => w.type == WidgetType.altitude).id;

      // Update position
      manager.updateWidgetPosition(widgetId, 2, 4);
      var w = manager.activeScreen.widgets.firstWhere((item) => item.id == widgetId);
      expect(w.x, 2);
      expect(w.y, 4);

      // Move widget
      manager.moveWidget(widgetId, 1, -1);
      w = manager.activeScreen.widgets.firstWhere((item) => item.id == widgetId);
      expect(w.x, 3);
      expect(w.y, 3);

      // Resize widget
      manager.updateWidgetSize(widgetId, 4, 3);
      w = manager.activeScreen.widgets.firstWhere((item) => item.id == widgetId);
      expect(w.w, 4);
      expect(w.h, 3);

      manager.resizeWidget(widgetId, -1, 1);
      w = manager.activeScreen.widgets.firstWhere((item) => item.id == widgetId);
      expect(w.w, 3);
      expect(w.h, 4);

      // Clamping checks: width cannot exceed grid columns (8), x clamped so x+w <= 8
      manager.updateWidgetPlacement(w.copyWith(x: 7, w: 4, y: -5, h: 20));
      w = manager.activeScreen.widgets.firstWhere((item) => item.id == widgetId);
      expect(w.w, 4);
      expect(w.x, 4); // clamped to 8 - 4 = 4
      expect(w.y, 0); // clamped to min 0
      expect(w.h, 16); // clamped to max 16
    });

    test('serializes and deserializes UIConfig correctly', () {
      final config = UIConfig.defaultConfig().copyWith(
        navBarStyle: NavBarStyle.cornerMenu,
        settingsStyle: SettingsStyle.cardDashboard,
      );

      final encoded = config.encodeJson();
      final decoded = UIConfig.decodeJson(encoded);

      expect(decoded.navBarStyle, NavBarStyle.cornerMenu);
      expect(decoded.settingsStyle, SettingsStyle.cardDashboard);
      expect(decoded.screens.length, config.screens.length);
    });

    test('tracks selectedWidgetId and clears upon exiting edit mode or switching screen', () {
      final manager = ScreenManagerService();
      final widgetId = manager.activeScreen.widgets.first.id;

      expect(manager.selectedWidgetId, isNull);

      manager.toggleEditMode(true);
      expect(manager.isEditMode, isTrue);

      manager.selectWidget(widgetId);
      expect(manager.selectedWidgetId, widgetId);

      // Exiting edit mode clears selection
      manager.toggleEditMode(false);
      expect(manager.isEditMode, isFalse);
      expect(manager.selectedWidgetId, isNull);

      // Re-entering and switching screen clears selection
      manager.toggleEditMode(true);
      manager.selectWidget(widgetId);
      expect(manager.selectedWidgetId, widgetId);

      manager.addScreen('New Screen');
      expect(manager.selectedWidgetId, isNull);
    });

    test('clears selectedWidgetId when selected widget is removed', () {
      final manager = ScreenManagerService();
      final widgetId = manager.activeScreen.widgets.first.id;

      manager.toggleEditMode(true);
      manager.selectWidget(widgetId);
      expect(manager.selectedWidgetId, widgetId);

      manager.removeWidget(widgetId);
      expect(manager.selectedWidgetId, isNull);
    });

    test('reorders widgets within stack hierarchy with boundary guards', () {
      final manager = ScreenManagerService();
      // Initially normal_flight has: w_map (0), w1 (1), w2 (2), w3 (3), w4 (4)
      final initialIds = manager.activeScreen.widgets.map((w) => w.id).toList();
      expect(initialIds.length, greaterThanOrEqualTo(3));

      final firstId = initialIds[0];
      final secondId = initialIds[1];
      final lastId = initialIds.last;

      // Cannot send first item backward or to back
      manager.sendBackward(firstId);
      expect(manager.activeScreen.widgets[0].id, firstId);
      manager.sendToBack(firstId);
      expect(manager.activeScreen.widgets[0].id, firstId);

      // Cannot bring last item forward or to front
      manager.bringForward(lastId);
      expect(manager.activeScreen.widgets.last.id, lastId);
      manager.bringToFront(lastId);
      expect(manager.activeScreen.widgets.last.id, lastId);

      // Bring second item forward: swaps index 1 with index 2
      manager.bringForward(secondId);
      expect(manager.activeScreen.widgets[2].id, secondId);

      // Bring second item to front: moves to the very end
      manager.bringToFront(secondId);
      expect(manager.activeScreen.widgets.last.id, secondId);

      // Send that item backward: moves from end to end-1
      manager.sendBackward(secondId);
      expect(manager.activeScreen.widgets[manager.activeScreen.widgets.length - 2].id, secondId);

      // Send to back: moves to index 0
      manager.sendToBack(secondId);
      expect(manager.activeScreen.widgets.first.id, secondId);
    });

    test('places new map widgets at background index 0 and instruments at foreground', () {
      final manager = ScreenManagerService();
      manager.addScreen('Test Placement Screen');
      expect(manager.activeScreen.widgets, isEmpty);

      // Add instrument widget -> goes to foreground (index 0 when empty)
      manager.addWidget(WidgetType.altitude);
      expect(manager.activeScreen.widgets.length, 1);
      final altId = manager.activeScreen.widgets.first.id;
      expect(manager.activeScreen.widgets[0].type, WidgetType.altitude);

      // Add another instrument widget -> appended to foreground (index 1)
      manager.addWidget(WidgetType.speed);
      expect(manager.activeScreen.widgets.length, 2);
      expect(manager.activeScreen.widgets[0].id, altId);
      expect(manager.activeScreen.widgets[1].type, WidgetType.speed);

      // Add map widget -> placed at background (index 0)
      manager.addWidget(WidgetType.map);
      expect(manager.activeScreen.widgets.length, 3);
      expect(manager.activeScreen.widgets[0].type, WidgetType.map);
      expect(manager.activeScreen.widgets[1].id, altId);
      expect(manager.activeScreen.widgets[2].type, WidgetType.speed);

      // Add thermal map widget -> placed at background (index 0)
      manager.addWidget(WidgetType.thermalMap);
      expect(manager.activeScreen.widgets.length, 4);
      expect(manager.activeScreen.widgets[0].type, WidgetType.thermalMap);
      expect(manager.activeScreen.widgets[1].type, WidgetType.map);
    });
  });
}
