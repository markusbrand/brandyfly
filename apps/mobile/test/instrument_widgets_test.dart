import 'package:brandyfly/models/flight_model.dart';
import 'package:brandyfly/models/flight_settings.dart';
import 'package:brandyfly/models/ui_config.dart';
import 'package:brandyfly/services/flight_replay_service.dart';
import 'package:brandyfly/services/flight_storage_service.dart';
import 'package:brandyfly/services/xcontest_upload_service.dart';
import 'package:brandyfly/widgets/flight/altitude_sparkline_chart.dart';
import 'package:brandyfly/widgets/flight/flight_summary_sheet.dart';
import 'package:brandyfly/widgets/flight/numeric_text_widget.dart';
import 'package:brandyfly/widgets/flight/replay_control_overlay.dart';
import 'package:brandyfly/widgets/flight/vario_lift_sink_bar.dart';
import 'package:brandyfly/widgets/flight/wind_direction_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrapWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 300,
            height: 200,
            child: child,
          ),
        ),
      ),
    );
  }

  group('AltitudeSparklineChart Tests', () {
    testWidgets('renders minimalSparkline with multiple points', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          const AltitudeSparklineChart(
            history: [1200.0, 1350.0, 1500.0, 1480.0],
            style: AltitudeChartStyle.minimalSparkline,
          ),
        ),
      );
      expect(find.text('ALTITUDE HISTORY (SPARKLINE)'), findsOneWidget);
    });

    testWidgets('renders filledAreaGraph cleanly', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          const AltitudeSparklineChart(
            history: [1000.0, 1100.0, 1200.0],
            style: AltitudeChartStyle.filledAreaGraph,
          ),
        ),
      );
      expect(find.text('ALTITUDE PROFILE (AREA)'), findsOneWidget);
    });

    testWidgets('renders detailedGrid cleanly', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          const AltitudeSparklineChart(
            history: [1000.0, 1050.0, 1100.0],
            style: AltitudeChartStyle.detailedGrid,
          ),
        ),
      );
      expect(find.text('ALTITUDE / TIME GRID'), findsOneWidget);
    });

    testWidgets('handles single point history without crashing', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          const AltitudeSparklineChart(
            history: [1250.0],
            style: AltitudeChartStyle.minimalSparkline,
          ),
        ),
      );
      expect(find.text('ALTITUDE HISTORY (SPARKLINE)'), findsOneWidget);
    });

    testWidgets('handles empty history without crashing', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          const AltitudeSparklineChart(
            history: [],
            style: AltitudeChartStyle.minimalSparkline,
          ),
        ),
      );
      expect(find.text('ALTITUDE HISTORY (SPARKLINE)'), findsOneWidget);
    });
  });

  group('NumericTextWidget Tests', () {
    testWidgets('renders minimalistText style', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          const NumericTextWidget(
            label: 'Altitude',
            value: '1850',
            unit: 'm',
            style: NumericWidgetStyle.minimalistText,
          ),
        ),
      );
      expect(find.text('ALTITUDE'), findsOneWidget);
      expect(find.text('1850'), findsOneWidget);
      expect(find.text('m'), findsOneWidget);
    });

    testWidgets('renders highContrastBox style', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          const NumericTextWidget(
            label: 'Speed',
            value: '42.5',
            unit: 'km/h',
            style: NumericWidgetStyle.highContrastBox,
          ),
        ),
      );
      expect(find.text('SPEED'), findsOneWidget);
      expect(find.text('42.5 km/h'), findsOneWidget);
    });

    testWidgets('renders circularGauge style', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          const NumericTextWidget(
            label: 'Glide',
            value: '8.4',
            unit: 'L/D',
            style: NumericWidgetStyle.circularGauge,
          ),
        ),
      );
      expect(find.text('GLIDE'), findsOneWidget);
      expect(find.text('8.4'), findsOneWidget);
      expect(find.text('L/D'), findsOneWidget);
    });

    testWidgets('renders retroDigital style', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          const NumericTextWidget(
            label: 'HAG',
            value: '350',
            unit: 'm AGL',
            style: NumericWidgetStyle.retroDigital,
          ),
        ),
      );
      expect(find.text('HAG'), findsOneWidget);
      expect(find.text('350 m AGL'), findsOneWidget);
    });
  });

  group('VarioLiftSinkBar Tests', () {
    testWidgets('renders verticalEdgeBar with positive climb', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          const VarioLiftSinkBar(
            climbRateMs: 2.5,
            style: LiftSinkBarStyle.verticalEdgeBar,
          ),
        ),
      );
      expect(find.text('+2.5'), findsOneWidget);
      expect(find.text('m/s'), findsOneWidget);
    });

    testWidgets('renders verticalEdgeBar with negative sink', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          const VarioLiftSinkBar(
            climbRateMs: -1.8,
            style: LiftSinkBarStyle.verticalEdgeBar,
          ),
        ),
      );
      expect(find.text('-1.8'), findsOneWidget);
    });

    testWidgets('renders analogDial style', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          const VarioLiftSinkBar(
            climbRateMs: 1.25,
            style: LiftSinkBarStyle.analogDial,
          ),
        ),
      );
      expect(find.text('VARIO DIAL'), findsOneWidget);
      expect(find.text('1.25 m/s'), findsOneWidget);
    });

    testWidgets('renders screenEdgeGlow style', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          const VarioLiftSinkBar(
            climbRateMs: 3.0,
            style: LiftSinkBarStyle.screenEdgeGlow,
          ),
        ),
      );
      expect(find.text('VARIO GLOW'), findsOneWidget);
      expect(find.text('+3.0 m/s'), findsOneWidget);
    });
  });

  group('WindDirectionWidget Tests', () {
    testWidgets('renders relativeArrow style', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          const WindDirectionWidget(
            directionDegrees: 240.0,
            speedKmH: 15.2,
            style: WindWidgetStyle.relativeArrow,
          ),
        ),
      );
      expect(find.text('WIND'), findsOneWidget);
      expect(find.text('15.2 km/h'), findsOneWidget);
      expect(find.text('240°'), findsOneWidget);
    });

    testWidgets('renders miniCompassRose style', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          const WindDirectionWidget(
            directionDegrees: 90.0,
            speedKmH: 18.0,
            style: WindWidgetStyle.miniCompassRose,
          ),
        ),
      );
      expect(find.text('N'), findsOneWidget);
      expect(find.text('18 km/h'), findsOneWidget);
    });

    testWidgets('renders windsockIndicator style', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          const WindDirectionWidget(
            directionDegrees: 180.0,
            speedKmH: 22.0,
            style: WindWidgetStyle.windsockIndicator,
          ),
        ),
      );
      expect(find.text('WINDSOCK'), findsOneWidget);
      expect(find.text('22 km/h @ 180°'), findsOneWidget);
    });
  });

  group('ReplayControlOverlay Tests', () {
    testWidgets('interacts with play/pause, seek, speed, and exit', (tester) async {
      final sampleFlight = FlightModel(
        id: 'replay_test',
        title: 'Replay Test Flight',
        date: DateTime.utc(2026, 8, 20, 10, 0, 0),
        points: [
          FlightPoint(
            timestamp: DateTime.utc(2026, 8, 20, 10, 0, 0),
            latitude: 47.0,
            longitude: 13.0,
            altitude: 1000.0,
          ),
          FlightPoint(
            timestamp: DateTime.utc(2026, 8, 20, 10, 0, 10),
            latitude: 47.01,
            longitude: 13.01,
            altitude: 1050.0,
          ),
        ],
        statistics: const FlightStatistics(
          duration: Duration(seconds: 10),
          maxAltitude: 1050.0,
          minAltitude: 1000.0,
          maxClimbRate: 5.0,
          maxSinkRate: 0.0,
          totalDistanceKm: 1.0,
          averageSpeedKmh: 36.0,
          averageGlideRatio: 8.0,
        ),
      );

      final replayService = FlightReplayService(flight: sampleFlight);
      bool exitCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReplayControlOverlay(
              replayService: replayService,
              onExit: () => exitCalled = true,
            ),
          ),
        ),
      );

      expect(find.text('Replay Test Flight'), findsOneWidget);
      expect(find.text('1x'), findsOneWidget);

      // Play toggle
      await tester.tap(find.byTooltip('Play'));
      await tester.pump();
      expect(replayService.isPlaying, isTrue);

      // Pause toggle
      await tester.tap(find.byTooltip('Pause'));
      await tester.pump();
      expect(replayService.isPlaying, isFalse);

      // Cycle speed
      await tester.tap(find.text('1x'));
      await tester.pump();
      expect(find.text('2x'), findsOneWidget);
      expect(replayService.speedMultiplier, 2);

      // Forward 10s
      await tester.tap(find.byTooltip('Forward 10s'));
      await tester.pump();
      expect(replayService.currentIndex, 1);

      // Rewind 10s
      await tester.tap(find.byTooltip('Back 10s'));
      await tester.pump();
      expect(replayService.currentIndex, 0);

      // Exit button
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(exitCalled, isTrue);

      replayService.dispose();
    });
  });

  group('FlightSummarySheet Tests', () {
    testWidgets('renders flight stats and handles upload and view in logbook', (tester) async {
      final flight = FlightModel(
        id: 'summary_flight',
        title: 'Finished Glide',
        date: DateTime.utc(2026, 8, 20, 12, 0, 0),
        statistics: const FlightStatistics(
          duration: Duration(minutes: 25, seconds: 30),
          maxAltitude: 2100.0,
          minAltitude: 900.0,
          maxClimbRate: 3.5,
          maxSinkRate: -2.1,
          totalDistanceKm: 18.2,
          averageSpeedKmh: 42.8,
          averageGlideRatio: 8.9,
        ),
      );

      final storageService = FlightStorageService();
      final uploadService = XContestUploadService(
        storageService: storageService,
        settings: const FlightSettings(xcontestUsername: 'markus'),
      );

      bool viewInLogbookCalled = false;
      bool dismissCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FlightSummarySheet(
              flight: flight,
              storageService: storageService,
              uploadService: uploadService,
              onViewInLogbook: () => viewInLogbookCalled = true,
              onDismiss: () => dismissCalled = true,
            ),
          ),
        ),
      );

      expect(find.text('Flight Completed'), findsOneWidget);
      expect(find.text('Finished Glide'), findsOneWidget);
      expect(find.text('25m 30s'), findsOneWidget);
      expect(find.text('18.2 km'), findsOneWidget);
      expect(find.text('2100 m'), findsOneWidget);

      // Trigger upload button
      final uploadBtn = find.text('Upload to XContest.org');
      await tester.ensureVisible(uploadBtn);
      await tester.pumpAndSettle();
      await tester.tap(uploadBtn);
      await tester.pump(); // Start upload
      await tester.pump(const Duration(milliseconds: 500)); // Finish upload simulation
      await tester.pumpAndSettle();
      expect(find.text('Flight successfully uploaded to XContest.org!'), findsOneWidget);

      // View in logbook button
      final viewBtn = find.text('View in Logbook');
      await tester.ensureVisible(viewBtn);
      await tester.pumpAndSettle();
      await tester.tap(viewBtn);
      expect(viewInLogbookCalled, isTrue);

      // Close button
      final closeBtn = find.byIcon(Icons.close);
      await tester.ensureVisible(closeBtn);
      await tester.pumpAndSettle();
      await tester.tap(closeBtn);
      expect(dismissCalled, isTrue);

      storageService.dispose();
      uploadService.dispose();
    });
  });

  group('Compact Dimensions Rendering Tests', () {
    Widget wrapCompact(Widget child, {double width = 60, double height = 38}) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              height: height,
              child: child,
            ),
          ),
        ),
      );
    }

    testWidgets('renders numeric widgets in compact box without overflow', (tester) async {
      await tester.pumpWidget(
        wrapCompact(
          const NumericTextWidget(
            label: 'Alt',
            value: '1850',
            unit: 'm',
            style: NumericWidgetStyle.minimalistText,
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('ALT'), findsOneWidget);
      expect(find.text('1850'), findsOneWidget);
    });

    testWidgets('renders vario bar in compact box without overflow', (tester) async {
      await tester.pumpWidget(
        wrapCompact(
          const VarioLiftSinkBar(
            climbRateMs: 2.5,
            style: LiftSinkBarStyle.verticalEdgeBar,
          ),
          width: 35,
          height: 70,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('+2.5'), findsOneWidget);
    });

    testWidgets('renders wind direction widget in compact box without overflow', (tester) async {
      await tester.pumpWidget(
        wrapCompact(
          const WindDirectionWidget(
            directionDegrees: 240.0,
            speedKmH: 15.0,
            style: WindWidgetStyle.relativeArrow,
          ),
          width: 70,
          height: 38,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('WIND'), findsOneWidget);
    });

    testWidgets('renders sparkline chart in compact box without overflow', (tester) async {
      await tester.pumpWidget(
        wrapCompact(
          const AltitudeSparklineChart(
            history: [1200.0, 1300.0, 1400.0],
            style: AltitudeChartStyle.minimalSparkline,
          ),
          width: 80,
          height: 38,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
