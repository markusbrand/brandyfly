import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brandyfly/models/flight_model.dart';
import 'package:brandyfly/services/airspace_service.dart';
import 'package:brandyfly/services/flight_replay_service.dart';
import 'package:brandyfly/widgets/flight/airspace_side_cut_widget.dart';
import 'package:brandyfly/widgets/flight/airspace_warning_banner_hud.dart';
import 'package:brandyfly_native/brandyfly_native.dart';

class FakeAirspaceNative extends BrandyflyNative {
  @override
  Future<int> airspaceInitStore() async => 1;

  @override
  Future<int> airspaceLoadDachFixture() async => 7;

  @override
  Future<int> airspaceLoadOpenAir(String openAirText) async => 1;

  @override
  Future<int> airspaceClearStore() async => 0;

  @override
  Future<int> airspaceCount() async => 7;

  @override
  Future<NativeAirspaceEvaluationOutput> airspaceEvaluate(
    NativeAirspaceEvaluationInput input,
  ) async =>
      NativeAirspaceEvaluationOutput.clear;
}

void main() {
  group('Airspace Replay End-to-End Simulation Tests', () {
    testWidgets(
      'Replay flight progressing towards and into airspace triggers HUD alert and side-cut visualization',
      (tester) async {
        // 1. Prepare synthetic flight path heading into Innsbruck CTR (lat ~47.26, lon ~11.20)
        final startTime = DateTime(2026, 6, 15, 14, 0, 0);
        final points = <FlightPoint>[
          // Point 0: 15 km away, clear of airspace
          FlightPoint(
            latitude: 47.26,
            longitude: 11.00,
            altitude: 2000.0,
            timestamp: startTime,
            speed: 36.0,
            heading: 90.0,
            vario: -1.0,
          ),
          // Point 1: 5 km away, heading 90
          FlightPoint(
            latitude: 47.26,
            longitude: 11.10,
            altitude: 1600.0,
            timestamp: startTime.add(const Duration(minutes: 2)),
            speed: 36.0,
            heading: 90.0,
            vario: -1.0,
          ),
          // Point 2: Inside Innsbruck CTR (lat 47.26, lon 11.25, alt 1000m < 1524m ceiling)
          FlightPoint(
            latitude: 47.26,
            longitude: 11.25,
            altitude: 1000.0,
            timestamp: startTime.add(const Duration(minutes: 5)),
            speed: 36.0,
            heading: 90.0,
            vario: -0.5,
          ),
        ];

        final flight = FlightModel(
          id: 'replay-test-flight',
          title: 'Innsbruck Approach Replay',
          date: startTime,
          points: points,
          statistics: const FlightStatistics(
            duration: Duration(minutes: 5),
            totalDistanceKm: 18.0,
            maxAltitude: 2000.0,
            minAltitude: 1000.0,
            maxClimbRate: 0.0,
            maxSinkRate: -1.0,
            averageSpeedKmh: 36.0,
            averageGlideRatio: 8.0,
          ),
        );

        // 2. Initialize AirspaceService with fake native client and load DACH Alpine airspace data
        final airspaceService = AirspaceService(nativeClient: FakeAirspaceNative());
        await airspaceService.loadDachFixture();
        expect(airspaceService.loadedAirspaces, isNotEmpty);

        // 3. Initialize replay service with flight
        final replayService = FlightReplayService(flight: flight);
        airspaceService.attachFlightReplayService(replayService);

        // 4. Pump UI with AirspaceWarningBannerHUD and AirspaceSideCutWidget
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedBuilder(
                animation: airspaceService,
                builder: (context, _) {
                  final curPt = replayService.currentPoint ?? points.first;
                  final forwardBlocks = airspaceService.getForwardAirspaces(
                    lat: curPt.latitude,
                    lon: curPt.longitude,
                    altitudeMsl: curPt.altitude,
                    headingDeg: curPt.heading,
                    lookaheadDistanceM: 15000.0,
                    glideRatio: 8.0,
                  );

                  return Column(
                    children: [
                      AirspaceWarningBannerHUD(
                        proximity: airspaceService.latestProximity,
                      ),
                      Expanded(
                        child: AirspaceSideCutWidget(
                          aircraftAltitudeMsl: curPt.altitude,
                          groundspeedMps: curPt.speed / 3.6,
                          headingDeg: curPt.heading,
                          forwardBlocks: forwardBlocks,
                          lookaheadDistanceM: 15000.0,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );

        // Step 0: Initially 15 km away -> Clear of airspace
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.byType(AirspaceSideCutWidget), findsOneWidget);
        // Alert banner should be hidden when clear
        expect(find.text('VIOLATION'), findsNothing);

        // Step 1: Advance replay to Point 2 (inside Innsbruck CTR)
        replayService.seekToRatio(1.0); // Jump to last point (index 2)
        await tester.pump(const Duration(milliseconds: 100));

        // Proximity should now be evaluated inside Innsbruck CTR
        expect(airspaceService.activeAlertLevel, AirspaceAlertLevel.violation);

        // Alert HUD banner must now surface VIOLATION
        expect(find.text('VIOLATION'), findsOneWidget);
        expect(find.text('INSIDE AIRSPACE BOUNDS'), findsOneWidget);

        // Unmount widget tree to cleanly stop repeating animations
        await tester.pumpWidget(const SizedBox());

        // Cleanup
        airspaceService.dispose();
        replayService.dispose();
      },
    );
  });
}
