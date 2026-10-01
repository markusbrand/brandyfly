// End-to-end walkthrough of the whole app on a real device or desktop:
//   flutter test integration_test -d linux
//
// For each reference window size it walks: navigation overlay, screen
// switching, placed map controls, edit mode (adding every widget type,
// presets, configuration sheet, corner resize, wide variant), the flights
// logbook and a replay. Any Flutter error fails the test.
import 'dart:io';

import 'package:brandyfly/domain/models/ui_config.dart';
import 'package:brandyfly/main.dart';
import 'package:brandyfly/models/flight_model.dart';
import 'package:brandyfly/services/flight_storage_service.dart';
import 'package:brandyfly/services/screen_manager_service.dart';
import 'package:brandyfly_native/brandyfly_native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:maplibre_platform_interface/maplibre_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/support/headless_maplibre.dart';

class _FakeNative extends BrandyflyNative {
  @override
  Future<String?> getPlatformVersion() async => 'IntegrationOS';

  @override
  Future<void> configureLocalMockFlightMode(MockFlightModeConfig config) async {}
}

const _sizes = {
  'phone portrait': Size(390, 844),
  'phone landscape': Size(844, 390),
  'tablet landscape': Size(1280, 800),
};

FlightModel _sampleFlight() {
  final start = DateTime.utc(2026, 7, 1, 10);
  return FlightModel(
    id: 'it_flight',
    title: 'Integration Glide',
    date: start,
    points: [
      for (var i = 0; i < 120; i++)
        FlightPoint(
          timestamp: start.add(Duration(seconds: i)),
          latitude: 47.52 + i * 0.0002,
          longitude: 13.68 + i * 0.0001,
          altitude: 1800.0 - i * 1.5,
          vario: (i % 30 - 15) / 10,
          speed: 35 + (i % 7).toDouble(),
          heading: (i * 3 % 360).toDouble(),
        ),
    ],
  );
}

