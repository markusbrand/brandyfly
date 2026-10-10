import 'package:brandyfly/domain/thermal/thermal_layer_spec.dart';
import 'package:brandyfly/domain/models/cockpit_telemetry.dart';
import 'package:brandyfly/domain/models/ui_config.dart';
import 'package:brandyfly/models/lat_lng.dart';
import 'package:brandyfly/services/maplibre_map_service.dart';
import 'package:brandyfly/services/screen_manager_service.dart';
import 'package:brandyfly/ui/core/bezel_button.dart';
import 'package:brandyfly/ui/features/flight_canvas/views/layout_canvas.dart';
import 'package:brandyfly/ui/features/layout_editor/views/widget_picker_sheet.dart';
import 'package:brandyfly/ui/features/map/view_models/map_camera_view_model.dart';
import 'package:brandyfly/ui/features/map/views/map_control_widgets.dart';
import 'package:brandyfly/ui/features/map/views/map_widget.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeMapService extends MapLibreMapService {
  int moveCalls = 0;
  int animateCalls = 0;
  double? lastZoom;
  LatLng? lastMovePosition;
  LatLng? lastAnimatePosition;

  @override
  Future<String> buildStyleJson({
    String? regionId,
    String? baseTemplateJson,
    ThermalLayerSpec? thermal,
  }) async => '{"version": 8, "sources": {}, "layers": []}';

  @override
  Future<void> moveCamera({
    required LatLng position,
    double? zoom,
    double? bearing,
    double? pitch,
    EdgeInsets padding = EdgeInsets.zero,
  }) async {
    moveCalls++;
    lastZoom = zoom;
    lastMovePosition = position;
  }

  @override
  Future<void> animateCamera({
    required LatLng position,
    double? zoom,
    double? bearing,
    double? pitch,
    Duration nativeDuration = const Duration(seconds: 1),
  }) async {
    animateCalls++;
    lastAnimatePosition = position;
  }
}

WidgetPlacementModel _p(
  String id,
  WidgetType type,
  int x,
  int y,
  int w,
  int h, {
  String? target,
  MapBuiltInControls? builtIn,
}) => WidgetPlacementModel(
  id: id,
  type: type,
  x: x,
  y: y,
  w: w,
  h: h,
  mapControlTarget: target,
  mapBuiltInControls: builtIn,
);

ScreenManagerService _manager(List<WidgetPlacementModel> widgets) =>
    ScreenManagerService(
      initialConfig: UIConfig(
        activeScreenId: 's',
        screens: [FlightScreenModel(id: 's', name: 'S', widgets: widgets)],
      ),
    );

MapCameraViewModel? _cameraFor(
  WidgetTester tester,
  String controlKey,
  String mapId,
) {
  final registry = MapCameraScope.maybeOf(
    tester.element(find.byKey(Key(controlKey))),
  );
  return registry?.lookup(mapId);
}

