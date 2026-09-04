import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brandyfly/models/ui_config.dart';
import 'package:brandyfly/services/flight_replay_service.dart';
import 'package:brandyfly/services/screen_manager_service.dart';
import 'package:brandyfly/widgets/flight/altitude_sparkline_chart.dart';
import 'package:brandyfly/widgets/flight/map_widget.dart';
import 'package:brandyfly/widgets/flight/numeric_text_widget.dart';
import 'package:brandyfly/widgets/flight/replay_control_overlay.dart';
import 'package:brandyfly/widgets/flight/thermal_map_widget.dart';
import 'package:brandyfly/widgets/flight/vario_lift_sink_bar.dart';
import 'package:brandyfly/widgets/flight/wind_direction_widget.dart';
import 'package:brandyfly/widgets/layout/layout_strategy_container.dart';
import 'package:brandyfly/widgets/layout/widget_picker_sheet.dart';
import 'package:brandyfly/widgets/navigation/top_nav_bar.dart';
import 'package:brandyfly/widgets/settings/ui_settings_panel.dart';

void main() {
  group('UI Components Widget Tests', () {
    testWidgets('NumericTextWidget renders all visual mockup styles', (
      tester,
    ) async {
      for (final style in NumericWidgetStyle.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NumericTextWidget(
                label: 'ALT',
                value: '1850',
                unit: 'm',
                style: style,
              ),
            ),
          ),
        );
        expect(find.textContaining('1850'), findsOneWidget);
      }
    });

    testWidgets('AltitudeSparklineChart renders all visual styles', (tester) async {
      for (final style in AltitudeChartStyle.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AltitudeSparklineChart(
                history: const [1000.0, 1020.0, 1050.0, 1040.0],
                style: style,
              ),
            ),
          ),
        );
        expect(find.byType(AltitudeSparklineChart), findsOneWidget);
        if (style == AltitudeChartStyle.minimalSparkline) {
          expect(find.text('ALTITUDE HISTORY (SPARKLINE)'), findsOneWidget);
        } else if (style == AltitudeChartStyle.filledAreaGraph) {
          expect(find.text('ALTITUDE PROFILE (AREA)'), findsOneWidget);
        } else if (style == AltitudeChartStyle.detailedGrid) {
          expect(find.text('ALTITUDE / TIME GRID'), findsOneWidget);
        }
      }
    });

    testWidgets('AltitudeSparklineChart renders with empty history without crashing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AltitudeSparklineChart(
              history: [],
              style: AltitudeChartStyle.minimalSparkline,
            ),
          ),
        ),
      );

      expect(find.byType(AltitudeSparklineChart), findsOneWidget);
    });

    testWidgets('WindDirectionWidget renders relative arrow, compass rose, and windsock', (
      tester,
    ) async {
      for (final style in WindWidgetStyle.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: WindDirectionWidget(
                directionDegrees: 210,
                speedKmH: 20.0,
                style: style,
              ),
            ),
          ),
        );
        expect(find.textContaining('20'), findsOneWidget);
      }
    });

    testWidgets('VarioLiftSinkBar renders all vario styles', (
      tester,
    ) async {
      for (final style in LiftSinkBarStyle.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: VarioLiftSinkBar(
                climbRateMs: 2.4,
                style: style,
              ),
            ),
          ),
        );
        expect(find.textContaining('2.4'), findsOneWidget);
      }
    });

    testWidgets('TopNavBarOverlay slides down and shows controls', (
      tester,
    ) async {
      final manager = ScreenManagerService();
      manager.toggleNavBar(true);

      await tester.pumpWidget(
        MaterialApp(
          home: TopNavBarOverlay(
            screenManager: manager,
            child: const Scaffold(body: Text('Main Body')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('BrandyFly Navigation'), findsOneWidget);
      expect(find.text('Edit Mode'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('UISettingsPanel allows changing shell preferences and screen layout strategy', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final manager = ScreenManagerService();

      await tester.pumpWidget(
        MaterialApp(home: UISettingsPanel(screenManager: manager)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Application Settings'), findsOneWidget);
      expect(find.text('SHELL & NAVIGATION PREFERENCES'), findsOneWidget);

      final screenMgmtFinder = find.text('FLIGHT SCREEN MANAGEMENT');
      await tester.scrollUntilVisible(screenMgmtFinder, 100);
      expect(screenMgmtFinder, findsOneWidget);

      manager.setNavBarStyle(NavBarStyle.floatingPill);
      manager.setScreenLayoutStrategy('normal_flight', LayoutStrategyStyle.freeformHud);
      await tester.pump();

      expect(
        manager.config.navBarStyle,
        NavBarStyle.floatingPill,
      );
      expect(
        manager.activeScreen.layoutStrategy,
        LayoutStrategyStyle.freeformHud,
      );
    });

    testWidgets(
      'LayoutStrategyContainer renders based on activeScreen.layoutStrategy',
      (tester) async {
        final manager = ScreenManagerService();
        manager.toggleEditMode(true);

        for (final strategy in LayoutStrategyStyle.values) {
          manager.setScreenLayoutStrategy('normal_flight', strategy);
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: LayoutStrategyContainer(
                  screenManager: manager,
                  telemetryData: const {
                    'altitude': 1450.0,
                    'speed': 42.5,
                    'glide': 8.4,
                    'hag': 320.0,
                    'climb': 1.8,
                    'windDir': 220.0,
                    'windSpeed': 14.0,
                    'history': [1400.0, 1420.0, 1450.0],
                  },
                ),
              ),
            ),
          );
          expect(find.text('Done Editing'), findsOneWidget);
          expect(find.text('Add Widget'), findsOneWidget);
        }
      },
    );

    testWidgets(
      'LayoutStrategyContainer allows interactive repositioning, resizing, and in-place style tuning',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final manager = ScreenManagerService();
        manager.toggleEditMode(true);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LayoutStrategyContainer(
                screenManager: manager,
                telemetryData: const {'altitude': 1450.0, 'speed': 42.5},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final targetWidget = manager.activeScreen.widgets.firstWhere((w) => w.type == WidgetType.altitude);
        final id = targetWidget.id;

        // Test position nudge right button
        final initialX = targetWidget.x;
        await tester.tap(find.byKey(Key('btn_move_right_$id')));
        await tester.pumpAndSettle();
        expect(
          manager.activeScreen.widgets.firstWhere((w) => w.id == id).x,
          initialX + 1,
        );

        // Test width increase button
        final currentW = manager.activeScreen.widgets.firstWhere((w) => w.id == id).w;
        await tester.tap(find.byKey(Key('btn_inc_width_$id')));
        await tester.pumpAndSettle();
        expect(
          manager.activeScreen.widgets.firstWhere((w) => w.id == id).w,
          currentW + 1,
        );

        // Test in-place config dialog / sheet
        await tester.tap(find.byKey(Key('btn_config_$id')));
        await tester.pumpAndSettle();
        expect(find.text('Configure ${targetWidget.type.name.toUpperCase()}'), findsOneWidget);
        expect(find.text('POSITION & SIZE'), findsOneWidget);
        expect(find.text('NUMERIC DISPLAY STYLE'), findsOneWidget);

        // Select 'Retro Digital' style chip
        await tester.tap(find.text('Retro Digital'));
        await tester.pumpAndSettle();

        // Tap Apply in config dialog
        await tester.tap(find.text('Apply'));
        await tester.pumpAndSettle();
        expect(find.text('Configure ${targetWidget.type.name.toUpperCase()}'), findsNothing);

        // Verify style was updated on the widget
        final updatedPlacement = manager.activeScreen.widgets.firstWhere((w) => w.id == id);
        expect(updatedPlacement.numericStyle, NumericWidgetStyle.retroDigital);

        // Test Corner Drag Resize handle
        final resizeHandleFinder = find.byKey(Key('resize_handle_$id'));
        expect(resizeHandleFinder, findsOneWidget);

        final beforeDragW = manager.activeScreen.widgets.firstWhere((w) => w.id == id).w;
        final beforeDragH = manager.activeScreen.widgets.firstWhere((w) => w.id == id).h;

        // Drag corner handle down and right
        await tester.drag(resizeHandleFinder, const Offset(100.0, 100.0));
        await tester.pumpAndSettle();

        final afterDrag = manager.activeScreen.widgets.firstWhere((w) => w.id == id);
        expect(afterDrag.w >= beforeDragW, true);
        expect(afterDrag.h >= beforeDragH, true);
      },
    );

    testWidgets('Map Widget in Edit Mode allows configuring Map style and layer toggles in-place', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final manager = ScreenManagerService();
      manager.addScreen('Map Screen');
      manager.addWidget(WidgetType.map);
      manager.toggleEditMode(true);

      final mapWidget = manager.activeScreen.widgets.firstWhere((w) => w.type == WidgetType.map);
      final id = mapWidget.id;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LayoutStrategyContainer(
              screenManager: manager,
              telemetryData: const {'altitude': 1450.0, 'speed': 42.5},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open tune dialog for map widget
      await tester.tap(find.byKey(Key('btn_config_$id')));
      await tester.pumpAndSettle();

      expect(find.text('Configure MAP'), findsOneWidget);
      expect(find.text('MAP STYLE'), findsOneWidget);
      expect(find.text('MAP LAYER OVERLAYS'), findsOneWidget);

      // Select Thermal Radar
      await tester.tap(find.text('Thermal Radar'));
      await tester.pumpAndSettle();

      // Select North Up
      await tester.tap(find.text('North Up'));
      await tester.pumpAndSettle();

      // Apply
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      final updatedMap = manager.activeScreen.widgets.firstWhere((w) => w.id == id);
      expect(updatedMap.mapStyle, MapWidgetStyle.thermalHeatmap);
      expect(updatedMap.mapOrientation, MapOrientation.northUp);
    });

    testWidgets('Widgets on same or different screens maintain independent styling', (
      tester,
    ) async {
      final manager = ScreenManagerService();
      // Configure screen 1 widget with Retro Digital
      final w1 = manager.activeScreen.widgets.firstWhere((w) => w.id == 'w1');
      manager.updateWidgetPlacement(w1.copyWith(numericStyle: NumericWidgetStyle.retroDigital));

      // Add screen 2 and configure a widget with High Contrast Box
      manager.addScreen('Screen 2');
      manager.addWidget(WidgetType.altitude);
      final screen2Widget = manager.activeScreen.widgets.last;
      manager.updateWidgetPlacement(
        screen2Widget.copyWith(numericStyle: NumericWidgetStyle.highContrastBox),
      );

      // Verify screen 2 widget is highContrastBox
      expect(
        manager.activeScreen.widgets.first.effectiveNumericStyle,
        NumericWidgetStyle.highContrastBox,
      );

      // Switch back to screen 1 and verify w1 is still retroDigital
      manager.setActiveScreen('normal_flight');
      final w1Restored = manager.activeScreen.widgets.firstWhere((w) => w.id == 'w1');
      expect(w1Restored.effectiveNumericStyle, NumericWidgetStyle.retroDigital);
    });

    testWidgets('Flight widgets scale smoothly within various parent constraints', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(
                    width: 300,
                    height: 200,
                    child: const NumericTextWidget(
                      label: 'Altitude',
                      value: '1850',
                      unit: 'm',
                      style: NumericWidgetStyle.minimalistText,
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    height: 300,
                    child: const VarioLiftSinkBar(
                      climbRateMs: 3.5,
                      style: LiftSinkBarStyle.verticalEdgeBar,
                    ),
                  ),
                  SizedBox(
                    width: 250,
                    height: 250,
                    child: const WindDirectionWidget(
                      directionDegrees: 180,
                      speedKmH: 22.0,
                      style: WindWidgetStyle.miniCompassRose,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('1850'), findsOneWidget);
      expect(find.textContaining('+3.5'), findsOneWidget);
      expect(find.textContaining('22 km/h'), findsOneWidget);
    });

    testWidgets('MapWidget renders across all visual MapWidgetStyles', (
      tester,
    ) async {
      for (final style in MapWidgetStyle.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 400,
                child: MapWidget(
                  style: style,
                  orientation: MapOrientation.trackUp,
                  altitudeM: 1650,
                  speedKmh: 45,
                  climbRateMs: 2.1,
                  headingDeg: 190,
                ),
              ),
            ),
          ),
        );
        expect(find.byType(MapWidget), findsOneWidget);
        expect(find.textContaining('OFFLINE'), findsOneWidget);
        expect(find.textContaining('1650m'), findsOneWidget);
        expect(find.text('N'), findsOneWidget);
      }
    });

    testWidgets('MapWidget handles interactive zoom in, zoom out, and recenter', (
      tester,
    ) async {
      int zoomInCount = 0;
      int zoomOutCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: MapWidget(
                onZoomIn: () => zoomInCount++,
                onZoomOut: () => zoomOutCount++,
              ),
            ),
          ),
        ),
      );

      // Tap zoom in
      await tester.tap(find.byKey(const Key('btn_map_zoom_in')));
      await tester.pump();
      expect(zoomInCount, 1);

      // Tap zoom out
      await tester.tap(find.byKey(const Key('btn_map_zoom_out')));
      await tester.pump();
      expect(zoomOutCount, 1);

      // Tap recenter
      await tester.tap(find.byKey(const Key('btn_map_recenter')));
      await tester.pump();
      expect(find.byType(MapWidget), findsOneWidget);
    });

    testWidgets('WidgetPickerSheet shows Map Widget and adds it with full screen initial size', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
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

      final mapItemFinder = find.widgetWithText(ListTile, 'Offline Map & Terrain');
      await tester.scrollUntilVisible(mapItemFinder, 100);
      expect(mapItemFinder, findsOneWidget);

      final addButtonFinder = find.descendant(
        of: mapItemFinder,
        matching: find.widgetWithText(ElevatedButton, 'Add'),
      );
      await tester.tap(addButtonFinder);
      await tester.pumpAndSettle();

      final lastWidget = manager.activeScreen.widgets.last;
      expect(lastWidget.type, WidgetType.map);
      expect(lastWidget.w, 8); // Full screen width
      expect(lastWidget.h, 8); // Full screen height
    });

    testWidgets('ThermalMapWidget renders Option 1 (XCtrack), Option 2 (Burnair Core), and Option 3 (Navigator Ribbon)', (
      tester,
    ) async {
      for (final style in ThermalMapStyle.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 400,
                child: ThermalMapWidget(
                  style: style,
                  showCore: true,
                  climbRateMs: 2.5,
                  altitudeM: 1600.0,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(ThermalMapWidget), findsOneWidget);

        if (style == ThermalMapStyle.xctrackBubbles) {
          expect(find.text('XCtrack Bubbles'), findsOneWidget);
        } else if (style == ThermalMapStyle.burnairCore) {
          expect(find.text('Burnair Core Assist'), findsOneWidget);
        } else if (style == ThermalMapStyle.navigatorRibbon) {
          expect(find.text('Navigator Ribbon'), findsOneWidget);
        }
      }
    });

    testWidgets('ThermalMapWidget zoom and recenter buttons respond to user interaction', (
      tester,
    ) async {
      int zoomInCount = 0;
      int zoomOutCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: ThermalMapWidget(
                onZoomIn: () => zoomInCount++,
                onZoomOut: () => zoomOutCount++,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Tap zoom in
      await tester.tap(find.byKey(const Key('btn_thermal_zoom_in')));
      await tester.pump();
      expect(zoomInCount, 1);

      // Tap zoom out
      await tester.tap(find.byKey(const Key('btn_thermal_zoom_out')));
      await tester.pump();
      expect(zoomOutCount, 1);
    });

    testWidgets('WidgetPickerSheet shows Thermal Assistant Map and adds it with full screen initial size', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
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

      final thermalItemFinder = find.widgetWithText(ListTile, 'Thermal Assistant Map');
      await tester.scrollUntilVisible(thermalItemFinder, 100);
      expect(thermalItemFinder, findsOneWidget);

      final addButtonFinder = find.descendant(
        of: thermalItemFinder,
        matching: find.widgetWithText(ElevatedButton, 'Add'),
      );
      await tester.tap(addButtonFinder);
      await tester.pumpAndSettle();

      final lastWidget = manager.activeScreen.widgets.last;
      expect(lastWidget.type, WidgetType.thermalMap);
      expect(lastWidget.w, 8); // Full screen width by default
      expect(lastWidget.h, 8); // Full screen height by default
      expect(lastWidget.effectiveThermalMapStyle, ThermalMapStyle.xctrackBubbles);
    });

    testWidgets('Default thermaling screen contains thermalMap in widgets list', (
      tester,
    ) async {
      final config = UIConfig.defaultConfig();
      final thermalingScreen = config.screens.firstWhere((s) => s.id == 'thermaling');

      final thermalWidget = thermalingScreen.widgets.firstWhere((w) => w.type == WidgetType.thermalMap);
      expect(thermalWidget.w, 8);
      expect(thermalWidget.h, 8);
      expect(thermalWidget.effectiveThermalMapStyle, ThermalMapStyle.xctrackBubbles);
    });

    testWidgets('TopNavBarOverlay opens via top grab handle tap and slides down', (
      tester,
    ) async {
      final manager = ScreenManagerService();

      await tester.pumpWidget(
        MaterialApp(
          home: TopNavBarOverlay(
            screenManager: manager,
            child: const Scaffold(body: Text('Main Body')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final grabHandleFinder = find.byKey(const Key('top_nav_grab_handle'));
      expect(grabHandleFinder, findsOneWidget);

      // Tap grab handle
      await tester.tap(grabHandleFinder);
      await tester.pumpAndSettle();

      expect(manager.isNavBarVisible, isTrue);
      expect(find.text('BrandyFly Navigation'), findsOneWidget);
    });

    testWidgets('ReplayControlOverlay supports collapsible bottom overlay minimization and expansion', (
      tester,
    ) async {
      final replayService = FlightReplayService();
      bool exited = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReplayControlOverlay(
              replayService: replayService,
              onExit: () => exited = true,
              initiallyExpanded: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Starts expanded: slider and play button visible
      expect(find.byType(Slider), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);

      // Collapse using toggle button
      final collapseBtn = find.byKey(const Key('btn_replay_collapse'));
      expect(collapseBtn, findsOneWidget);
      await tester.tap(collapseBtn);
      await tester.pumpAndSettle();

      // Now minimized: slider hidden
      expect(find.byType(Slider), findsNothing);
      expect(find.byKey(const Key('btn_replay_expand')), findsOneWidget);

      // Expand using grab handle tap
      final bottomHandle = find.byKey(const Key('replay_bottom_grab_handle'));
      expect(bottomHandle, findsOneWidget);
      await tester.tap(bottomHandle);
      await tester.pumpAndSettle();

      // Expanded again: slider visible
      expect(find.byType(Slider), findsOneWidget);

      // Test exit button
      final exitBtn = find.byTooltip('Close Replay');
      expect(exitBtn, findsOneWidget);
      await tester.tap(exitBtn);
      expect(exited, isTrue);
    });
  });
}
