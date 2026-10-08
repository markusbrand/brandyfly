import 'dart:io';

import 'package:brandyfly/data/repositories/telemetry_repository.dart';
import 'package:brandyfly/domain/models/cockpit_telemetry.dart';
import 'package:brandyfly/domain/models/size_tier.dart';
import 'package:brandyfly/domain/models/ui_config.dart';
import 'package:brandyfly/domain/thermal/geo_bounds.dart';
import 'package:brandyfly/services/elevation_service.dart';
import 'package:brandyfly/services/flight_replay_service.dart';
import 'package:brandyfly/services/telemetry/telemetry_types.dart';
import 'package:brandyfly/ui/features/flight_canvas/views/widget_slot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/terrain_fixture.dart';

void main() {
  group('HAG Telemetry Pipeline with ElevationService', () {
    late Directory tempDir;
    late File pmtilesFile;
    late ElevationService elevationService;
    late FlightReplayService replayService;

    const testZ = 12;
    const testX = 2203;
    const testY = 1431;
    final testBounds = GeoBounds(
      west: 13.6,
      south: 47.45,
      east: 13.8,
      north: 47.6,
    );

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hag_integration_test_');
      final pngBytes = encodeTerrainPng(
        width: 256,
        height: 256,
        elevationAt: (x, y) => 1200.0, // Constant 1200m ground elevation
      );

      pmtilesFile = await writeTerrainPmtiles(
        '${tempDir.path}/terrain.pmtiles',
        z: testZ,
        x: testX,
        y: testY,
        pngBytes: pngBytes,
        bounds: testBounds,
      );

      elevationService = ElevationService(cacheCapacity: 8);
      await elevationService.addTerrainSource('alps', pmtilesFile.path);
      replayService = FlightReplayService();
    });

    tearDown(() async {
      await elevationService.dispose();
      replayService.dispose();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('computes HAG = altitude - groundElevation on GPS update', () async {
      final repo = TelemetryRepository(
        replayService: replayService,
        elevationService: elevationService,
      );

      // Krippenstein coordinate (lat=47.52, lon=13.69), altitude=1650.0
      // Ground is 1200.0, expected HAG = 1650.0 - 1200.0 = 450.0
      repo.onSnapshot(
        TelemetrySnapshot(
          timestamp: DateTime.utc(2026, 6, 1, 12, 0, 0),
          altitude: 1650.0,
          vario: 1.5,
          speed: 35.0,
          heading: 180.0,
          latitude: 47.52,
          longitude: 13.69,
        ),
      );

      // Allow async elevation query to complete
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(repo.telemetry.value.hag, isNotNull);
      expect(repo.telemetry.value.hag!, closeTo(450.0, 0.5));

      // Subsequent update at same or nearby coordinate resolves from cache immediately
      repo.onSnapshot(
        TelemetrySnapshot(
          timestamp: DateTime.utc(2026, 6, 1, 12, 0, 1),
          altitude: 1700.0,
          vario: 2.0,
          speed: 36.0,
          heading: 180.0,
          latitude: 47.521,
          longitude: 13.691,
        ),
      );

      expect(repo.telemetry.value.hag, isNotNull);
      expect(repo.telemetry.value.hag!, closeTo(500.0, 0.5));

      repo.dispose();
    });

    test('handles null elevation gracefully when outside coverage', () async {
      final repo = TelemetryRepository(
        replayService: replayService,
        elevationService: elevationService,
      );

      // Coordinate outside Alps coverage (e.g. 51.5, -0.1)
      repo.onSnapshot(
        TelemetrySnapshot(
          timestamp: DateTime.utc(2026, 6, 1, 12, 0, 0),
          altitude: 2000.0,
          vario: 0.0,
          speed: 40.0,
          heading: 90.0,
          latitude: 51.5,
          longitude: -0.1,
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(repo.telemetry.value.hag, isNull);
      repo.dispose();
    });

    test('holds previous HAG value during cache miss to prevent flickering', () async {
      final repo = TelemetryRepository(
        replayService: replayService,
        elevationService: elevationService,
      );

      // First query fills cache and establishes initial HAG
      repo.onSnapshot(
        TelemetrySnapshot(
          timestamp: DateTime.utc(2026, 6, 1, 12, 0, 0),
          altitude: 1500.0,
          vario: 0.0,
          speed: 35.0,
          heading: 180.0,
          latitude: 47.52,
          longitude: 13.69,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(repo.telemetry.value.hag, closeTo(300.0, 0.5));

      // Now clear elevation service cache to simulate moving to a non-cached tile
      elevationService.tileCache.clear();

      // Immediate tick with new altitude before disk read completes
      repo.onSnapshot(
        TelemetrySnapshot(
          timestamp: DateTime.utc(2026, 6, 1, 12, 0, 1),
          altitude: 1550.0,
          vario: 1.0,
          speed: 35.0,
          heading: 180.0,
          latitude: 47.52,
          longitude: 13.69,
        ),
      );

      // On cache miss tick, the previous HAG is held synchronously
      expect(repo.telemetry.value.hag, closeTo(300.0, 0.5));

      // After async disk query resolves, new HAG is applied
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(repo.telemetry.value.hag, closeTo(350.0, 0.5));

      repo.dispose();
    });
  });

  group('HAG Widget Display Integration', () {
    testWidgets('renders formatted numeric HAG when elevation is available', (tester) async {
      final telemetryNotifier = ValueNotifier<CockpitTelemetry>(
        const CockpitTelemetry(hag: 350.0),
      );

      final model = const WidgetPlacementModel(
        id: 'hag_slot',
        type: WidgetType.hag,
        x: 0,
        y: 0,
        w: 4,
        h: 2,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: 100,
                child: FlightWidgetContent(
                  model: model,
                  telemetry: telemetryNotifier,
                  tier: SizeTier.regular,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('HAG'), findsOneWidget);
      expect(find.text('350'), findsOneWidget);
      expect(find.text('m AGL'), findsOneWidget);

      // Update telemetry value
      telemetryNotifier.value = const CockpitTelemetry(hag: 420.0);
      await tester.pump();

      expect(find.text('420'), findsOneWidget);
    });

    testWidgets('renders "---" when HAG elevation is null', (tester) async {
      final telemetryNotifier = ValueNotifier<CockpitTelemetry>(
        const CockpitTelemetry(hag: null),
      );

      final model = const WidgetPlacementModel(
        id: 'hag_slot',
        type: WidgetType.hag,
        x: 0,
        y: 0,
        w: 4,
        h: 2,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: 100,
                child: FlightWidgetContent(
                  model: model,
                  telemetry: telemetryNotifier,
                  tier: SizeTier.regular,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('HAG'), findsOneWidget);
      expect(find.text('---'), findsOneWidget);
      expect(find.text('m AGL'), findsOneWidget);

      // Update telemetry from null to valid value
      telemetryNotifier.value = const CockpitTelemetry(hag: 285.0);
      await tester.pump();

      expect(find.text('285'), findsOneWidget);

      // Transition back to null (e.g. left region coverage)
      telemetryNotifier.value = const CockpitTelemetry(hag: null);
      await tester.pump();

      expect(find.text('---'), findsOneWidget);
    });
  });
}
