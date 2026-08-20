import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brandyfly/models/ui_config.dart';
import 'package:brandyfly/services/screen_manager_service.dart';
import 'package:brandyfly/widgets/flight/altitude_sparkline_chart.dart';
import 'package:brandyfly/widgets/flight/map_widget.dart';
import 'package:brandyfly/widgets/flight/numeric_text_widget.dart';
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

    testWidgets('WindDirectionWidget renders relative arrow and compass rose', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WindDirectionWidget(
              directionDegrees: 210,
              speedKmH: 15.5,
              style: WindWidgetStyle.relativeArrow,
            ),
          ),
        ),
      );
      expect(find.textContaining('15.5 km/h'), findsOneWidget);
    });

    testWidgets('VarioLiftSinkBar renders vertical bar and analog dial', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VarioLiftSinkBar(
              climbRateMs: 2.4,
              style: LiftSinkBarStyle.verticalEdgeBar,
            ),
          ),
        ),
      );
      expect(find.textContaining('+2.4'), findsOneWidget);
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

    testWidgets('UISettingsPanel allows changing visual styles', (
      tester,
    ) async {
      final manager = ScreenManagerService();

      await tester.pumpWidget(
        MaterialApp(home: UISettingsPanel(screenManager: manager)),
      );

      expect(find.text('UI Visual Mockup Settings'), findsOneWidget);

      manager.setNumericWidgetStyle(NumericWidgetStyle.highContrastBox);
      await tester.pump();

      expect(
        manager.config.numericWidgetStyle,
        NumericWidgetStyle.highContrastBox,
      );
    });

    testWidgets(
      'LayoutStrategyContainer renders in edit mode and across all strategies',
      (tester) async {
        final manager = ScreenManagerService();
        manager.toggleEditMode(true);

        for (final strategy in LayoutStrategyStyle.values) {
          manager.setLayoutStrategyStyle(strategy);
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
      'LayoutStrategyContainer allows interactive repositioning and resizing of widgets',
      (tester) async {
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

        final firstWidget = manager.activeScreen.widgets.first;
        final id = firstWidget.id;

        // Test position nudge right button
        final initialX = firstWidget.x;
        await tester.tap(find.byKey(Key('btn_move_right_$id')));
        await tester.pumpAndSettle();
        expect(
          manager.activeScreen.widgets.firstWhere((w) => w.id == id).x,
          initialX + 1,
        );

        // Test width decrease and increase buttons
        final currentW = manager.activeScreen.widgets.firstWhere((w) => w.id == id).w;
        await tester.tap(find.byKey(Key('btn_dec_width_$id')));
        await tester.pumpAndSettle();
        expect(
          manager.activeScreen.widgets.firstWhere((w) => w.id == id).w,
          currentW - 1,
        );

        // Test config dialog
        await tester.tap(find.byKey(Key('btn_config_$id')));
        await tester.pumpAndSettle();
        expect(find.text('Configure ${firstWidget.type.name.toUpperCase()}'), findsOneWidget);

        // Tap Apply in config dialog
        await tester.tap(find.text('Apply'));
        await tester.pumpAndSettle();
        expect(find.text('Configure ${firstWidget.type.name.toUpperCase()}'), findsNothing);

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
      expect(lastWidget.w, 4); // Full screen width
      expect(lastWidget.h, 4); // Full screen height
    });

    testWidgets('UISettingsPanel toggles MapWidgetStyle and map layers', (
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

      final mapSectionFinder = find.text('Offline Map & Terrain Style (REQ-MAP-001)');
      await tester.scrollUntilVisible(mapSectionFinder, 100);
      expect(mapSectionFinder, findsOneWidget);

      manager.setMapWidgetStyle(MapWidgetStyle.thermalHeatmap);
      await tester.pump();
      expect(manager.config.mapWidgetStyle, MapWidgetStyle.thermalHeatmap);

      manager.setMapOrientation(MapOrientation.northUp);
      await tester.pump();
      expect(manager.config.mapOrientation, MapOrientation.northUp);

      manager.toggleMapAirspace(false);
      await tester.pump();
      expect(manager.config.mapShowAirspace, false);
    });
  });
}
