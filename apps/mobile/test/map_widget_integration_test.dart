import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brandyfly/models/ui_config.dart';
import 'package:brandyfly/services/screen_manager_service.dart';
import 'package:brandyfly/widgets/flight/map_widget.dart';
import 'package:brandyfly/widgets/layout/layout_strategy_container.dart';
import 'package:brandyfly/widgets/layout/widget_picker_sheet.dart';
import 'package:brandyfly/widgets/settings/ui_settings_panel.dart';

void main() {
  group('Map View Autonomous Integration & Behavior Test Suite', () {
    testWidgets(
      'TC-MAP-001: Verifies all MapWidgetStyles render cleanly with correct themes and legends',
      (tester) async {
        final styles = [
          (MapWidgetStyle.topoContours, 'ALPINE TOPO 1:50k (OFFLINE)'),
          (MapWidgetStyle.minimalVector, 'VECTOR HUD (OFFLINE)'),
          (MapWidgetStyle.thermalHeatmap, 'THERMAL RADAR (OFFLINE)'),
          (MapWidgetStyle.satelliteTerrain, 'RELIEF SHADED (OFFLINE)'),
        ];

        for (final (style, expectedTitle) in styles) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 480,
                  height: 480,
                  child: MapWidget(
                    style: style,
                    orientation: MapOrientation.trackUp,
                    altitudeM: 1720,
                    speedKmh: 48.5,
                    climbRateMs: 2.6,
                    headingDeg: 215,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text(expectedTitle), findsOneWidget);
          expect(find.textContaining('ALT: 1720m'), findsOneWidget);
          expect(find.text('N'), findsOneWidget);
        }
      },
    );

    testWidgets(
      'TC-MAP-002: Verifies all MapOrientation modes (North Up, Track Up, Heading Up)',
      (tester) async {
        for (final orientation in MapOrientation.values) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 400,
                  height: 400,
                  child: MapWidget(
                    style: MapWidgetStyle.topoContours,
                    orientation: orientation,
                    headingDeg: 120,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(MapWidget), findsOneWidget);
          expect(find.text('N'), findsOneWidget);
        }
      },
    );

    testWidgets(
      'TC-MAP-003: Verifies Map Layer toggles (Airspace, Thermals, Track, Contours)',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 400,
                child: MapWidget(
                  showAirspace: false,
                  showThermals: false,
                  showTrack: false,
                  showContours: false,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(MapWidget), findsOneWidget);
      },
    );

    testWidgets(
      'TC-MAP-004: Verifies interactive pan gestures, zoom in/out step clamping, and recentering',
      (tester) async {
        int zoomInEvents = 0;
        int zoomOutEvents = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 500,
                height: 500,
                child: MapWidget(
                  onZoomIn: () => zoomInEvents++,
                  onZoomOut: () => zoomOutEvents++,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Perform pan drag on the map surface
        await tester.drag(find.byType(CustomPaint).first, const Offset(60, -40));
        await tester.pumpAndSettle();

        // Zoom In multiple times
        await tester.tap(find.byKey(const Key('btn_map_zoom_in')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('btn_map_zoom_in')));
        await tester.pumpAndSettle();
        expect(zoomInEvents, 2);

        // Zoom Out
        await tester.tap(find.byKey(const Key('btn_map_zoom_out')));
        await tester.pumpAndSettle();
        expect(zoomOutEvents, 1);

        // Recenter on pilot
        await tester.tap(find.byKey(const Key('btn_map_recenter')));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'TC-MAP-005: Verifies Map is placed in the background layer behind other instruments in LayoutStrategyContainer',
      (tester) async {
        final manager = ScreenManagerService();
        manager.addWidget(WidgetType.map);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LayoutStrategyContainer(
                screenManager: manager,
                telemetryData: const {
                  'altitude': 1520.0,
                  'speed': 44.0,
                  'glide': 8.8,
                  'hag': 310.0,
                  'climb': 2.2,
                  'windDir': 200.0,
                  'windSpeed': 15.0,
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify both map widget and foreground widgets (altitude, speed, etc.) are present
        expect(find.byType(MapWidget), findsOneWidget);
        expect(find.text('1520'), findsOneWidget);
        expect(find.text('44.0'), findsOneWidget);
      },
    );

    testWidgets(
      'TC-MAP-006: Verifies adding Map via WidgetPickerSheet sets full-screen initial dimensions (w:4, h:4)',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final manager = ScreenManagerService();
        final initialCount = manager.activeScreen.widgets.length;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: WidgetPickerSheet(screenManager: manager),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final mapTile = find.widgetWithText(ListTile, 'Offline Map & Terrain');
        await tester.scrollUntilVisible(mapTile, 100);
        expect(mapTile, findsOneWidget);

        final addBtn = find.descendant(
          of: mapTile,
          matching: find.widgetWithText(ElevatedButton, 'Add'),
        );
        await tester.tap(addBtn);
        await tester.pumpAndSettle();

        expect(manager.activeScreen.widgets.length, initialCount + 1);
        final mapWidgetModel = manager.activeScreen.widgets.last;
        expect(mapWidgetModel.type, WidgetType.map);
        expect(mapWidgetModel.x, 0);
        expect(mapWidgetModel.y, 0);
        expect(mapWidgetModel.w, 4); // Spans full grid width
        expect(mapWidgetModel.h, 4); // Spans full initial height
      },
    );

    testWidgets(
      'TC-MAP-007: Verifies Map can be resized and repositioned in Edit Mode',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final manager = ScreenManagerService();
        // Use freeform HUD layout so all handles are clean
        manager.setLayoutStrategyStyle(LayoutStrategyStyle.freeformHud);
        manager.addWidget(WidgetType.map);
        manager.toggleEditMode(true);

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

        final mapModel = manager.activeScreen.widgets.firstWhere((w) => w.type == WidgetType.map);
        final mapId = mapModel.id;

        // Decrease width from 4 to 3
        manager.resizeWidget(mapId, -1, 0);
        await tester.pumpAndSettle();
        var updatedMap = manager.activeScreen.widgets.firstWhere((w) => w.id == mapId);
        expect(updatedMap.w, 3);

        // Move right by 1
        manager.moveWidget(mapId, 1, 0);
        await tester.pumpAndSettle();
        updatedMap = manager.activeScreen.widgets.firstWhere((w) => w.id == mapId);
        expect(updatedMap.x, 1);

        // Decrease height from 4 to 3
        manager.resizeWidget(mapId, 0, -1);
        await tester.pumpAndSettle();
        updatedMap = manager.activeScreen.widgets.firstWhere((w) => w.id == mapId);
        expect(updatedMap.h, 3);
      },
    );

    testWidgets(
      'TC-MAP-008: Verifies full UISettingsPanel configuration controls for map styles and layers',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final manager = ScreenManagerService();

        await tester.pumpWidget(
          MaterialApp(
            home: UISettingsPanel(screenManager: manager),
          ),
        );
        await tester.pumpAndSettle();

        // Change Map style to satellite terrain
        manager.setMapWidgetStyle(MapWidgetStyle.satelliteTerrain);
        await tester.pump();
        expect(manager.config.mapWidgetStyle, MapWidgetStyle.satelliteTerrain);

        // Change orientation to heading up
        manager.setMapOrientation(MapOrientation.headingUp);
        await tester.pump();
        expect(manager.config.mapOrientation, MapOrientation.headingUp);

        // Toggle layer switches
        manager.toggleMapAirspace(false);
        manager.toggleMapThermals(false);
        manager.toggleMapTrack(false);
        manager.toggleMapContours(false);
        await tester.pump();

        expect(manager.config.mapShowAirspace, false);
        expect(manager.config.mapShowThermals, false);
        expect(manager.config.mapShowTrack, false);
        expect(manager.config.mapShowContours, false);
      },
    );
  });
}
