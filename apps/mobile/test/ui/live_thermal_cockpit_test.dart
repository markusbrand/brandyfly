import 'package:brandyfly/domain/models/cockpit_telemetry.dart';
import 'package:brandyfly/domain/models/size_tier.dart';
import 'package:brandyfly/domain/models/ui_config.dart';
import 'package:brandyfly/domain/thermal_assistant/thermal_assistant_engine.dart';
import 'package:brandyfly/ui/features/flight_canvas/views/widget_slot.dart';
import 'package:brandyfly/ui/features/instruments/views/thermal_map_widget.dart';
import 'package:brandyfly/ui/features/instruments/views/wind_direction_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Canvas that records draw calls so tests can assert what was painted.
class _RecordingCanvas implements Canvas {
  int circles = 0;

  @override
  void drawCircle(Offset c, double radius, Paint paint) => circles++;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Circles painted by the thermal map painter (4 are static range rings).
int _paintedCircles(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.byKey(const Key('canvas_thermal_map')),
  );
  final canvas = _RecordingCanvas();
  paint.painter!.paint(canvas, const Size(400, 400));
  return canvas.circles;
}

const int _rangeRings = 4;

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(
    body: Center(child: SizedBox(width: 400, height: 400, child: child)),
  ),
);

List<ThermalPoint> _ring(DateTime now) => [
  for (var i = 0; i < 12; i++)
    ThermalPoint(
      dx: 40.0 * (i.isEven ? 1 : -1),
      dy: 3.0 * i,
      climbRateMs: i.isEven ? 2.5 : -1.0,
      timestamp: now.subtract(Duration(seconds: 12 - i)),
    ),
];

