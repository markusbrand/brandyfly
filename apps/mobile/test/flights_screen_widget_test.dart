import 'package:brandyfly/models/flight_model.dart';
import 'package:brandyfly/models/flight_settings.dart';
import 'package:brandyfly/services/flight_replay_service.dart';
import 'package:brandyfly/services/flight_storage_service.dart';
import 'package:brandyfly/services/xcontest_upload_service.dart';
import 'package:brandyfly/widgets/flight/flight_summary_sheet.dart';
import 'package:brandyfly/widgets/flight/flights_screen.dart';
import 'package:brandyfly/widgets/flight/replay_control_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('FlightsScreen & Flight UI Widget Tests', () {
    late FlightStorageService storage;
    late XContestUploadService uploadService;
    late FlightModel sampleFlight;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storage = FlightStorageService(preferences: prefs);

      final samplePoints = List.generate(
        10,
        (i) => FlightPoint(
          timestamp: DateTime.utc(2026, 8, 20, 10, i, 0),
          latitude: 47.52 + (i * 0.001),
          longitude: 13.69 + (i * 0.001),
          altitude: 1000.0 + (i * 50),
          speed: 35.0,
          vario: 1.5,
        ),
      );

      sampleFlight = FlightModel(
        id: 'flight_1',
        title: 'Krippenstein XC Classic',
        date: DateTime.utc(2026, 8, 20, 10, 0, 0),
        siteName: 'Krippenstein',
        category: FlightCategory.myFlights,
        uploadStatus: UploadStatus.notUploaded,
        points: samplePoints,
        statistics: const FlightStatistics(
          duration: Duration(hours: 1, minutes: 24),
          maxAltitude: 2150.0,
          minAltitude: 550.0,
          maxClimbRate: 3.8,
          maxSinkRate: -2.1,
          totalDistanceKm: 42.5,
          averageSpeedKmh: 36.2,
          averageGlideRatio: 8.8,
        ),
      );

      await storage.saveFlight(sampleFlight);
      uploadService = XContestUploadService(
        storageService: storage,
        settings: const FlightSettings(xcontestUsername: 'markus_pilot'),
      );
    });

    testWidgets('Renders FlightsScreen with tabs, search, and flight cards', (tester) async {
      FlightModel? replayedFlight;

      await tester.pumpWidget(
        MaterialApp(
          home: FlightsScreen(
            storageService: storage,
            uploadService: uploadService,
            onStartReplay: (f) => replayedFlight = f,
            onClose: () {},
          ),
        ),
      );

      expect(find.text('Flights & Logbook'), findsOneWidget);
      expect(find.textContaining('My Flights (1)'), findsOneWidget);
      expect(find.textContaining('Planned (0)'), findsOneWidget);
      expect(find.text('Krippenstein XC Classic'), findsOneWidget);
      expect(find.text('42.5 km'), findsOneWidget);

      // Tap Replay
      await tester.tap(find.text('Replay Flight'));
      await tester.pump();
      expect(replayedFlight, isNotNull);
      expect(replayedFlight!.id, 'flight_1');

      // Test Search query filtering
      await tester.enterText(find.byType(TextField), 'Nonexistent');
      await tester.pump();
      expect(find.text('Krippenstein XC Classic'), findsNothing);
      expect(find.text('No recorded flights yet'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Krippenstein');
      await tester.pump();
      expect(find.text('Krippenstein XC Classic'), findsOneWidget);
    });

    testWidgets('ReplayControlOverlay HUD renders controls and cycles speed multipliers', (tester) async {
      final replayService = FlightReplayService(flight: sampleFlight);
      addTearDown(replayService.dispose);
      var exited = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReplayControlOverlay(
              replayService: replayService,
              onExit: () => exited = true,
            ),
          ),
        ),
      );

      expect(find.text('Krippenstein XC Classic'), findsOneWidget);
      expect(find.text('1x'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);

      // Tap Play
      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pump();
      expect(replayService.isPlaying, isTrue);
      expect(find.byIcon(Icons.pause), findsOneWidget);

      // Cycle Speed Multiplier
      await tester.tap(find.text('1x'));
      await tester.pump();
      expect(replayService.speedMultiplier, 2);
      expect(find.text('2x'), findsOneWidget);

      // Tap Close/Exit
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(exited, isTrue);

      replayService.pause();
    });

    testWidgets('FlightSummarySheet displays statistics and triggers XContest upload', (tester) async {
      var viewedInLogbook = false;

      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FlightSummarySheet(
              flight: sampleFlight,
              storageService: storage,
              uploadService: uploadService,
              onViewInLogbook: () => viewedInLogbook = true,
              onDismiss: () {},
            ),
          ),
        ),
      );

      expect(find.text('Flight Completed'), findsOneWidget);
      expect(find.text('Krippenstein XC Classic'), findsOneWidget);
      expect(find.text('42.5 km'), findsOneWidget);
      expect(find.text('+3.8 m/s'), findsOneWidget);
      expect(find.text('Upload to XContest.org'), findsOneWidget);

      // Tap View in Logbook
      await tester.ensureVisible(find.text('View in Logbook'));
      await tester.tap(find.text('View in Logbook'));
      await tester.pump();
      expect(viewedInLogbook, isTrue);

      // Tap Upload to XContest.org
      await tester.ensureVisible(find.text('Upload to XContest.org'));
      await tester.tap(find.text('Upload to XContest.org'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Flight successfully uploaded to XContest.org!'), findsOneWidget);
    });
  });
}