/// Pumps frames for [duration] (the simulator streams telemetry at 10 Hz,
/// so pumpAndSettle would never settle).
Future<void> _settle(WidgetTester tester, [int ms = 600]) async {
  for (var t = 0; t < ms; t += 50) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void _debugHit(WidgetTester tester, Finder finder, String key) {
  final center = tester.getCenter(finder);
  final result = tester.hitTestOnBinding(center);
  final target = finder.evaluate().single.renderObject;
  if (result.path.any((e) => e.target == target)) return;
  final top = result.path.first.target;
  debugPrint('HITDEBUG $key at $center blocked by $top '
      'creator=${(top is RenderObject) ? top.debugCreator : null}');
}

/// Pumps until [finder] matches (real devices and software GL emulators can
/// be slower than the fixed settle time).
Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final end = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(end)) {
      fail('Timed out waiting for $finder');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void _noErrors(WidgetTester tester, String step) {
  expect(tester.takeException(), isNull, reason: step);
}

Future<void> _tapKey(WidgetTester tester, String key, {int settleMs = 400}) async {
  final finder = find.byKey(Key(key));
  expect(finder, findsOneWidget, reason: 'missing $key');
  // Desktop shows tooltips on hover; they live in the overlay and can sit on
  // top of neighbouring controls.
  Tooltip.dismissAllToolTips();
  await tester.ensureVisible(finder);
  await _settle(tester, 100);
  _debugHit(tester, finder, key);
  await tester.tap(finder);
  await _settle(tester, settleMs);
  _noErrors(tester, 'after tapping $key');
}

Future<void> _openNav(WidgetTester tester) async {
  await _tapKey(tester, 'top_nav_grab_handle');
}

/// The app provides its screen manager through the root dependency scope.
ScreenManagerService _screenManager(WidgetTester tester) =>
    Provider.of<ScreenManagerService>(
      tester.element(find.byKey(const Key('flight_canvas'))),
      listen: false,
    );

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // A tap that misses its target is a real failure in this walkthrough.
  WidgetController.hitTestWarningShouldBeFatal = true;

  // MapLibre ships no desktop implementation; render an empty map surface on
  // desktop so the rest of the app can be exercised end to end.
  if (Platform.isLinux || Platform.isWindows) {
    MapLibrePlatform.instance = HeadlessMapLibrePlatform();
  }

  for (final entry in _sizes.entries) {
    testWidgets('app walkthrough on ${entry.key}', (tester) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});

      final storage = FlightStorageService();
      await storage.saveFlight(_sampleFlight());

      await tester.pumpWidget(
        BrandyFlyApp(
          config: MockFlightModeConfig(
            enabled: true,
            fixtureVersion: 'mock-flight-v1',
            seed: 7,
            logicalClockStep: const Duration(seconds: 1),
            startTime: DateTime.parse('2026-08-07T00:00:00Z'),
            provenance: 'synthetic-anonymized',
          ),
          native: _FakeNative(),
          storageService: storage,
        ),
      );
      await _settle(tester, 1500);
      _noErrors(tester, 'startup');
      expect(find.byKey(const Key('flight_canvas')), findsOneWidget);
      final manager = _screenManager(tester);

      // The simulation card floats over the top-right of the canvas; collapse
      // it like a pilot would before using controls placed underneath.
      await _tapKey(tester, 'btn_minimize_mock_session');

      // 1. Navigation overlay and screen switching.
      await _openNav(tester);
      await _tapKey(tester, 'nav_chip_map_screen');
      expect(manager.activeScreen.id, 'map_screen');
      expect(manager.isNavBarVisible, isFalse);

      // 2. Placed map controls drive the map (built-in buttons hidden).
      expect(find.byKey(const Key('btn_map_recenter')), findsNothing);
      await _tapKey(tester, 'map_control_rocker_in_wm_zoom');
      await _tapKey(tester, 'map_control_rocker_out_wm_zoom');
      await _tapKey(tester, 'map_control_recenter_wm_recenter');

      // 3. Thermaling screen renders.
      await _openNav(tester);
      await _tapKey(tester, 'nav_chip_thermaling');
      expect(manager.activeScreen.id, 'thermaling');

      // 4. Edit mode on the normal flight screen.
      await _openNav(tester);
      await _tapKey(tester, 'nav_chip_normal_flight');
      await _openNav(tester);
      await _tapKey(tester, 'nav_btn_edit_mode');
      expect(manager.isEditMode, isTrue);

      for (final type in WidgetType.values) {
        final before = manager.activeScreen.widgets.length;
        debugPrint('walkthrough(${entry.key}): add ${type.name}');
        await _tapKey(tester, 'btn_add_widget');
        await _waitFor(tester, find.byType(BottomSheet));
        final add = find.byKey(Key('btn_picker_add_${type.name}'));
        await tester.ensureVisible(add);
        await _settle(tester, 200);
        await tester.tap(add);
        await _settle(tester);
        _noErrors(tester, 'add ${type.name}');
        expect(manager.activeScreen.widgets.length, before + 1, reason: type.name);
        final added = manager.selectedWidgetId;
        expect(added, isNotNull, reason: 'new ${type.name} is selected');

        // Preset (size tab exists only on narrow inspectors).
        final sizeTab = find.byKey(const Key('inspector_tab_size'));
        if (sizeTab.evaluate().isNotEmpty) {
          await tester.tap(sizeTab);
          await _settle(tester, 200);
        }
        await _tapKey(tester, 'btn_inspector_preset_m');

        // Configuration sheet opens and applies.
        await _tapKey(tester, 'btn_inspector_config');
        expect(find.text('Apply'), findsOneWidget);
        await tester.tap(find.text('Apply'));
        await _settle(tester);
        _noErrors(tester, 'configure ${type.name}');

        // Remove again to keep the layout uncluttered (except one control).
        if (type != WidgetType.mapZoomRocker) {
          await _tapKey(tester, 'btn_inspector_delete');
          expect(manager.activeScreen.widgets.length, before);
        }
      }

      // Corner resize of the selected altitude widget.
      manager.selectWidget('w1');
      await _settle(tester, 300);
      final before = manager.activeScreen.widgets.firstWhere((w) => w.id == 'w1');
      await tester.drag(
        find.byKey(const Key('resize_handle_w1')),
        const Offset(60, 60),
      );
      await _settle(tester);
      _noErrors(tester, 'corner resize');
      final after = manager.activeScreen.widgets.firstWhere((w) => w.id == 'w1');
      expect(after.w >= before.w && after.h >= before.h, isTrue);

      // Wide variant: create from tall, then back to tall.
      await _tapKey(tester, 'btn_variant_wide');
      await _tapKey(tester, 'btn_copy_from_tall');
      expect(manager.activeScreen.hasWideVariant, isTrue);
      await _tapKey(tester, 'btn_variant_delete_wide');
      expect(manager.activeScreen.hasWideVariant, isFalse);

      await _tapKey(tester, 'btn_done_editing');
      expect(manager.isEditMode, isFalse);

      // 5. Flights logbook and replay.
      await _openNav(tester);
      await _tapKey(tester, 'nav_btn_flights');
      expect(find.text('Integration Glide'), findsWidgets);
      final replayButton = find.text('Replay Flight').first;
      await tester.ensureVisible(replayButton);
      await _settle(tester, 200);
      await tester.tap(replayButton);
      await _settle(tester, 2500);
      _noErrors(tester, 'replay running');
      expect(manager.isReplayActive, isTrue);
      expect(find.byKey(const Key('flight_canvas')), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close).last);
      await _settle(tester);
      expect(manager.isReplayActive, isFalse);
      _noErrors(tester, 'replay exit');

      // Unmount cleanly.
      await tester.pumpWidget(const SizedBox());
      await _settle(tester, 300);
      _noErrors(tester, 'teardown');
    });
  }
}
