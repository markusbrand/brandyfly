import 'package:brandyfly/models/flight_model.dart';
import 'package:brandyfly/widgets/flight/map_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

List<Polyline> _allPolylines(WidgetTester tester) {
  final layers = tester.widgetList<PolylineLayer>(find.byType(PolylineLayer));
  return layers.expand((l) => l.polylines).toList();
}

void main() {
  group('getVarioTrackColor piecewise gradient', () {
    test('severe sink (<= -3.0 m/s) maps to deep dark red', () {
      expect(MapWidget.getVarioTrackColor(-3.0), const Color(0xFF991B1B));
      expect(MapWidget.getVarioTrackColor(-5.0), const Color(0xFF991B1B));
    });

    test('medium-to-severe sink interpolates between dark red and medium red', () {
      // Exactly halfway between -3.0 and -1.5 => equidistant from both colors.
      final half = MapWidget.getVarioTrackColor(-2.25);
      final mid = Color.lerp(
        const Color(0xFF991B1B),
        const Color(0xFFEF4444),
        0.5,
      )!;
      expect(half, mid);
    });

    test('light sink (-1.5 to -0.5 m/s) interpolates toward pale red', () {
      final half = MapWidget.getVarioTrackColor(-1.0);
      final mid = Color.lerp(
        const Color(0xFFEF4444),
        const Color(0xFFFCA5A5),
        0.5,
      )!;
      expect(half, mid);
    });

    test('neutral glide (-0.5 to +0.5 m/s) maps to slate grey', () {
      expect(MapWidget.getVarioTrackColor(-0.5), const Color(0xFF94A3B8));
      expect(MapWidget.getVarioTrackColor(0.0), const Color(0xFF94A3B8));
      expect(MapWidget.getVarioTrackColor(0.5), const Color(0xFF94A3B8));
    });

    test('weak lift (0.5 to 1.5 m/s) interpolates from pale green to vibrant green', () {
      final half = MapWidget.getVarioTrackColor(1.0);
      final mid = Color.lerp(
        const Color(0xFF86EFAC),
        const Color(0xFF22C55E),
        0.5,
      )!;
      expect(half, mid);
    });

    test('usable lift (1.5 to 3.5 m/s) interpolates to dark emerald', () {
      final half = MapWidget.getVarioTrackColor(2.5);
      final mid = Color.lerp(
        const Color(0xFF22C55E),
        const Color(0xFF15803D),
        0.5,
      )!;
      expect(half, mid);
    });

    test('strong lift (>= 3.5 m/s) maps to dark emerald green', () {
      expect(MapWidget.getVarioTrackColor(3.5), const Color(0xFF15803D));
      expect(MapWidget.getVarioTrackColor(4.5), const Color(0xFF15803D));
    });

    test('edge values clamp without error', () {
      expect(MapWidget.getVarioTrackColor(-3.0), isNotNull);
      expect(MapWidget.getVarioTrackColor(-0.5), isNotNull);
      expect(MapWidget.getVarioTrackColor(0.5), isNotNull);
      expect(MapWidget.getVarioTrackColor(3.5), isNotNull);
    });
  });

  group('_buildGradientPolylines time window & batching', () {
    (DateTime, FlightPoint, List<FlightPoint>) buildWindow(double windowMinutes) {
      final now = DateTime.now();
      final points = <FlightPoint>[];
      for (var i = 0; i < 30; i++) {
        points.add(
          FlightPoint(
            timestamp: now.subtract(Duration(minutes: 30 - i)),
            latitude: 47.0 + (i * 0.001),
            longitude: 13.0 + (i * 0.001),
            altitude: 1500.0 + (i * 10),
            vario: 2.0,
          ),
        );
      }
      return (DateTime.now(), points.first, points);
    }

    testWidgets('history window filters points older than the configured window', (tester) async {
      final (_, _, points) =
          buildWindow(10.0);
      final now = DateTime.now();

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

      // Older tail should be rendered as one faint polyline (>= 2 old points).
      final faint = _allPolylines(tester).where((p) => p.strokeWidth == 1.4).toList();
      expect(faint, isNotEmpty);
      expect(now, isNotNull);
    });

    testWidgets('full-flight mode (0 minutes) renders all points in one gradient', (tester) async {
      final (_, _, points) = buildWindow(0.0);

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

      final polylines = _allPolylines(tester);
      final gradientLines =
          polylines.where((p) => p.strokeWidth == 3.5).toList();
      expect(gradientLines, isNotEmpty);
    });

    testWidgets('vario variation produces batched multi-point polylines', (tester) async {
      // Alternate lift and sink to force multiple color batches.
      final now = DateTime.now();
      final points = <FlightPoint>[];
      for (var i = 0; i < 40; i++) {
        points.add(
          FlightPoint(
            timestamp: now.add(Duration(seconds: i)),
            latitude: 47.0 + (i * 0.001),
            longitude: 13.0 + (i * 0.001),
            altitude: 1500.0 + (i * 10),
            vario: (i % 2 == 0) ? 2.5 : -2.5,
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

      final polylines = _allPolylines(tester);
      final gradientCount =
          polylines.where((p) => p.strokeWidth == 3.5).length;
      expect(gradientCount, greaterThan(1));
    });
  });
}