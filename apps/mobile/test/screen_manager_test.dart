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

      final added = manager.activeScreen.widgets.last;
      expect(added.type, WidgetType.map);
      expect(added.x, 0);
      expect(added.y, 0);
      expect(added.w, 4);
      expect(added.h, 4);
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
      manager.updateWidgetPosition(widgetId, 1, 2);
      var w = manager.activeScreen.widgets.firstWhere((item) => item.id == widgetId);
      expect(w.x, 1);
      expect(w.y, 2);

      // Move widget
      manager.moveWidget(widgetId, 1, -1);
      w = manager.activeScreen.widgets.firstWhere((item) => item.id == widgetId);
      expect(w.x, 2);
      expect(w.y, 1);

      // Resize widget
      manager.updateWidgetSize(widgetId, 2, 2);
      w = manager.activeScreen.widgets.firstWhere((item) => item.id == widgetId);
      expect(w.w, 2);
      expect(w.h, 2);

      manager.resizeWidget(widgetId, -1, 1);
      w = manager.activeScreen.widgets.firstWhere((item) => item.id == widgetId);
      expect(w.w, 1);
      expect(w.h, 3);

      // Clamping checks: width cannot exceed grid columns (4), x clamped so x+w <= 4
      manager.updateWidgetPlacement(w.copyWith(x: 3, w: 3, y: -5, h: 10));
      w = manager.activeScreen.widgets.firstWhere((item) => item.id == widgetId);
      expect(w.w, 3);
      expect(w.x, 1); // clamped to 4 - 3 = 1
      expect(w.y, 0); // clamped to min 0
      expect(w.h, 6); // clamped to max 6
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
  });
}
