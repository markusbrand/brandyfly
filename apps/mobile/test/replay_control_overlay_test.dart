import 'package:brandyfly/models/flight_model.dart';
import 'package:brandyfly/services/flight_replay_service.dart';
import 'package:brandyfly/widgets/flight/replay_control_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  FlightModel createSampleFlight() {
    return FlightModel(
      id: 'replay_floating_test',
      title: 'Floating Overlay Test Flight',
      date: DateTime.utc(2026, 9, 13, 14, 0, 0),
      points: [
        FlightPoint(
          timestamp: DateTime.utc(2026, 9, 13, 14, 0, 0),
          latitude: 47.5,
          longitude: 13.5,
          altitude: 1200.0,
        ),
        FlightPoint(
          timestamp: DateTime.utc(2026, 9, 13, 14, 0, 20),
          latitude: 47.51,
          longitude: 13.51,
          altitude: 1250.0,
        ),
        FlightPoint(
          timestamp: DateTime.utc(2026, 9, 13, 14, 0, 40),
          latitude: 47.52,
          longitude: 13.52,
          altitude: 1300.0,
        ),
      ],
      statistics: const FlightStatistics(
        duration: Duration(seconds: 40),
        maxAltitude: 1300.0,
        minAltitude: 1200.0,
        maxClimbRate: 4.0,
        maxSinkRate: -1.2,
        totalDistanceKm: 2.5,
        averageSpeedKmh: 38.0,
        averageGlideRatio: 8.5,
      ),
    );
  }

  group('Floating ReplayControlOverlay Tests', () {
    testWidgets('renders at default bottom location initially', (tester) async {
      final flight = createSampleFlight();
      final replayService = FlightReplayService(flight: flight);
      addTearDown(replayService.dispose);

      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Positioned.fill(
                  child: ReplayControlOverlay(
                    replayService: replayService,
                    onExit: () {},
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cardFinder = find.byKey(const Key('replay_control_overlay_card'));
      expect(cardFinder, findsOneWidget);

      final initialTopLeft = tester.getTopLeft(cardFinder);
      // In 400x800, card should be near the bottom (top > 600)
      expect(initialTopLeft.dy, greaterThan(600));
      // Horizontally centered or padded within bounds
      expect(initialTopLeft.dx, greaterThanOrEqualTo(8));
    });

    testWidgets('allows free-floating dragging across screen', (tester) async {
      final flight = createSampleFlight();
      final replayService = FlightReplayService(flight: flight);
      addTearDown(replayService.dispose);

      await tester.binding.setSurfaceSize(const Size(600, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Positioned.fill(
                  child: ReplayControlOverlay(
                    replayService: replayService,
                    onExit: () {},
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cardFinder = find.byKey(const Key('replay_control_overlay_card'));
      final initialRect = tester.getRect(cardFinder);

      // Drag up and to the right
      await tester.timedDrag(
        cardFinder,
        const Offset(30, -300),
        const Duration(milliseconds: 300),
      );
      await tester.pumpAndSettle();

      final movedRect = tester.getRect(cardFinder);
      expect(movedRect.top, lessThan(initialRect.top - 200));
      expect(movedRect.left, greaterThan(initialRect.left + 15));
    });

    testWidgets('clamps to screen viewport and safe area margins', (tester) async {
      final flight = createSampleFlight();
      final replayService = FlightReplayService(flight: flight);
      addTearDown(replayService.dispose);

      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Positioned.fill(
                  child: ReplayControlOverlay(
                    replayService: replayService,
                    onExit: () {},
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cardFinder = find.byKey(const Key('replay_control_overlay_card'));

      // Drag far beyond top-left screen edge
      await tester.timedDrag(
        cardFinder,
        const Offset(-1000, -2000),
        const Duration(milliseconds: 300),
      );
      await tester.pumpAndSettle();

      var clampedPos = tester.getTopLeft(cardFinder);
      expect(clampedPos.dx, greaterThanOrEqualTo(8.0));
      expect(clampedPos.dy, greaterThanOrEqualTo(8.0));

      // Drag far beyond bottom-right screen edge
      await tester.timedDrag(
        cardFinder,
        const Offset(2000, 2000),
        const Duration(milliseconds: 300),
      );
      await tester.pumpAndSettle();

      final cardBottomRight = tester.getBottomRight(cardFinder);
      expect(cardBottomRight.dx, lessThanOrEqualTo(400.0));
      expect(cardBottomRight.dy, lessThanOrEqualTo(800.0));
    });

    testWidgets('preserves child control touch interactions without initiating drag', (tester) async {
      final flight = createSampleFlight();
      final replayService = FlightReplayService(flight: flight);
      addTearDown(replayService.dispose);
      bool exitPressed = false;

      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Positioned.fill(
                  child: ReplayControlOverlay(
                    replayService: replayService,
                    onExit: () => exitPressed = true,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cardFinder = find.byKey(const Key('replay_control_overlay_card'));
      final posBeforeInteractions = tester.getTopLeft(cardFinder);

      // Play / Pause toggle
      final playBtn = find.byIcon(Icons.play_arrow);
      expect(playBtn, findsOneWidget);
      await tester.tap(playBtn);
      await tester.pump();
      expect(replayService.isPlaying, isTrue);

      // Pause so timer doesn't remain pending after test
      replayService.pause();
      await tester.pump();

      // Speed cycle button
      final speedBtn = find.text('1x');
      expect(speedBtn, findsOneWidget);
      await tester.tap(speedBtn);
      await tester.pump();
      expect(replayService.speedMultiplier, 2);

      // Seek via slider
      final sliderFinder = find.byType(Slider);
      expect(sliderFinder, findsOneWidget);
      await tester.tap(sliderFinder);
      await tester.pump();

      // Card position should not have changed due to button taps / slider interaction
      final posAfterInteractions = tester.getTopLeft(cardFinder);
      expect(posAfterInteractions.dx, equals(posBeforeInteractions.dx));
      expect(posAfterInteractions.dy, equals(posBeforeInteractions.dy));

      // Close button
      final closeBtn = find.byKey(const Key('btn_replay_close'));
      expect(closeBtn, findsOneWidget);
      await tester.tap(closeBtn);
      expect(exitPressed, isTrue);
    });

    testWidgets('ephemeral session lifetime resets to default bottom position on remount', (tester) async {
      final flight = createSampleFlight();
      final replayService = FlightReplayService(flight: flight);
      addTearDown(replayService.dispose);

      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      bool isReplayActive = true;

      Widget buildApp() {
        return StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              home: Scaffold(
                body: Stack(
                  children: [
                    if (isReplayActive)
                      Positioned.fill(
                        child: ReplayControlOverlay(
                          replayService: replayService,
                          onExit: () {},
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      }

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      final cardFinder = find.byKey(const Key('replay_control_overlay_card'));
      final defaultPos = tester.getTopLeft(cardFinder);

      // Drag overlay up by 250px via timedDrag
      await tester.timedDrag(
        cardFinder,
        const Offset(0, -250),
        const Duration(milliseconds: 300),
      );
      await tester.pumpAndSettle();

      final movedPos = tester.getTopLeft(cardFinder);
      expect(movedPos.dy, lessThan(defaultPos.dy - 100));

      // Simulate exiting replay (unmounting)
      isReplayActive = false;
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('replay_control_overlay_card')), findsNothing);

      // Simulate entering replay again (mounting new session)
      isReplayActive = true;
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      final remountedFinder = find.byKey(const Key('replay_control_overlay_card'));
      expect(remountedFinder, findsOneWidget);
      final remountedPos = tester.getTopLeft(remountedFinder);

      // Position must have reset to the default location, NOT the dragged location
      expect(remountedPos.dy, equals(defaultPos.dy));
      expect(remountedPos.dx, equals(defaultPos.dx));
    });
  });
}