void main() {
  group('ThermalMapWidget live data', () {
    testWidgets('renders actual track points and core while circling', (
      tester,
    ) async {
      final now = DateTime.utc(2026, 7, 1, 12);
      await tester.pumpWidget(
        _host(
          ThermalMapWidget(
            style: ThermalMapStyle.burnairCore,
            trackPoints: _ring(now),
            coreOffset: const Offset(20, -10),
            referenceTime: now,
            windDirDeg: 270,
            windSpeedKmh: 18,
          ),
        ),
      );
      // 12 bubbles + core (pulse ring, disc, inner dot) + range rings.
      expect(_paintedCircles(tester), greaterThanOrEqualTo(_rangeRings + 12));
      expect(find.byKey(const Key('thermal_map_preview_label')), findsNothing);
    });

    testWidgets('gliding with no circling data renders no bubbles or demo', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const ThermalMapWidget(
            style: ThermalMapStyle.burnairCore,
            trackPoints: [],
          ),
        ),
      );
      expect(_paintedCircles(tester), _rangeRings);
      expect(find.byKey(const Key('thermal_map_preview_label')), findsNothing);
    });

    testWidgets('preview renders a labelled demo track', (tester) async {
      await tester.pumpWidget(_host(const ThermalMapWidget(preview: true)));
      expect(_paintedCircles(tester), greaterThan(_rangeRings + 10));
      expect(
        find.byKey(const Key('thermal_map_preview_label')),
        findsOneWidget,
      );
      expect(find.text('PREVIEW'), findsOneWidget);
    });
  });

  group('FlightWidgetContent thermal map wiring', () {
    const model = WidgetPlacementModel(
      id: 'tm',
      type: WidgetType.thermalMap,
      x: 0,
      y: 0,
      w: 8,
      h: 8,
    );

    Future<ThermalMapWidget> pumpWith(
      WidgetTester tester,
      CockpitTelemetry t,
    ) async {
      await tester.pumpWidget(
        _host(
          FlightWidgetContent(
            model: model,
            telemetry: ValueNotifier(t),
            tier: SizeTier.regular,
          ),
        ),
      );
      return tester.widget<ThermalMapWidget>(find.byType(ThermalMapWidget));
    }

    testWidgets('orients by track heading, not wind direction', (tester) async {
      final w = await pumpWith(
        tester,
        const CockpitTelemetry(
          heading: 95,
          windDir: 270,
          windSpeed: 15,
          latitude: 47,
          longitude: 13,
          hasSource: true,
        ),
      );
      expect(w.headingDeg, 95);
      expect(w.windDirDeg, 270);
      expect(w.preview, isFalse);
    });

    testWidgets('projects engine track relative to the pilot', (tester) async {
      final t0 = DateTime.utc(2026, 7, 1, 12);
      final state = ThermalAssistantState(
        mode: const FlightModeState.circling(TurnDirection.right),
        timestamp: t0,
        core: const GeoPosition(47.0009, 13.0),
        track: [
          ThermalTrackSample(
            timestamp: t0.subtract(const Duration(seconds: 2)),
            position: const GeoPosition(47.0, 13.001),
            climbRateMs: 2,
          ),
        ],
        revision: 1,
      );
      final w = await pumpWith(
        tester,
        CockpitTelemetry(
          heading: 10,
          latitude: 47,
          longitude: 13,
          hasSource: true,
          thermal: state,
        ),
      );
      expect(w.trackPoints, hasLength(1));
      expect(w.trackPoints!.first.dx, closeTo(75.8, 1)); // ~76 m east
      expect(w.trackPoints!.first.dy, closeTo(0, 0.5));
      expect(w.coreOffset!.dy, closeTo(-100, 1)); // 100 m north (canvas up)
      expect(w.referenceTime, t0);
    });

    testWidgets('no source -> preview', (tester) async {
      final w = await pumpWith(tester, const CockpitTelemetry());
      expect(w.preview, isTrue);
    });
  });

  group('WindDirectionWidget honest wind', () {
    for (final style in WindWidgetStyle.values) {
      testWidgets('no estimate (${style.name})', (tester) async {
        await tester.pumpWidget(
          _host(
            WindDirectionWidget(
              directionDegrees: null,
              speedKmH: null,
              style: style,
            ),
          ),
        );
        expect(find.byKey(const Key('wind_no_estimate')), findsOneWidget);
        expect(find.text('NO ESTIMATE'), findsOneWidget);
        expect(find.byKey(const Key('wind_stale_badge')), findsNothing);
      });

      testWidgets('valid estimate (${style.name})', (tester) async {
        await tester.pumpWidget(
          _host(
            WindDirectionWidget(
              directionDegrees: 270,
              speedKmH: 18,
              style: style,
            ),
          ),
        );
        expect(find.byKey(const Key('wind_no_estimate')), findsNothing);
        expect(find.byKey(const Key('wind_stale_badge')), findsNothing);
        expect(find.textContaining('18'), findsWidgets);
      });

      testWidgets('stale estimate (${style.name})', (tester) async {
        await tester.pumpWidget(
          _host(
            WindDirectionWidget(
              directionDegrees: 270,
              speedKmH: 18,
              isStale: true,
              style: style,
            ),
          ),
        );
        expect(find.byKey(const Key('wind_stale_badge')), findsOneWidget);
        expect(find.byType(ColorFiltered), findsOneWidget);
      });
    }

    testWidgets('tiny tier no estimate shows dashes', (tester) async {
      await tester.pumpWidget(
        _host(
          const WindDirectionWidget(
            directionDegrees: null,
            speedKmH: null,
            style: WindWidgetStyle.relativeArrow,
            tier: SizeTier.tiny,
          ),
        ),
      );
      expect(find.text('--'), findsOneWidget);
    });

    testWidgets('slot passes stale flag and null wind through', (tester) async {
      const model = WidgetPlacementModel(
        id: 'w',
        type: WidgetType.windDirection,
        x: 0,
        y: 0,
        w: 4,
        h: 2,
      );
      final notifier = ValueNotifier(const CockpitTelemetry(hasSource: true));
      await tester.pumpWidget(
        _host(
          FlightWidgetContent(
            model: model,
            telemetry: notifier,
            tier: SizeTier.regular,
          ),
        ),
      );
      expect(find.byKey(const Key('wind_no_estimate')), findsOneWidget);
      notifier.value = const CockpitTelemetry(
        windDir: 250,
        windSpeed: 12,
        windStale: true,
        hasSource: true,
      );
      await tester.pump();
      expect(find.byKey(const Key('wind_stale_badge')), findsOneWidget);
    });
  });
}
