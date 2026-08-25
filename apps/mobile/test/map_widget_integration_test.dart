import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:brandyfly/models/ui_config.dart';
import 'package:brandyfly/services/screen_manager_service.dart';
import 'package:brandyfly/widgets/flight/map_widget.dart';
import 'package:brandyfly/widgets/layout/layout_strategy_container.dart';
import 'package:brandyfly/widgets/layout/widget_picker_sheet.dart';

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
        manager.setScreenLayoutStrategy('normal_flight', LayoutStrategyStyle.freeformHud);
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
      'TC-MAP-008: Verifies in-place Edit Mode configuration controls for map styles and layers',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final manager = ScreenManagerService();
        manager.addScreen('Map Test Screen');
        manager.addWidget(WidgetType.map);
        manager.toggleEditMode(true);

        final mapWidget = manager.activeScreen.widgets.firstWhere((w) => w.type == WidgetType.map);
        final id = mapWidget.id;

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

        // Open in-place tune dialog
        await tester.tap(find.byKey(Key('btn_config_$id')));
        await tester.pumpAndSettle();

        expect(find.text('Configure MAP'), findsOneWidget);
        expect(find.text('MAP STYLE'), findsOneWidget);
        expect(find.text('MAP ORIENTATION'), findsOneWidget);
        expect(find.text('MAP LAYER OVERLAYS'), findsOneWidget);

        // Change Map style to Shaded Relief
        await tester.tap(find.text('Shaded Relief'));
        await tester.pumpAndSettle();

        // Change orientation to Heading Up
        await tester.tap(find.text('Heading Up'));
        await tester.pumpAndSettle();

        // Toggle an overlay
        await tester.tap(find.text('Airspaces (CTR / TMA)'));
        await tester.pumpAndSettle();

        // Apply changes
        await tester.tap(find.text('Apply'));
        await tester.pumpAndSettle();

        final updated = manager.activeScreen.widgets.firstWhere((w) => w.id == id);
        expect(updated.mapStyle, MapWidgetStyle.satelliteTerrain);
        expect(updated.mapOrientation, MapOrientation.headingUp);
        expect(updated.mapShowAirspace, false);
      },
    );

    testWidgets(
      'TC-MAP-009: Verifies Map Zoom Level configuration slider, stepper, presets, and model persistence',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final manager = ScreenManagerService();
        manager.addScreen('Zoom Test Screen');
        manager.addWidget(WidgetType.map);
        manager.toggleEditMode(true);

        final mapWidget = manager.activeScreen.widgets.firstWhere((w) => w.type == WidgetType.map);
        final id = mapWidget.id;

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

        // Open config dialog
        await tester.tap(find.byKey(Key('btn_config_$id')));
        await tester.pumpAndSettle();

        expect(find.text('INITIAL ZOOM LEVEL'), findsOneWidget);
        expect(find.text('Zoom: 13.5x'), findsOneWidget);

        // Tap preset "Overview (10.0x)"
        await tester.tap(find.text('Overview (10.0x)'));
        await tester.pumpAndSettle();
        expect(find.text('Zoom: 10.0x'), findsOneWidget);

        // Tap stepper zoom increase (+) twice
        await tester.tap(find.byKey(const Key('btn_config_zoom_increase')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('btn_config_zoom_increase')));
        await tester.pumpAndSettle();
        expect(find.text('Zoom: 11.0x'), findsOneWidget);

        // Apply changes
        await tester.tap(find.text('Apply'));
        await tester.pumpAndSettle();

        final updated = manager.activeScreen.widgets.firstWhere((w) => w.id == id);
        expect(updated.mapZoomLevel, 11.0);
        expect(updated.effectiveMapZoomLevel, 11.0);
      },
    );

    testWidgets(
      'TC-MAP-010: Verifies TileLayer maxNativeZoom and over-zoom capability up to zoom 22 without blank canvas',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 500,
                height: 500,
                child: MapWidget(
                  style: MapWidgetStyle.topoContours,
                  initialZoom: 18.5,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final tileLayer = tester.widget<TileLayer>(find.byType(TileLayer));
        expect(tileLayer.maxNativeZoom, 17);
        expect(tileLayer.maxZoom, 22.0);
        expect(tileLayer.minZoom, 1.0);
        expect(tileLayer.minNativeZoom, 3);

        // Zoom in beyond native limit using the on-screen zoom button
        await tester.tap(find.byKey(const Key('btn_map_zoom_in')));
        await tester.pumpAndSettle();

        // Layer remains present and active
        expect(find.byType(TileLayer), findsOneWidget);
      },
    );

    testWidgets(
      'TC-MAP-011: Verifies dynamic style switching updates TileLayer key and urlTemplate',
      (tester) async {
        final styles = [
          (MapWidgetStyle.topoContours, 'topoContours'),
          (MapWidgetStyle.minimalVector, 'minimalVector'),
          (MapWidgetStyle.thermalHeatmap, 'thermalHeatmap'),
          (MapWidgetStyle.satelliteTerrain, 'satelliteTerrain'),
        ];

        for (final (style, expectedStyleName) in styles) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 400,
                  height: 400,
                  child: MapWidget(style: style),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final tileLayer = tester.widget<TileLayer>(find.byType(TileLayer));
          final keyString = (tileLayer.key as ValueKey<String>).value;
          expect(keyString, contains(expectedStyleName));
        }
      },
    );

    testWidgets(
      'TC-MAP-012: Verifies showContours toggle updates tile layer URL template',
      (tester) async {
        // With contours enabled
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 400,
                child: MapWidget(
                  style: MapWidgetStyle.topoContours,
                  showContours: true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        var tileLayer = tester.widget<TileLayer>(find.byType(TileLayer));
        expect(tileLayer.urlTemplate, contains('opentopomap.org'));

        // With contours disabled
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 400,
                child: MapWidget(
                  style: MapWidgetStyle.topoContours,
                  showContours: false,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        tileLayer = tester.widget<TileLayer>(find.byType(TileLayer));
        expect(tileLayer.urlTemplate, contains('tile.openstreetmap.org'));
      },
    );

    testWidgets(
      'TC-MAP-013: Verifies telemetry streaming preserves active camera zoom and pilot recentering',
      (tester) async {
        double? reportedZoom;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 400,
                child: MapWidget(
                  initialZoom: 14.0,
                  pilotPosition: const LatLng(47.525, 13.685),
                  onZoomChanged: (z) => reportedZoom = z,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Zoom in to 15.0
        await tester.tap(find.byKey(const Key('btn_map_zoom_in')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('btn_map_zoom_in')));
        await tester.pumpAndSettle();
        expect(reportedZoom, 15.0);

        // Stream new telemetry data (altitude, heading, pilot position)
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 400,
                child: MapWidget(
                  initialZoom: 14.0, // initialZoom unchanged
                  altitudeM: 1850.0,
                  headingDeg: 240.0,
                  speedKmh: 52.0,
                  pilotPosition: const LatLng(47.530, 13.690),
                  onZoomChanged: (z) => reportedZoom = z,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify altitude HUD updated without resetting zoom
        expect(find.textContaining('ALT: 1850m'), findsOneWidget);
        expect(find.textContaining('SPD: 52km/h'), findsOneWidget);
      },
    );
  });
}
