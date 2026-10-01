import 'package:brandyfly/domain/models/cockpit_telemetry.dart';
import 'package:brandyfly/domain/models/ui_config.dart';
import 'package:brandyfly/services/screen_manager_service.dart';
import 'package:brandyfly/ui/core/rebuild_probe.dart';
import 'package:brandyfly/ui/core/value_selector.dart';
import 'package:brandyfly/ui/features/flight_canvas/views/layout_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

WidgetPlacementModel _p(String id, WidgetType type, int x, int y, int w, int h) =>
    WidgetPlacementModel(id: id, type: type, x: x, y: y, w: w, h: h);

/// Ten widgets covering every telemetry-driven instrument type.
final _tenWidgets = [
  _p('map', WidgetType.map, 0, 0, 16, 32),
  _p('alt', WidgetType.altitude, 0, 0, 4, 4),
  _p('spd', WidgetType.speed, 4, 0, 4, 4),
  _p('glide', WidgetType.glide, 8, 0, 4, 4),
  _p('hag', WidgetType.hag, 12, 0, 4, 4),
  _p('wind', WidgetType.windDirection, 0, 4, 5, 5),
  _p('vario', WidgetType.varioBar, 0, 10, 3, 16),
  _p('chart', WidgetType.altitudeChart, 4, 10, 8, 4),
  _p('thermal', WidgetType.thermalMap, 4, 16, 8, 8),
  _p('rocker', WidgetType.mapZoomRocker, 13, 20, 3, 6),
];

const _instrumentIds = [
  'alt',
  'spd',
  'glide',
  'hag',
  'wind',
  'vario',
  'chart',
  'thermal',
  'map',
];

Future<(ScreenManagerService, ValueNotifier<CockpitTelemetry>)> _pump(
  WidgetTester tester,
) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final manager = ScreenManagerService(
    initialConfig: UIConfig(
      activeScreenId: 's',
      screens: [FlightScreenModel(id: 's', name: 'S', widgets: _tenWidgets)],
    ),
  );
  final telemetry = ValueNotifier(const CockpitTelemetry());
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: LayoutStrategyContainer(
          screenManager: manager,
          telemetry: telemetry,
        ),
      ),
    ),
  );
  // The thermal map pulses continuously, so settle with fixed pumps.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  return (manager, telemetry);
}

void main() {
  setUp(() {
    RebuildProbe.enabled = true;
    RebuildProbe.reset();
  });
  tearDown(() {
    RebuildProbe.enabled = false;
    RebuildProbe.reset();
  });

  group('ValueSelector', () {
    testWidgets('rebuilds only when the selected value changes', (tester) async {
      final source = ValueNotifier(const CockpitTelemetry());
      var builds = 0;
      await tester.pumpWidget(
        ValueSelector<CockpitTelemetry, int>(
          listenable: source,
          select: (t) => t.altitude.round(),
          builder: (context, v) {
            builds++;
            return Text('$v', textDirection: TextDirection.ltr);
          },
        ),
      );
      expect(builds, 1);
      source.value = source.value.copyWith(speed: 99); // unrelated field
      await tester.pump();
      expect(builds, 1);
      source.value = source.value.copyWith(altitude: 1450.2); // same rounded
      await tester.pump();
      expect(builds, 1);
      source.value = source.value.copyWith(altitude: 1460);
      await tester.pump();
      expect(builds, 2);
      expect(find.text('1460'), findsOneWidget);
    });
  });

  group('Rebuild budget', () {
    testWidgets('altitude-only change rebuilds only altitude consumers', (
      tester,
    ) async {
      final (_, telemetry) = await _pump(tester);
      RebuildProbe.reset();

      telemetry.value = telemetry.value.copyWith(altitude: 1600);
      await tester.pump();

      expect(RebuildProbe.count('canvas'), 0);
      expect(RebuildProbe.count('instrument:alt'), 1);
      for (final id in ['spd', 'glide', 'hag', 'wind', 'vario', 'chart']) {
        expect(RebuildProbe.count('instrument:$id'), 0, reason: id);
      }
      // Map legend and thermal map display altitude and may rebuild once.
      expect(RebuildProbe.count('instrument:map'), lessThanOrEqualTo(1));
      expect(RebuildProbe.count('instrument:thermal'), lessThanOrEqualTo(1));
    });

    testWidgets('100 full updates on 10 widgets stay within budget', (
      tester,
    ) async {
      final (_, telemetry) = await _pump(tester);
      final initialCanvasBuilds = RebuildProbe.count('canvas');
      expect(initialCanvasBuilds, greaterThanOrEqualTo(1));
      final initial = {
        for (final id in _instrumentIds) id: RebuildProbe.count('instrument:$id'),
      };

      for (var i = 1; i <= 100; i++) {
        telemetry.value = CockpitTelemetry(
          altitude: 1450.0 + i * 3,
          speed: 40.0 + i,
          glide: 8.0 + i / 5,
          hag: 300.0 + i * 3,
          climb: (i % 20 - 10) / 2,
          windDir: (180.0 + i * 5) % 360,
          windSpeed: 10.0 + i / 2,
          latitude: 47.5 + i * 0.0001,
          longitude: 13.6,
          history: [for (var k = 0; k < 5; k++) 1450.0 + i + k],
        );
        await tester.pump();
      }

      expect(
        RebuildProbe.count('canvas'),
        initialCanvasBuilds,
        reason: 'layout canvas must not rebuild on telemetry',
      );
      for (final id in _instrumentIds) {
        final builds = RebuildProbe.count('instrument:$id') - initial[id]!;
        expect(builds, lessThanOrEqualTo(101), reason: id);
        expect(builds, greaterThan(0), reason: '$id must update');
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('edit chrome does not rebuild on telemetry', (tester) async {
      final (manager, telemetry) = await _pump(tester);
      manager.toggleEditMode(true);
      manager.selectWidget('alt');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      RebuildProbe.reset();

      for (var i = 1; i <= 50; i++) {
        telemetry.value = telemetry.value.copyWith(
          altitude: 1450.0 + i * 5,
          climb: i / 10,
        );
        await tester.pump();
      }

      expect(RebuildProbe.count('inspector'), 0);
      expect(RebuildProbe.count('canvas'), 0);
      expect(RebuildProbe.count('instrument:alt'), 50);
      expect(RebuildProbe.count('instrument:spd'), 0);
    });

    testWidgets('a full telemetry tick with 10 widgets stays under a frame budget', (
      tester,
    ) async {
      final (_, telemetry) = await _pump(tester);
      final stopwatch = Stopwatch()..start();
      for (var i = 0; i < 100; i++) {
        telemetry.value = telemetry.value.copyWith(
          altitude: 1450.0 + i,
          speed: 40.0 + i / 10,
          climb: i / 50,
        );
        await tester.pump();
      }
      stopwatch.stop();
      // Generous bound for CI: average per tick (build + layout + paint in
      // the test binding) well below one 16 ms frame.
      expect(stopwatch.elapsedMilliseconds / 100, lessThan(16));
    });
  });
}
