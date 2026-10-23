import 'package:brandyfly/models/flight_model.dart';
import 'package:brandyfly/services/flight_tracking_service.dart';
import 'package:brandyfly/services/screen_manager_service.dart';
import 'package:brandyfly/widgets/flight/recording_status_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RecordingStatusOverlay Tests', () {
    late ScreenManagerService screenManager;
    late FlightTrackingService trackingService;

    setUp(() {
      screenManager = ScreenManagerService();
      trackingService = FlightTrackingService();
    });

    Widget buildTestHarness({
      Size screenSize = const Size(800, 600),
      EdgeInsets padding = EdgeInsets.zero,
    }) {
      return MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: screenSize, padding: padding),
          child: Scaffold(
            body: Stack(
              children: [
                RecordingStatusOverlay(
                  platformVersion: 'Linux Test 1.0',
                  screenManager: screenManager,
                  trackingService: trackingService,
                ),
              ],
            ),
          ),
        ),
      );
    }

    testWidgets('renders standby state and toggles manual recording', (tester) async {
      await tester.pumpWidget(buildTestHarness());
      await tester.pumpAndSettle();

      expect(find.text('BrandyFly'), findsOneWidget);
      expect(find.text('LIVE'), findsOneWidget);
      expect(find.text('STANDBY'), findsOneWidget);
      expect(find.textContaining('Running on: Linux Test 1.0'), findsOneWidget);

      final toggleFinder = find.byKey(const Key('btn_manual_record_toggle'));
      expect(toggleFinder, findsOneWidget);
      expect(find.text('REC'), findsOneWidget);

      // Tap manual REC to start recording
      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();

      expect(trackingService.state, FlightState.flying);
      expect(find.textContaining('REC 00:00'), findsOneWidget);
      expect(find.text('STOP'), findsOneWidget);

      // Add a track point 65 seconds later
      final now = DateTime.now();
      trackingService.processPoint(
        FlightPoint(
          timestamp: now,
          latitude: 47.0,
          longitude: 13.0,
          altitude: 1000,
          speed: 35,
          vario: 1.0,
        ),
      );
      trackingService.processPoint(
        FlightPoint(
          timestamp: now.add(const Duration(seconds: 65)),
          latitude: 47.01,
          longitude: 13.01,
          altitude: 1050,
          speed: 36,
          vario: 0.5,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('REC 01:05'), findsOneWidget);

      // Tap manual STOP
      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();

      expect(trackingService.state, FlightState.landed);
      expect(find.text('LANDED'), findsOneWidget);
    });

    testWidgets('collapses and expands platform metadata details', (tester) async {
      await tester.pumpWidget(buildTestHarness());
      await tester.pumpAndSettle();

      expect(find.textContaining('Running on: Linux Test 1.0'), findsOneWidget);
      final collapseBtn = find.byKey(const Key('btn_recording_overlay_collapse'));
      expect(collapseBtn, findsOneWidget);

      // Collapse
      await tester.tap(collapseBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('Running on: Linux Test 1.0'), findsNothing);
      final expandBtn = find.byKey(const Key('btn_recording_overlay_expand'));
      expect(expandBtn, findsOneWidget);

      // Expand
      await tester.tap(expandBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('Running on: Linux Test 1.0'), findsOneWidget);
    });

    testWidgets('supports 2D drag repositioning and safe-area clamping', (tester) async {
      await tester.pumpWidget(
        buildTestHarness(
          screenSize: const Size(600, 800),
          padding: const EdgeInsets.only(top: 24, bottom: 24),
        ),
      );
      await tester.pumpAndSettle();

      final cardFinder = find.byKey(const Key('recording_status_overlay_card'));
      expect(cardFinder, findsOneWidget);

      final initialTopLeft = tester.getTopLeft(cardFinder);

      // Drag downwards and leftwards
      await tester.drag(cardFinder, const Offset(-150, 200));
      await tester.pumpAndSettle();

      final draggedTopLeft = tester.getTopLeft(cardFinder);
      expect(draggedTopLeft.dx, lessThan(initialTopLeft.dx));
      expect(draggedTopLeft.dy, greaterThan(initialTopLeft.dy));

      // Drag completely beyond the top edge to verify safe-area clamping
      await tester.drag(cardFinder, const Offset(0, -600));
      await tester.pumpAndSettle();

      final clampedTopLeft = tester.getTopLeft(cardFinder);
      // Safe area top is 24 + margin 8 = 32
      expect(clampedTopLeft.dy, greaterThanOrEqualTo(32.0));
    });
  });
}
