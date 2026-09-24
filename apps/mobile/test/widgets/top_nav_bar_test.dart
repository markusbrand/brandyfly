import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brandyfly/models/ui_config.dart';
import 'package:brandyfly/services/screen_manager_service.dart';
import 'package:brandyfly/widgets/navigation/top_nav_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestShell({
    required ScreenManagerService screenManager,
    Widget? child,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: TopNavBarOverlay(
          screenManager: screenManager,
          child: child ?? const Center(child: Text('Underlying Content')),
        ),
      ),
    );
  }

  group('TopNavBarOverlay Tap & Click Interaction Tests', () {
    testWidgets('Tapping grab handle opens nav bar', (tester) async {
      final screenManager = ScreenManagerService();
      await tester.pumpWidget(buildTestShell(screenManager: screenManager));
      await tester.pumpAndSettle();

      expect(screenManager.isNavBarVisible, isFalse);

      final grabFinder = find.byKey(const Key('top_nav_grab_handle'));
      expect(grabFinder, findsOneWidget);

      await tester.tap(grabFinder);
      await tester.pumpAndSettle();

      expect(screenManager.isNavBarVisible, isTrue);
      expect(find.text('BrandyFly Navigation'), findsOneWidget);
    });

    testWidgets(
        'ChoiceChip click on currently active screen activates and dismisses drawer',
        (tester) async {
      final screenManager = ScreenManagerService(
        initialConfig: const UIConfig(
          activeScreenId: 'screen_1',
          screens: [
            FlightScreenModel(
              id: 'screen_1',
              name: 'Alpine Map Screen',
              widgets: const [],
            ),
            FlightScreenModel(
              id: 'screen_2',
              name: 'Thermal Assist Screen',
              widgets: const [],
            ),
          ],
        ),
      );

      screenManager.toggleNavBar(true);
      await tester.pumpWidget(buildTestShell(screenManager: screenManager));
      await tester.pumpAndSettle();

      expect(screenManager.isNavBarVisible, isTrue);
      expect(screenManager.activeScreen.id, 'screen_1');

      // Tap on the chip that is ALREADY active ('Alpine Map Screen')
      final activeChip = find.byKey(const Key('nav_chip_screen_1'));
      expect(activeChip, findsOneWidget);

      await tester.tap(activeChip);
      await tester.pumpAndSettle();

      // Should keep active screen and dismiss nav bar
      expect(screenManager.activeScreen.id, 'screen_1');
      expect(screenManager.isNavBarVisible, isFalse);
    });

    testWidgets(
        'ChoiceChip click on inactive screen activates it and dismisses drawer',
        (tester) async {
      final screenManager = ScreenManagerService(
        initialConfig: const UIConfig(
          activeScreenId: 'screen_1',
          screens: [
            FlightScreenModel(
              id: 'screen_1',
              name: 'Alpine Map Screen',
              widgets: const [],
            ),
            FlightScreenModel(
              id: 'screen_2',
              name: 'Thermal Assist Screen',
              widgets: const [],
            ),
          ],
        ),
      );

      screenManager.toggleNavBar(true);
      await tester.pumpWidget(buildTestShell(screenManager: screenManager));
      await tester.pumpAndSettle();

      // Tap on inactive chip ('Thermal Assist Screen')
      final targetChip = find.byKey(const Key('nav_chip_screen_2'));
      expect(targetChip, findsOneWidget);

      await tester.tap(targetChip);
      await tester.pumpAndSettle();

      expect(screenManager.activeScreen.id, 'screen_2');
      expect(screenManager.isNavBarVisible, isFalse);
    });

    testWidgets('Tapping Flights action button opens flights screen and dismisses drawer',
        (tester) async {
      final screenManager = ScreenManagerService();
      screenManager.toggleNavBar(true);

      await tester.pumpWidget(buildTestShell(screenManager: screenManager));
      await tester.pumpAndSettle();

      final flightsBtn = find.byKey(const Key('nav_btn_flights'));
      expect(flightsBtn, findsOneWidget);

      await tester.tap(flightsBtn);
      await tester.pumpAndSettle();

      expect(screenManager.isNavBarVisible, isFalse);
      expect(screenManager.isFlightsScreenVisible, isTrue);
    });

    testWidgets('Tapping Edit Mode action button activates edit mode and dismisses drawer',
        (tester) async {
      final screenManager = ScreenManagerService();
      screenManager.toggleNavBar(true);

      await tester.pumpWidget(buildTestShell(screenManager: screenManager));
      await tester.pumpAndSettle();

      final editModeBtn = find.byKey(const Key('nav_btn_edit_mode'));
      expect(editModeBtn, findsOneWidget);

      await tester.tap(editModeBtn);
      await tester.pumpAndSettle();

      expect(screenManager.isNavBarVisible, isFalse);
      expect(screenManager.isEditMode, isTrue);
    });

    testWidgets('Tapping Settings action button opens settings panel and dismisses drawer',
        (tester) async {
      final screenManager = ScreenManagerService();
      screenManager.toggleNavBar(true);

      await tester.pumpWidget(buildTestShell(screenManager: screenManager));
      await tester.pumpAndSettle();

      final settingsBtn = find.byKey(const Key('nav_btn_settings'));
      expect(settingsBtn, findsOneWidget);

      await tester.tap(settingsBtn);
      await tester.pumpAndSettle();

      expect(screenManager.isNavBarVisible, isFalse);
      expect(screenManager.isSettingsVisible, isTrue);
    });

    testWidgets('Tapping drawer background absorbs tap and does not dismiss drawer',
        (tester) async {
      final screenManager = ScreenManagerService();
      screenManager.toggleNavBar(true);

      await tester.pumpWidget(buildTestShell(screenManager: screenManager));
      await tester.pumpAndSettle();

      expect(screenManager.isNavBarVisible, isTrue);

      // Tap on title text inside drawer
      final titleFinder = find.text('BrandyFly Navigation');
      expect(titleFinder, findsOneWidget);
      await tester.tap(titleFinder);
      await tester.pumpAndSettle();

      // Drawer should still remain open!
      expect(screenManager.isNavBarVisible, isTrue);
    });

    testWidgets('Tapping dismiss barrier outside drawer dismisses drawer',
        (tester) async {
      final screenManager = ScreenManagerService();
      screenManager.toggleNavBar(true);

      await tester.pumpWidget(buildTestShell(screenManager: screenManager));
      await tester.pumpAndSettle();

      expect(screenManager.isNavBarVisible, isTrue);

      // Tap near bottom of screen where dismiss barrier is exposed
      await tester.tapAt(const Offset(200, 500));
      await tester.pumpAndSettle();

      expect(screenManager.isNavBarVisible, isFalse);
    });

    testWidgets('Floating pill style action buttons trigger callbacks and close drawer',
        (tester) async {
      final screenManager = ScreenManagerService();
      screenManager.setNavBarStyle(NavBarStyle.floatingPill);
      screenManager.toggleNavBar(true);

      await tester.pumpWidget(buildTestShell(screenManager: screenManager));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('nav_pill_btn_flights')), findsOneWidget);
      expect(find.byKey(const Key('nav_pill_btn_edit_mode')), findsOneWidget);
      expect(find.byKey(const Key('nav_pill_btn_settings')), findsOneWidget);

      await tester.tap(find.byKey(const Key('nav_pill_btn_flights')));
      await tester.pumpAndSettle();

      expect(screenManager.isNavBarVisible, isFalse);
      expect(screenManager.isFlightsScreenVisible, isTrue);
    });
  });
}
