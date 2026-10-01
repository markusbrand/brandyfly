import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brandyfly/models/ui_config.dart';
import 'package:brandyfly/services/screen_manager_service.dart';
import 'package:brandyfly/widgets/layout/layout_strategy_container.dart';
import 'package:brandyfly/widgets/navigation/top_nav_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Layout Resilience and Zero-Overflow Dense Test Suite', () {
    testWidgets('Edit mode does not overflow on narrow phone viewport (360x640)',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final screenManager = ScreenManagerService(
        initialConfig: UIConfig(
          activeScreenId: 'resilience_test',
          screens: [
            FlightScreenModel(
              id: 'resilience_test',
              name: 'Resilience Test',
              layoutStrategy: LayoutStrategyStyle.freeformHud,
              widgets: [
                WidgetPlacementModel(
                  id: 'compact_1x1',
                  type: WidgetType.altitude,
                  x: 0,
                  y: 0,
                  w: 1,
                  h: 1,
                ),
                WidgetPlacementModel(
                  id: 'compact_2x1',
                  type: WidgetType.speed,
                  x: 1,
                  y: 0,
                  w: 2,
                  h: 1,
                ),
                WidgetPlacementModel(
                  id: 'standard_4x3',
                  type: WidgetType.varioBar,
                  x: 3,
                  y: 0,
                  w: 4,
                  h: 3,
                ),
              ],
            ),
          ],
        ),
      );

      screenManager.toggleEditMode(true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LayoutStrategyContainer(
              screenManager: screenManager,
              telemetryData: const {
                'altitude': 1450.0,
                'speed': 42.5,
                'climb': 1.8,
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Ensure no layout overflow assertions occurred
      expect(tester.takeException(), isNull);

      // Verify edit action bar elements exist and are rendered safely
      expect(find.byKey(const Key('btn_add_widget')), findsOneWidget);
      expect(find.byKey(const Key('btn_done_editing')), findsOneWidget);
      // Compact widgets host no controls; each is selectable through its hit
      // area and gets configure/resize chrome outside its bounds.
      for (final id in ['compact_1x1', 'compact_2x1']) {
        expect(find.byKey(Key('widget_box_$id')), findsOneWidget);
        await tester.tap(find.byKey(Key('widget_box_$id')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(screenManager.selectedWidgetId, id);
        expect(find.byKey(Key('btn_config_$id')), findsOneWidget);
        expect(find.byKey(Key('resize_handle_$id')), findsOneWidget);
        expect(find.byKey(Key('size_tag_$id')), findsOneWidget);
        expect(find.byKey(const Key('widget_inspector_panel')), findsOneWidget);
        // Deselect before picking the neighbour (selection chrome sits on top).
        await tester.tap(find.byKey(const Key('btn_inspector_close')));
        await tester.pumpAndSettle();
      }
    });

    testWidgets('All extreme widget sizes (1x1 to 16x32) render without overflow in edit mode',
        (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final screenManager = ScreenManagerService(
        initialConfig: UIConfig(
          activeScreenId: 'extremes_test',
          screens: [
            FlightScreenModel(
              id: 'extremes_test',
              name: 'Extremes Test',
              layoutStrategy: LayoutStrategyStyle.freeformHud,
              widgets: [
                WidgetPlacementModel(
                  id: 'min_cell',
                  type: WidgetType.altitude,
                  x: 0,
                  y: 0,
                  w: 1,
                  h: 1,
                ),
                WidgetPlacementModel(
                  id: 'tall_narrow',
                  type: WidgetType.glide,
                  x: 1,
                  y: 0,
                  w: 1,
                  h: 8,
                ),
                WidgetPlacementModel(
                  id: 'wide_short',
                  type: WidgetType.hag,
                  x: 2,
                  y: 0,
                  w: 6,
                  h: 1,
                ),
                WidgetPlacementModel(
                  id: 'full_span',
                  type: WidgetType.speed,
                  x: 0,
                  y: 8,
                  w: 16,
                  h: 24,
                ),
              ],
            ),
          ],
        ),
      );

      screenManager.toggleEditMode(true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LayoutStrategyContainer(
              screenManager: screenManager,
              telemetryData: const {
                'altitude': 1200.0,
                'speed': 35.0,
                'glide': 7.2,
                'hag': 250.0,
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('TopNavBarOverlay respects SafeArea and has accessible grab target',
        (tester) async {
      final screenManager = ScreenManagerService();

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              padding: EdgeInsets.only(top: 44), // Status bar notch
            ),
            child: Scaffold(
              body: TopNavBarOverlay(
                screenManager: screenManager,
                child: const Center(child: Text('Main Content')),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final grabFinder = find.byKey(const Key('top_nav_grab_handle'));
      expect(grabFinder, findsOneWidget);

      // Verify the grab container height is at least 48dp for accessibility
      final renderBox = tester.renderObject(grabFinder) as RenderBox;
      expect(renderBox.size.height, greaterThanOrEqualTo(48.0));

      // Tap to toggle navigation bar
      await tester.tap(grabFinder);
      await tester.pumpAndSettle();

      expect(screenManager.isNavBarVisible, isTrue);
      expect(find.text('BrandyFly Navigation'), findsOneWidget);
    });

    testWidgets('Telemetry instruments have accessible Semantics labels',
        (tester) async {
      final screenManager = ScreenManagerService(
        initialConfig: UIConfig(
          activeScreenId: 'a11y_test',
          screens: [
            FlightScreenModel(
              id: 'a11y_test',
              name: 'A11y Test',
              layoutStrategy: LayoutStrategyStyle.freeformHud,
              widgets: [
                WidgetPlacementModel(
                  id: 'alt_1',
                  type: WidgetType.altitude,
                  x: 0,
                  y: 0,
                  w: 4,
                  h: 3,
                ),
                WidgetPlacementModel(
                  id: 'vario_1',
                  type: WidgetType.varioBar,
                  x: 4,
                  y: 0,
                  w: 4,
                  h: 3,
                ),
                WidgetPlacementModel(
                  id: 'wind_1',
                  type: WidgetType.windDirection,
                  x: 0,
                  y: 3,
                  w: 4,
                  h: 3,
                ),
              ],
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LayoutStrategyContainer(
              screenManager: screenManager,
              telemetryData: const {
                'altitude': 1520.0,
                'climb': 2.3,
                'windSpeed': 18.0,
                'windDir': 270.0,
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify semantics
      expect(
        find.bySemanticsLabel(RegExp(r'Altitude:\s*1520\s*m')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
            RegExp(r'Vario climb rate:\s*2\.3 meters per second')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp(r'Wind:\s*18\.0 km/h at 270 degrees')),
        findsOneWidget,
      );
    });
  });
}
