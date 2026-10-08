import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brandyfly/services/airspace_service.dart';
import 'package:brandyfly/widgets/flight/airspace_map_layer.dart';
import 'package:brandyfly/widgets/flight/airspace_side_cut_widget.dart';
import 'package:brandyfly/widgets/flight/airspace_warning_banner_hud.dart';

void main() {
  group('Airspace UI Widget Tests', () {
    testWidgets('AirspaceSideCutWidget renders header, L/D and grid', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 200,
              child: AirspaceSideCutWidget(
                aircraftAltitudeMsl: 1500.0,
                groundspeedMps: 12.0,
                headingDeg: 90.0,
                glideRatio: 8.5,
                terrainElevationMsl: 650.0,
                forwardBlocks: [],
              ),
            ),
          ),
        ),
      );

      expect(find.text('SIDE-CUT (90°)'), findsOneWidget);
      expect(find.textContaining('L/D 8.5'), findsOneWidget);
      expect(find.byType(AirspaceSideCutWidget), findsOneWidget);
    });

    testWidgets('AirspaceSideCutWidget surfaces PENETRATION RISK on penetration', (tester) async {
      const airspace = AirspaceModel(
        id: 'test-ctr',
        name: 'INNSBRUCK CTR',
        airspaceClass: 'CTR',
        floorLabel: 'GND',
        ceilingLabel: '5000ft MSL',
        floorMslM: 600.0,
        ceilingMslM: 1524.0,
        polygon: [
          (lat: 47.2, lon: 11.2),
          (lat: 47.3, lon: 11.2),
          (lat: 47.3, lon: 11.4),
          (lat: 47.2, lon: 11.4),
        ],
      );

      const block = ForwardAirspaceBlock(
        airspace: airspace,
        entryDistanceM: 2000.0,
        exitDistanceM: 5000.0,
        entryAltitudeM: 1200.0,
        floorMslM: 600.0,
        ceilingMslM: 1524.0,
        willPenetrate: true,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 220,
              child: AirspaceSideCutWidget(
                aircraftAltitudeMsl: 1400.0,
                groundspeedMps: 10.0,
                headingDeg: 90.0,
                forwardBlocks: [block],
              ),
            ),
          ),
        ),
      );

      expect(find.text('PENETRATION'), findsOneWidget);
    });

    testWidgets('AirspaceMapLayer paints vector boundary without error', (tester) async {
      const airspace = AirspaceModel(
        id: 'test-ctr',
        name: 'INNSBRUCK CTR',
        airspaceClass: 'CTR',
        floorLabel: 'GND',
        ceilingLabel: '5000ft MSL',
        floorMslM: 600.0,
        ceilingMslM: 1524.0,
        polygon: [
          (lat: 47.2, lon: 11.2),
          (lat: 47.3, lon: 11.2),
          (lat: 47.3, lon: 11.4),
          (lat: 47.2, lon: 11.4),
        ],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: AirspaceMapLayer(
                airspaces: [airspace],
                centerLat: 47.25,
                centerLon: 11.30,
                zoom: 11.0,
                activeAlertLevel: AirspaceAlertLevel.warning,
                highlightedAirspaceId: 'test-ctr',
              ),
            ),
          ),
        ),
      );

      expect(find.byType(AirspaceMapLayer), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('AirspaceWarningBannerHUD renders advisory, warning, and violation states', (tester) async {
      // 1. Advisory state
      const advisoryState = AirspaceProximityState(
        alertLevel: AirspaceAlertLevel.advisory,
        airspaceName: 'ED-R107 ALLGAEU',
        airspaceClass: 'R',
        horizontalSeparationM: 850.0,
        verticalSeparationM: 120.0,
        total3dDistanceM: 858.0,
        isInsideHorizontal: false,
        isInsideVertical: false,
        floorMslM: 1000.0,
        ceilingMslM: 3000.0,
        forwardIntersectionDistanceM: -1.0,
        forwardIntersectionTimeS: -1.0,
        willPenetrateGlideSlope: false,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AirspaceWarningBannerHUD(proximity: advisoryState),
          ),
        ),
      );

      expect(find.text('ADVISORY'), findsOneWidget);
      expect(find.text('ED-R107 ALLGAEU'), findsOneWidget);
      expect(find.text('R'), findsOneWidget);
      expect(find.textContaining('H: 850m'), findsOneWidget);

      // 2. Violation state
      const violationState = AirspaceProximityState(
        alertLevel: AirspaceAlertLevel.violation,
        airspaceName: 'INNSBRUCK CTR',
        airspaceClass: 'CTR',
        horizontalSeparationM: 0.0,
        verticalSeparationM: 0.0,
        total3dDistanceM: 0.0,
        isInsideHorizontal: true,
        isInsideVertical: true,
        floorMslM: 600.0,
        ceilingMslM: 1524.0,
        forwardIntersectionDistanceM: -1.0,
        forwardIntersectionTimeS: -1.0,
        willPenetrateGlideSlope: false,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AirspaceWarningBannerHUD(proximity: violationState),
          ),
        ),
      );

      expect(find.text('VIOLATION'), findsOneWidget);
      expect(find.text('INSIDE AIRSPACE BOUNDS'), findsOneWidget);
    });

    testWidgets('AirspaceWarningBannerHUD can be dismissed', (tester) async {
      var dismissed = false;
      const warningState = AirspaceProximityState(
        alertLevel: AirspaceAlertLevel.warning,
        airspaceName: 'DANGER AREA D-08',
        airspaceClass: 'D',
        horizontalSeparationM: 320.0,
        verticalSeparationM: 40.0,
        total3dDistanceM: 322.0,
        isInsideHorizontal: false,
        isInsideVertical: false,
        floorMslM: 0.0,
        ceilingMslM: 3500.0,
        forwardIntersectionDistanceM: -1.0,
        forwardIntersectionTimeS: -1.0,
        willPenetrateGlideSlope: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AirspaceWarningBannerHUD(
              proximity: warningState,
              onDismiss: () => dismissed = true,
            ),
          ),
        ),
      );

      expect(find.text('WARNING'), findsOneWidget);

      // Tap close button
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(dismissed, isTrue);
      expect(find.text('WARNING'), findsNothing);
    });
  });
}
