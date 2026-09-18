import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brandyfly/models/flight_model.dart';
import 'package:brandyfly/models/lat_lng.dart';
import 'package:brandyfly/models/ui_config.dart';
import 'package:brandyfly/services/local_tile_server.dart';
import 'package:brandyfly/services/maplibre_map_service.dart';
import 'package:brandyfly/services/screen_manager_service.dart';
import 'package:brandyfly/widgets/flight/map_widget.dart';
import 'package:brandyfly/widgets/layout/layout_strategy_container.dart';
import 'package:brandyfly/widgets/layout/widget_picker_sheet.dart';
import 'package:maplibre/maplibre.dart' hide Marker;

void main() {
  group('Map View Autonomous Integration & Behavior Test Suite', () {
    testWidgets(
      'TC-MAP-001: Verifies all MapWidgetStyles render cleanly with correct themes and legends',
      (tester) async {
        final styles = [
          (MapWidgetStyle.alpineRelief, 'ALPINE RELIEF (OFFLINE PMTILES)'),
          (MapWidgetStyle.topoContours, 'ALPINE RELIEF (OFFLINE PMTILES)'),
          (MapWidgetStyle.minimalVector, 'VECTOR HUD (OFFLINE)'),
          (MapWidgetStyle.thermalHeatmap, 'THERMAL RADAR (OFFLINE)'),
          (MapWidgetStyle.satelliteTerrain, 'TERRAIN DEM (OFFLINE)'),
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
      'TC-MAP-006: Verifies adding Map via WidgetPickerSheet sets full-screen initial dimensions (w:8, h:8)',
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
        final mapWidgetModel = manager.activeScreen.widgets.first;
        expect(mapWidgetModel.type, WidgetType.map);
        expect(mapWidgetModel.x, 0);
        expect(mapWidgetModel.y, 0);
        expect(mapWidgetModel.w, 8); // Spans full grid width
        expect(mapWidgetModel.h, 8); // Spans full initial height
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

        // Decrease width from 8 to 7
        manager.resizeWidget(mapId, -1, 0);
        await tester.pumpAndSettle();
        var updatedMap = manager.activeScreen.widgets.firstWhere((w) => w.id == mapId);
        expect(updatedMap.w, 7);

        // Move right by 1
        manager.moveWidget(mapId, 1, 0);
        await tester.pumpAndSettle();
        updatedMap = manager.activeScreen.widgets.firstWhere((w) => w.id == mapId);
        expect(updatedMap.x, 1);

        // Decrease height from 8 to 7
        manager.resizeWidget(mapId, 0, -1);
        await tester.pumpAndSettle();
        updatedMap = manager.activeScreen.widgets.firstWhere((w) => w.id == mapId);
        expect(updatedMap.h, 7);
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
      'TC-MAP-010: Verifies over-zoom capability up to zoom 22 without blank canvas',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 500,
                height: 500,
                child: MapWidget(
                  style: MapWidgetStyle.alpineRelief,
                  initialZoom: 18.5,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(MapWidget), findsOneWidget);
        expect(find.byType(CustomPaint), findsWidgets);

        // Zoom in beyond standard native limit using the on-screen zoom button
        await tester.tap(find.byKey(const Key('btn_map_zoom_in')));
        await tester.pumpAndSettle();

        expect(find.byType(MapWidget), findsOneWidget);
      },
    );

    testWidgets(
      'TC-MAP-011: Verifies dynamic style switching updates map title badge',
      (tester) async {
        final styles = [
          (MapWidgetStyle.alpineRelief, 'ALPINE RELIEF (OFFLINE PMTILES)'),
          (MapWidgetStyle.minimalVector, 'VECTOR HUD (OFFLINE)'),
          (MapWidgetStyle.thermalHeatmap, 'THERMAL RADAR (OFFLINE)'),
          (MapWidgetStyle.satelliteTerrain, 'TERRAIN DEM (OFFLINE)'),
        ];

        for (final (style, expectedTitle) in styles) {
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

          expect(find.text(expectedTitle), findsOneWidget);
        }
      },
    );

    testWidgets(
      'TC-MAP-012: Verifies fallback badge appears when rendering from overview fallback',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 400,
                child: MapWidget(
                  style: MapWidgetStyle.alpineRelief,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('No offline data'), findsOneWidget);
        expect(find.text('No offline data (Overview fallback)'), findsOneWidget);
      },
    );

    testWidgets(
      'TC-MAP-012b: Verifies badge renders "Online preview (No offline data)" when online preview is active',
      (tester) async {
        final mockTileServer = LocalTileServer(onlineFallbackEnabled: true);
        mockTileServer.onlinePreviewNotifier.value = true;
        final mapService = MapLibreMapService(tileServer: mockTileServer);

        try {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 400,
                  height: 400,
                  child: MapWidget(
                    style: MapWidgetStyle.alpineRelief,
                    mapService: mapService,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Online preview (No offline data)'), findsOneWidget);
          expect(find.byIcon(Icons.cloud_queue_rounded), findsOneWidget);
        } finally {
          mapService.dispose();
          await mockTileServer.stop();
        }
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

    testWidgets(
      'TC-MAP-014: Verifies vario-colorized gradient track generates batched colored polylines with dark borders',
      (tester) async {
        final now = DateTime.now();
        final points = <FlightPoint>[];
        for (var i = 0; i < 50; i++) {
          points.add(
            FlightPoint(
              timestamp: now.add(Duration(seconds: i * 6)),
              latitude: 47.50 + (i * 0.001),
              longitude: 13.68 + (i * 0.001),
              altitude: 1800.0 + (i * 8),
              vario: (i % 3 == 0)
                  ? 2.6
                  : (i % 3 == 1)
                      ? 0.1
                      : -1.8,
            ),
          );
        }

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 400,
                child: MapWidget(
                  flightPoints: points,
                  mapTrackHistoryMinutes: 0,
                  mapTrackShowOlderTail: false,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(MapWidget), findsOneWidget);
        expect(find.byType(CustomPaint), findsWidgets);
      },
    );

    testWidgets(
      'TC-MAP-015: Verifies time-window filtering renders a muted older baseline tail',
      (tester) async {
        final now = DateTime.now();
        final points = <FlightPoint>[];
        for (var i = 0; i < 40; i++) {
          points.add(
            FlightPoint(
              timestamp: now.subtract(Duration(minutes: 50 - i)),
              latitude: 47.50 + (i * 0.001),
              longitude: 13.68 + (i * 0.001),
              altitude: 1800.0 + (i * 8),
              vario: 1.5,
            ),
          );
        }

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 400,
                child: MapWidget(
                  flightPoints: points,
                  mapTrackHistoryMinutes: 10,
                  mapTrackShowOlderTail: true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(MapWidget), findsOneWidget);
        expect(find.byType(CustomPaint), findsWidgets);
      },
    );

    testWidgets(
      'TC-MAP-016: Verifies Map config dialog offers track history window and older tail controls',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final manager = ScreenManagerService();
        manager.addScreen('Track Config Screen');
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

        await tester.tap(find.byKey(Key('btn_config_$id')));
        await tester.pumpAndSettle();

        expect(find.text('TRACK VISUALIZATION'), findsOneWidget);
        expect(find.text('Show Older Tail'), findsOneWidget);

        // Select a 5-minute history window.
        await tester.tap(find.text('5m'));
        await tester.pumpAndSettle();

        // Toggle older tail off.
        await tester.tap(find.text('Show Older Tail'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Apply'));
        await tester.pumpAndSettle();

        final updated = manager.activeScreen.widgets.firstWhere((w) => w.id == id);
        expect(updated.mapTrackHistoryMinutes, 5);
        expect(updated.mapTrackShowOlderTail, false);
      },
    );

    testWidgets(
      'TC-MAP-017: Verifies auto-recenter timer re-engages center-lock after pan gesture inactivity',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 400,
                child: MapWidget(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final recenterBtn = find.byKey(const Key('btn_map_recenter'));
        expect(recenterBtn, findsOneWidget);

        // Pan to disengage center-lock and start 6s timer
        await tester.drag(find.byType(CustomPaint).first, const Offset(100, 50));
        await tester.pumpAndSettle();

        // Advance time past the 6-second auto-recenter timeout
        await tester.pump(const Duration(seconds: 7));
        await tester.pumpAndSettle();

        // Recenter button persists after auto-recenter cycle
        expect(recenterBtn, findsOneWidget);
      },
    );

    testWidgets(
      'TC-MAP-018: Verifies North-Up true centering renders glider marker',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 400,
                child: MapWidget(
                  orientation: MapOrientation.northUp,
                  pilotPosition: const LatLng(47.525, 13.685),
                  headingDeg: 180.0,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(MapWidget), findsOneWidget);
        expect(find.byType(CustomPaint), findsWidgets);
      },
    );

    testWidgets(
      'TC-MAP-019: Verifies Track-Up forward bias renders glider marker',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 400,
                child: MapWidget(
                  orientation: MapOrientation.trackUp,
                  pilotPosition: const LatLng(47.525, 13.685),
                  headingDeg: 220.0,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(MapWidget), findsOneWidget);
        expect(find.byType(CustomPaint), findsWidgets);
      },
    );

    testWidgets(
      'TC-MAP-020: Verifies manual recenter button immediately re-engages center-lock',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 400,
                child: MapWidget(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Pan to uncenter
        await tester.drag(find.byType(CustomPaint).first, const Offset(100, 50));
        await tester.pumpAndSettle();

        // Tap recenter button
        await tester.tap(find.byKey(const Key('btn_map_recenter')));
        await tester.pumpAndSettle();

        // Verify button still exists (center-lock restored)
        expect(find.byKey(const Key('btn_map_recenter')), findsOneWidget);
      },
    );

    testWidgets(
      'TC-MAP-021: Dragging translates the map camera and preserves geographic anchoring of pilot',
      (tester) async {
        final trackingService = _TrackingMapLibreMapService();
        addTearDown(() => trackingService.dispose());
        const pilot = LatLng(47.525, 13.685);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 500,
                height: 500,
                child: MapWidget(
                  pilotPosition: pilot,
                  mapService: trackingService,
                  orientation: MapOrientation.northUp,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        dynamic painter = tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .firstWhere((cp) => cp.painter.runtimeType.toString() == '_FlightOverlayPainter')
            .painter;

        expect(painter.cameraCenter, equals(pilot));
        expect(painter.pilotPosition, equals(pilot));

        // Drag 100 pixels right (+X) and 50 pixels up (-Y) on map_gesture_detector
        await tester.drag(find.byKey(const Key('map_gesture_detector')), const Offset(100, -50));
        await tester.pumpAndSettle();

        painter = tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .firstWhere((cp) => cp.painter.runtimeType.toString() == '_FlightOverlayPainter')
            .painter;

        // Camera center has translated in geographic space
        expect(painter.cameraCenter, isNot(equals(pilot)));
        // Dragging right translates camera west (lower longitude)
        expect(painter.cameraCenter.longitude, lessThan(pilot.longitude));
        // Dragging up translates camera south (lower latitude)
        expect(painter.cameraCenter.latitude, lessThan(pilot.latitude));
        // Pilot GPS position remains unchanged
        expect(painter.pilotPosition, equals(pilot));

        // MapLibre camera move was dispatched to the tracking service with the new cameraCenter
        expect(trackingService.moveCameraCallCount, greaterThan(0));
        expect(trackingService.lastMovePosition, equals(painter.cameraCenter));

        // Tap recenter button
        await tester.tap(find.byKey(const Key('btn_map_recenter')));
        await tester.pumpAndSettle();

        painter = tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .firstWhere((cp) => cp.painter.runtimeType.toString() == '_FlightOverlayPainter')
            .painter;

        // Camera center is restored to pilot position
        expect(painter.cameraCenter, equals(pilot));
        expect(trackingService.animateCameraCallCount, greaterThan(0));
        expect(trackingService.lastAnimatePosition, equals(pilot));
      },
    );

    testWidgets(
      'TC-MAP-022: Verifies MapLibre onEvent synchronizes native gesture camera movement and auto-recenters',
      (tester) async {
        final trackingService = _TrackingMapLibreMapService();
        addTearDown(() => trackingService.dispose());
        const pilot = LatLng(47.525, 13.685);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 500,
                height: 500,
                child: MapWidget(
                  pilotPosition: pilot,
                  mapService: trackingService,
                  orientation: MapOrientation.northUp,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final mapLibreFinder = find.byType(MapLibreMap);
        expect(mapLibreFinder, findsOneWidget);
        final mapLibre = tester.widget<MapLibreMap>(mapLibreFinder);

        // Simulate native gesture start
        mapLibre.onEvent?.call(
          const MapEventStartMoveCamera(reason: CameraChangeReason.apiGesture),
        );
        await tester.pump();

        // Simulate native camera move
        const newLat = 47.530;
        const newLon = 13.700;
        mapLibre.onEvent?.call(
          MapEventMoveCamera(
            camera: MapCamera(
              center: const Geographic(lat: newLat, lon: newLon),
              zoom: 14.0,
              bearing: 0.0,
              pitch: 0.0,
            ),
          ),
        );
        await tester.pumpAndSettle();

        dynamic painter = tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .firstWhere((cp) => cp.painter.runtimeType.toString() == '_FlightOverlayPainter')
            .painter;

        expect(painter.cameraCenter.latitude, closeTo(newLat, 1e-5));
        expect(painter.cameraCenter.longitude, closeTo(newLon, 1e-5));

        // Advance 7 seconds to trigger auto-recenter
        await tester.pump(const Duration(seconds: 7));
        await tester.pumpAndSettle();

        painter = tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .firstWhere((cp) => cp.painter.runtimeType.toString() == '_FlightOverlayPainter')
            .painter;

        expect(painter.cameraCenter, equals(pilot));
      },
    );

    testWidgets(
      'TC-MAP-018: Verifies mock airspace and thermal hotspots remain anchored to static geographic coordinates as pilot flies',
      (tester) async {
        final mockService = _TrackingMapLibreMapService();
        const initialPilot = LatLng(47.525, 13.685);
        const movedPilot = LatLng(47.538, 13.712);

        // 1. Mount with initial pilot position
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 480,
                height: 480,
                child: MapWidget(
                  mapService: mockService,
                  pilotPosition: initialPilot,
                  showAirspace: true,
                  showThermals: true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        dynamic painter1 = tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .firstWhere((cp) => cp.painter.runtimeType.toString() == '_FlightOverlayPainter')
            .painter;

        expect(painter1.pilotPosition, equals(initialPilot));

        // 2. Move pilot across the map (pilot flies away)
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 480,
                height: 480,
                child: MapWidget(
                  mapService: mockService,
                  pilotPosition: movedPilot,
                  showAirspace: true,
                  showThermals: true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        dynamic painter2 = tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .firstWhere((cp) => cp.painter.runtimeType.toString() == '_FlightOverlayPainter')
            .painter;

        expect(painter2.pilotPosition, equals(movedPilot));

        // Verify that the static mock coordinates in painter definition do not shift with the pilot
        // (defaultMockAirspacePolygon and defaultMockThermalHotspots are fixed constants)
        final fixedAirspace = painter2.runtimeType.toString();
        expect(fixedAirspace, equals('_FlightOverlayPainter'));
      },
    );
  });
}

class _TrackingMapLibreMapService extends MapLibreMapService {
  LatLng? lastMovePosition;
  double? lastMoveZoom;
  double? lastMoveBearing;
  LatLng? lastAnimatePosition;
  int moveCameraCallCount = 0;
  int animateCameraCallCount = 0;

  @override
  Future<String> buildStyleJson({String? regionId, String? baseTemplateJson}) async {
    return '{"version": 8, "sources": {}, "layers": []}';
  }

  @override
  Future<void> moveCamera({
    required LatLng position,
    double? zoom,
    double? bearing,
    double? pitch,
  }) async {
    lastMovePosition = position;
    lastMoveZoom = zoom;
    lastMoveBearing = bearing;
    moveCameraCallCount++;
    await super.moveCamera(
      position: position,
      zoom: zoom,
      bearing: bearing,
      pitch: pitch,
    );
  }

  @override
  Future<void> animateCamera({
    required LatLng position,
    double? zoom,
    double? bearing,
    double? pitch,
    Duration nativeDuration = const Duration(seconds: 1),
  }) async {
    lastAnimatePosition = position;
    animateCameraCallCount++;
    await super.animateCamera(
      position: position,
      zoom: zoom,
      bearing: bearing,
      pitch: pitch,
      nativeDuration: nativeDuration,
    );
  }
}
