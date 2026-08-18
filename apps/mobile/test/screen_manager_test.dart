import 'package:flutter_test/flutter_test.dart';
import 'package:brandyfly/models/ui_config.dart';
import 'package:brandyfly/services/screen_manager_service.dart';

void main() {
  group('ScreenManagerService Tests', () {
    test('initializes with default config and state', () {
      final manager = ScreenManagerService();
      expect(manager.config.navBarStyle, NavBarStyle.translucentDrawer);
      expect(
        manager.config.layoutStrategyStyle,
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

    test('updates visual mockup style options', () {
      final manager = ScreenManagerService();

      manager.setNavBarStyle(NavBarStyle.floatingPill);
      expect(manager.config.navBarStyle, NavBarStyle.floatingPill);

      manager.setLayoutStrategyStyle(LayoutStrategyStyle.freeformHud);
      expect(
        manager.config.layoutStrategyStyle,
        LayoutStrategyStyle.freeformHud,
      );

      manager.setNumericWidgetStyle(NumericWidgetStyle.highContrastBox);
      expect(
        manager.config.numericWidgetStyle,
        NumericWidgetStyle.highContrastBox,
      );

      manager.setWindWidgetStyle(WindWidgetStyle.miniCompassRose);
      expect(manager.config.windWidgetStyle, WindWidgetStyle.miniCompassRose);
    });

    test('adds, switches, and removes flight screens', () {
      final manager = ScreenManagerService();
      final initialCount = manager.config.screens.length;

      manager.addScreen('Cross Country');
      expect(manager.config.screens.length, initialCount + 1);
      expect(manager.activeScreen.name, 'Cross Country');

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

    test('serializes and deserializes UIConfig correctly', () {
      final config = UIConfig.defaultConfig().copyWith(
        navBarStyle: NavBarStyle.cornerMenu,
        numericWidgetStyle: NumericWidgetStyle.retroDigital,
      );

      final encoded = config.encodeJson();
      final decoded = UIConfig.decodeJson(encoded);

      expect(decoded.navBarStyle, NavBarStyle.cornerMenu);
      expect(decoded.numericWidgetStyle, NumericWidgetStyle.retroDigital);
    });
  });
}