void main() {
  group('MapCameraViewModel', () {
    test('zoom steps are clamped to limits and disable at bounds', () {
      final vm = MapCameraViewModel(initialZoom: 21.5, maxZoom: 22, minZoom: 1);
      var notifications = 0;
      vm.addListener(() => notifications++);
      vm.zoomIn();
      expect(vm.zoom, 22);
      expect(vm.canZoomIn, isFalse);
      vm.zoomIn();
      expect(notifications, 1, reason: 'no-op at max zoom');
      vm.zoomBy(-30);
      expect(vm.zoom, 1);
      expect(vm.canZoomOut, isFalse);
      vm.dispose();
    });

    test('manual pan releases center-lock and auto-recenters after 6 s', () {
      fakeAsync((async) {
        final vm = MapCameraViewModel();
        vm.beginManualPan();
        expect(vm.centerLocked, isFalse);
        expect(vm.recenterPending, isTrue);
        async.elapse(const Duration(seconds: 5));
        expect(vm.centerLocked, isFalse);
        vm.beginManualPan(); // further pan restarts the timer
        async.elapse(const Duration(seconds: 5));
        expect(vm.centerLocked, isFalse);
        async.elapse(const Duration(seconds: 2));
        expect(vm.centerLocked, isTrue);
        expect(vm.recenterRequests, 1);
        vm.dispose();
      });
    });

    test('zoom during temporary pan restarts the inactivity timer', () {
      fakeAsync((async) {
        final vm = MapCameraViewModel();
        vm.beginManualPan();
        async.elapse(const Duration(seconds: 5));
        vm.zoomIn();
        async.elapse(const Duration(seconds: 5));
        expect(vm.centerLocked, isFalse);
        async.elapse(const Duration(seconds: 1, milliseconds: 1));
        expect(vm.centerLocked, isTrue);
        vm.dispose();
      });
    });

    test('recenter cancels pending timer', () {
      fakeAsync((async) {
        final vm = MapCameraViewModel();
        vm.beginManualPan();
        vm.recenter();
        expect(vm.centerLocked, isTrue);
        expect(vm.recenterPending, isFalse);
        async.elapse(const Duration(seconds: 10));
        expect(vm.recenterRequests, 1);
        vm.dispose();
      });
    });

    test('commands after dispose are ignored and timers cancelled', () {
      fakeAsync((async) {
        final vm = MapCameraViewModel();
        vm.beginManualPan();
        vm.dispose();
        vm.zoomIn();
        vm.recenter();
        async.elapse(const Duration(seconds: 10));
        expect(vm.isDisposed, isTrue);
      });
    });
  });

  group('MapCameraRegistry', () {
    testWidgets('register/unregister notify after the frame', (tester) async {
      final registry = MapCameraRegistry();
      final vm = MapCameraViewModel();
      var notifications = 0;
      registry.addListener(() => notifications++);
      registry.register('m', vm);
      expect(registry.lookup('m'), same(vm));
      expect(notifications, 0);
      await tester.pump();
      expect(notifications, 1);
      registry.unregister('m', MapCameraViewModel()); // other instance: ignored
      expect(registry.lookup('m'), same(vm));
      registry.unregister('m', vm);
      expect(registry.lookup('m'), isNull);
      expect(registry.lookup(null), isNull);
      await tester.pump();
      registry.dispose();
      vm.dispose();
    });
  });

  group('Map control widgets with a standalone map', () {
    Future<_FakeMapService> pumpHarness(
      WidgetTester tester, {
      String? target = 'm1',
      bool showMap = true,
    }) async {
      final service = _FakeMapService();
      final registry = MapCameraRegistry();
      addTearDown(registry.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MapCameraScope(
              registry: registry,
              child: Column(
                children: [
                  if (showMap)
                    SizedBox(
                      width: 400,
                      height: 400,
                      child: MapWidget(
                        cameraId: 'm1',
                        mapService: service,
                        pilotPosition: const LatLng(47.5, 13.6),
                      ),
                    ),
                  Row(
                    children: [
                      for (final type in [
                        WidgetType.mapZoomIn,
                        WidgetType.mapZoomOut,
                        WidgetType.mapRecenter,
                      ])
                        SizedBox(
                          width: 56,
                          height: 56,
                          child: MapControlWidget(
                            placementId: 'c_${type.name}',
                            type: type,
                            targetMapId: target,
                          ),
                        ),
                      SizedBox(
                        width: 90,
                        height: 200,
                        child: MapControlWidget(
                          placementId: 'rocker',
                          type: WidgetType.mapZoomRocker,
                          targetMapId: target,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return service;
    }

    testWidgets('external zoom matches built-in zoom behavior', (tester) async {
      final service = await pumpHarness(tester);
      final camera = _cameraFor(
        tester,
        'map_control_zoom_in_c_mapZoomIn',
        'm1',
      )!;
      final start = camera.zoom;

      await tester.tap(
        find.byKey(const Key('map_control_zoom_in_c_mapZoomIn')),
      );
      await tester.pump();
      expect(camera.zoom, start + 0.5);
      // Zoom is eased by the follow loop (one camera write per frame).
      await tester.pump(const Duration(milliseconds: 300));
      expect(service.lastZoom, start + 0.5);
      expect(camera.centerLocked, isTrue, reason: 'zoom keeps glider anchor');

      await tester.tap(find.byKey(const Key('btn_map_zoom_in')));
      await tester.pump();
      expect(camera.zoom, start + 1.0, reason: 'same step as built-in button');

      await tester.tap(find.byKey(const Key('map_control_rocker_out_rocker')));
      await tester.pump();
      expect(camera.zoom, start + 0.5);
      await tester.tap(
        find.byKey(const Key('map_control_zoom_out_c_mapZoomOut')),
      );
      await tester.pump();
      expect(camera.zoom, start);
    });

    testWidgets('external recenter during pan cancels timer and relocks', (
      tester,
    ) async {
      final service = await pumpHarness(tester);
      final camera = _cameraFor(
        tester,
        'map_control_recenter_c_mapRecenter',
        'm1',
      )!;

      await tester.drag(
        find.byKey(const Key('map_gesture_detector')),
        const Offset(80, 40),
      );
      await tester.pump();
      expect(camera.centerLocked, isFalse);
      BezelButton recenter() => tester.widget<BezelButton>(
        find.byKey(const Key('map_control_recenter_c_mapRecenter')),
      );
      expect(recenter().lit, isFalse);

      final animateBefore = service.animateCalls;
      await tester.tap(
        find.byKey(const Key('map_control_recenter_c_mapRecenter')),
      );
      await tester.pump();
      expect(camera.centerLocked, isTrue);
      expect(camera.recenterPending, isFalse);
      // Recenter eases back inside the follow loop, not via animateCamera.
      await tester.pump(const Duration(milliseconds: 700));
      expect(service.animateCalls, animateBefore);
      expect(service.lastMovePosition!.latitude, closeTo(47.5, 1e-9));
      expect(service.lastMovePosition!.longitude, closeTo(13.6, 1e-9));
      expect(recenter().lit, isTrue);
      await tester.pump(const Duration(seconds: 7));
    });

    testWidgets('auto-recenter after inactivity re-lights recenter control', (
      tester,
    ) async {
      await pumpHarness(tester);
      final camera = _cameraFor(
        tester,
        'map_control_recenter_c_mapRecenter',
        'm1',
      )!;
      camera.beginManualPan();
      await tester.pump();
      expect(
        tester
            .widget<BezelButton>(
              find.byKey(const Key('map_control_recenter_c_mapRecenter')),
            )
            .lit,
        isFalse,
      );
      await tester.pump(const Duration(seconds: 7));
      expect(camera.centerLocked, isTrue);
      expect(
        tester
            .widget<BezelButton>(
              find.byKey(const Key('map_control_recenter_c_mapRecenter')),
            )
            .lit,
        isTrue,
      );
    });

    testWidgets('zoom-in control disables at maximum zoom', (tester) async {
      await pumpHarness(tester);
      final camera = _cameraFor(
        tester,
        'map_control_zoom_in_c_mapZoomIn',
        'm1',
      )!;
      camera.zoomBy(100);
      await tester.pump();
      final zoomIn = tester.widget<BezelButton>(
        find.byKey(const Key('map_control_zoom_in_c_mapZoomIn')),
      );
      expect(zoomIn.onPressed, isNull);
      final rockerIn = tester.widget<BezelButton>(
        find.byKey(const Key('map_control_rocker_in_rocker')),
      );
      expect(rockerIn.onPressed, isNull);
      await tester.tap(
        find.byKey(const Key('map_control_zoom_in_c_mapZoomIn')),
      );
      expect(camera.zoom, camera.maxZoom);
    });

    testWidgets('controls without a target are dimmed and inert', (
      tester,
    ) async {
      await pumpHarness(tester, target: null);
      for (final key in [
        'map_control_zoom_in_c_mapZoomIn',
        'map_control_zoom_out_c_mapZoomOut',
        'map_control_recenter_c_mapRecenter',
        'map_control_rocker_in_rocker',
        'map_control_rocker_out_rocker',
      ]) {
        expect(
          tester.widget<BezelButton>(find.byKey(Key(key))).onPressed,
          isNull,
          reason: key,
        );
        await tester.tap(find.byKey(Key(key)), warnIfMissed: false);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('removing the map leaves controls dimmed without errors', (
      tester,
    ) async {
      await pumpHarness(tester);
      expect(
        tester
            .widget<BezelButton>(
              find.byKey(const Key('map_control_zoom_in_c_mapZoomIn')),
            )
            .onPressed,
        isNotNull,
      );
      // Rebuild without the map: camera unregisters on dispose.
      final registry = MapCameraScope.maybeOf(
        tester.element(
          find.byKey(const Key('map_control_zoom_in_c_mapZoomIn')),
        ),
      )!;
      final scope = tester.widget<MapCameraScope>(find.byType(MapCameraScope));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MapCameraScope(
              registry: scope.registry,
              child: const SizedBox(
                width: 56,
                height: 56,
                child: MapControlWidget(
                  placementId: 'c_mapZoomIn',
                  type: WidgetType.mapZoomIn,
                  targetMapId: 'm1',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(registry.lookup('m1'), isNull);
      expect(
        tester
            .widget<BezelButton>(
              find.byKey(const Key('map_control_zoom_in_c_mapZoomIn')),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'rocker orientation follows its shape and shows zoom read-out',
      (tester) async {
        await pumpHarness(tester);
        final inTop = tester.getCenter(
          find.byKey(const Key('map_control_rocker_in_rocker')),
        );
        final outBottom = tester.getCenter(
          find.byKey(const Key('map_control_rocker_out_rocker')),
        );
        expect(
          inTop.dy,
          lessThan(outBottom.dy),
          reason: 'tall rocker: zoom-in on top',
        );
        expect(
          find.byKey(const Key('map_control_rocker_zoom_rocker')),
          findsOneWidget,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 160,
                  height: 60,
                  child: MapControlWidget(
                    placementId: 'wide',
                    type: WidgetType.mapZoomRocker,
                    targetMapId: null,
                  ),
                ),
              ),
            ),
          ),
        );
        final outLeft = tester.getCenter(
          find.byKey(const Key('map_control_rocker_out_wide')),
        );
        final inRight = tester.getCenter(
          find.byKey(const Key('map_control_rocker_in_wide')),
        );
        expect(
          outLeft.dx,
          lessThan(inRight.dx),
          reason: 'wide rocker: zoom-out left',
        );
      },
    );
  });

  group('Map controls on the flight canvas', () {
    Future<void> pumpCanvas(
      WidgetTester tester,
      ScreenManagerService manager, {
      ValueNotifier<CockpitTelemetry>? telemetry,
    }) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LayoutStrategyContainer(
              screenManager: manager,
              telemetry: telemetry ?? ValueNotifier(const CockpitTelemetry()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('explicit target drives only the second map', (tester) async {
      final manager = _manager([
        _p('m1', WidgetType.map, 0, 0, 16, 16),
        _p('m2', WidgetType.map, 0, 16, 16, 16),
        _p('c', WidgetType.mapZoomIn, 0, 12, 3, 3, target: 'm2'),
      ]);
      await pumpCanvas(tester, manager);
      final cam1 = _cameraFor(tester, 'map_control_zoom_in_c', 'm1')!;
      final cam2 = _cameraFor(tester, 'map_control_zoom_in_c', 'm2')!;
      final z1 = cam1.zoom;
      final z2 = cam2.zoom;
      await tester.tap(find.byKey(const Key('map_control_zoom_in_c')));
      await tester.pump();
      expect(cam1.zoom, z1);
      expect(cam2.zoom, z2 + 0.5);
    });

    testWidgets('auto target drives the bottom-most map', (tester) async {
      final manager = _manager([
        _p('m1', WidgetType.map, 0, 0, 16, 32),
        _p('c', WidgetType.mapRecenter, 12, 26, 3, 3),
      ]);
      await pumpCanvas(tester, manager);
      final cam = _cameraFor(tester, 'map_control_recenter_c', 'm1')!;
      cam.beginManualPan();
      await tester.pump();
      await tester.tap(find.byKey(const Key('map_control_recenter_c')));
      await tester.pump();
      expect(cam.centerLocked, isTrue);
    });

    testWidgets(
      'built-in buttons hide on Auto and return when control removed',
      (tester) async {
        final manager = _manager([
          _p('m1', WidgetType.map, 0, 0, 16, 32),
          _p('c', WidgetType.mapRecenter, 12, 26, 3, 3),
        ]);
        await pumpCanvas(tester, manager);
        expect(find.byKey(const Key('btn_map_recenter')), findsNothing);
        expect(find.byKey(const Key('btn_map_zoom_in')), findsNothing);

        manager.removeWidget('c');
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('btn_map_recenter')), findsOneWidget);
        expect(find.byKey(const Key('btn_map_zoom_in')), findsOneWidget);
      },
    );

    testWidgets('Always and Never override built-in visibility', (
      tester,
    ) async {
      final manager = _manager([
        _p(
          'm1',
          WidgetType.map,
          0,
          0,
          16,
          32,
          builtIn: MapBuiltInControls.always,
        ),
        _p('c', WidgetType.mapRecenter, 12, 26, 3, 3),
      ]);
      await pumpCanvas(tester, manager);
      expect(find.byKey(const Key('btn_map_recenter')), findsOneWidget);

      final map = manager.activeScreen.widgets.first;
      manager.updateWidgetPlacement(
        map.copyWith(mapBuiltInControls: MapBuiltInControls.never),
      );
      manager.removeWidget('c');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('btn_map_recenter')), findsNothing);
    });

    testWidgets('telemetry ticks keep the zoom chosen via a control', (
      tester,
    ) async {
      final telemetry = ValueNotifier(
        const CockpitTelemetry(latitude: 47.5, longitude: 13.6),
      );
      final manager = _manager([
        _p('m1', WidgetType.map, 0, 0, 16, 32),
        _p('c', WidgetType.mapZoomOut, 12, 26, 3, 3),
      ]);
      await pumpCanvas(tester, manager, telemetry: telemetry);
      final cam = _cameraFor(tester, 'map_control_zoom_out_c', 'm1')!;
      await tester.tap(find.byKey(const Key('map_control_zoom_out_c')));
      await tester.pump();
      final zoom = cam.zoom;
      for (var i = 0; i < 5; i++) {
        telemetry.value = telemetry.value.copyWith(
          latitude: 47.5 + i * 0.001,
          altitude: 1500.0 + i,
        );
        await tester.pump();
      }
      expect(cam.zoom, zoom);
      expect(cam.centerLocked, isTrue);
      expect(
        manager.activeScreen.widgets.first.mapZoomLevel,
        isNull,
        reason: 'in-flight zoom is not persisted as configured zoom',
      );
    });

    testWidgets('config sheet offers target picker and flags missing map', (
      tester,
    ) async {
      final manager = _manager([
        _p('m1', WidgetType.map, 0, 0, 16, 32),
        _p('c', WidgetType.mapZoomIn, 0, 10, 4, 4, target: 'gone'),
      ]);
      manager.toggleEditMode(true);
      manager.selectWidget('c');
      await pumpCanvas(tester, manager);

      expect(
        tester
            .widget<BezelButton>(find.byKey(const Key('map_control_zoom_in_c')))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const Key('btn_inspector_config')));
      await tester.pumpAndSettle();
      expect(find.text('TARGET MAP'), findsOneWidget);
      expect(find.byKey(const Key('chip_target_missing')), findsOneWidget);
      await tester.tap(find.byKey(const Key('chip_target_auto')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(
        manager.activeScreen.widgets.last.effectiveMapControlTarget,
        kAutoMapTarget,
      );
      manager.toggleEditMode(false);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<BezelButton>(find.byKey(const Key('map_control_zoom_in_c')))
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('map built-in controls setting is configurable', (
      tester,
    ) async {
      final manager = _manager([_p('m1', WidgetType.map, 0, 0, 16, 32)]);
      manager.toggleEditMode(true);
      manager.selectWidget('m1');
      await pumpCanvas(tester, manager);
      await tester.tap(find.byKey(const Key('btn_inspector_config')));
      await tester.pumpAndSettle();
      final chip = find.byKey(const Key('chip_builtin_never'));
      await tester.scrollUntilVisible(
        chip,
        100,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(chip);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(
        manager.activeScreen.widgets.first.effectiveMapBuiltInControls,
        MapBuiltInControls.never,
      );
    });

    testWidgets('picker adds every map control type to the foreground', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(600, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final manager = _manager([_p('m1', WidgetType.map, 0, 0, 16, 32)]);
      for (final type in [
        WidgetType.mapZoomRocker,
        WidgetType.mapZoomIn,
        WidgetType.mapZoomOut,
        WidgetType.mapRecenter,
      ]) {
        // The sheet pops its route after adding; use a fresh app each time.
        await tester.pumpWidget(
          MaterialApp(
            key: UniqueKey(),
            home: Scaffold(body: WidgetPickerSheet(screenManager: manager)),
          ),
        );
        await tester.pumpAndSettle();
        final add = find.byKey(Key('btn_picker_add_${type.name}'));
        await tester.scrollUntilVisible(add, 100);
        await tester.tap(add);
        await tester.pumpAndSettle();
        final added = manager.activeScreen.widgets.last;
        expect(added.type, type);
        expect(added.effectiveMapControlTarget, kAutoMapTarget);
      }
      expect(manager.activeScreen.widgets.first.id, 'm1');
    });
  });
}
