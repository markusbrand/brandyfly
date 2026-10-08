import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:brandyfly/services/flight_tracking_service.dart';
import 'package:brandyfly/services/region_manager_service.dart';
import 'package:brandyfly/services/screen_manager_service.dart';
import 'package:brandyfly/widgets/settings/pre_flight_coverage_prompt.dart';
import 'package:brandyfly/widgets/settings/region_manager_screen.dart';
import 'package:brandyfly/widgets/settings/ui_settings_panel.dart';

void main() {
  group('Region Manager UI and Pre-Flight Prompt Tests', () {
    late Directory tempDir;
    late String customBasePath;

    final testCatalogJson = {
      'catalogVersion': 1,
      'generatedAt': '2026-08-01T00:00:00.000Z',
      'regions': [
        {
          'id': 'alps-east',
          'name': 'Alps - Eastern',
          'description': 'Eastern Austria and Slovenia',
          'bounds': {
            'north': 48.3,
            'south': 46.2,
            'west': 12.5,
            'east': 16.6,
          },
          'version': '2026-08',
          'generatedAt': '2026-08-01T00:00:00.000Z',
          'files': {
            'map': {
              'url': 'https://cdn.example/regions/alps-east/map.pmtiles',
              'sizeBytes': 250,
              'sha256': '',
            },
            'terrain': {
              'url': 'https://cdn.example/regions/alps-east/terrain.pmtiles',
              'sizeBytes': 120,
              'sha256': '',
            },
          },
        },
        {
          'id': 'pyrenees',
          'name': 'Pyrenees',
          'description': 'Pyrenees flying area',
          'bounds': {
            'north': 43.5,
            'south': 42.0,
            'west': -1.5,
            'east': 3.0,
          },
          'version': '2026-08',
          'generatedAt': '2026-08-01T00:00:00.000Z',
          'files': {
            'map': {
              'url': 'https://cdn.example/regions/pyrenees/map.pmtiles',
              'sizeBytes': 180,
              'sha256': '',
            },
          },
        },
      ],
    };

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('brandyfly_ui_test_');
      customBasePath = tempDir.path;
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    testWidgets('RegionManagerScreen displays catalog, storage bar, and actions', (tester) async {
      final mockClient = MockClient((request) async {
        final url = request.url.toString();
        if (url.endsWith('catalog.json')) {
          return http.Response(jsonEncode(testCatalogJson), 200);
        }
        if (url.endsWith('map.pmtiles')) {
          return http.Response.bytes(List<int>.filled(250, 0), 200);
        }
        if (url.endsWith('terrain.pmtiles')) {
          return http.Response.bytes(List<int>.filled(120, 0), 200);
        }
        return http.Response('Not found', 404);
      });

      final service = RegionManagerService(
        customAppSupportDir: customBasePath,
        catalogUrl: 'https://cdn.example/catalog.json',
        requestTimeout: null,
        httpClient: mockClient,
      );

      await tester.runAsync(() async {
        await service.fetchCatalog();

        final pyreneesDir = Directory('$customBasePath/regions/pyrenees');
        await pyreneesDir.create(recursive: true);
        final metaFile = File('${pyreneesDir.path}/meta.json');
        await metaFile.writeAsString(jsonEncode({
          'id': 'pyrenees',
          'version': '2026-07',
          'downloadedAt': '2026-07-15T00:00:00.000Z',
          'directoryPath': pyreneesDir.path,
          'mapPath': '${pyreneesDir.path}/map.pmtiles',
          'bounds': {
            'north': 43.5,
            'south': 42.0,
            'west': -1.5,
            'east': 3.0,
          },
        }));
        final pyreneesMap = File('${pyreneesDir.path}/map.pmtiles');
        await pyreneesMap.writeAsBytes(List<int>.filled(180, 1));
      });

      await tester.pumpWidget(
        MaterialApp(
          home: RegionManagerScreen(regionManager: service),
        ),
      );

      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 250));
      });
      await tester.pumpAndSettle();

      // Verify title & storage header
      expect(find.text('Offline Map Regions'), findsOneWidget);
      expect(find.text('Offline Maps Storage'), findsOneWidget);

      // Verify region cards
      expect(find.text('Alps - Eastern'), findsOneWidget);
      expect(find.text('Pyrenees'), findsOneWidget);

      // alps-east is not downloaded -> shows "Available" and "Download" button
      expect(find.text('Available'), findsOneWidget);
      expect(find.byKey(const Key('download_button_alps-east')), findsOneWidget);

      // pyrenees has older version -> shows "Update available" badge and "Update" button
      expect(find.text('Update available'), findsOneWidget);
      expect(find.byKey(const Key('update_button_pyrenees')), findsOneWidget);
      expect(find.byKey(const Key('delete_button_pyrenees')), findsOneWidget);

      // Test delete dialog
      await tester.tap(find.byKey(const Key('delete_button_pyrenees')));
      await tester.pump();
      expect(find.text('Delete Pyrenees?'), findsOneWidget);

      // Confirm delete in dialog
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Delete'),
        ),
      );
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();

      // After delete, pyrenees should now show Download button
      expect(find.byKey(const Key('download_button_pyrenees')), findsOneWidget);
    });

    testWidgets('PreFlightCoveragePrompt displays suggested regions and dismisses', (tester) async {
      final service = RegionManagerService(
        customAppSupportDir: customBasePath,
        catalogUrl: 'https://cdn.example/catalog.json',
        requestTimeout: null,
        httpClient: MockClient((request) async {
          return http.Response(jsonEncode(testCatalogJson), 200);
        }),
      );

      await tester.runAsync(() async {
        await service.fetchCatalog();
      });

      bool dismissed = false;
      bool manageTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PreFlightCoveragePrompt(
              latitude: 47.0,
              longitude: 13.0,
              regionManager: service,
              onDismiss: () => dismissed = true,
              onManageRegions: () => manageTapped = true,
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('No Offline Map Coverage'), findsOneWidget);
      expect(find.text('Alps - Eastern'), findsOneWidget);

      // Tap "Manage Regions"
      await tester.tap(find.text('Manage Regions'));
      await tester.pump();
      expect(manageTapped, isTrue);

      // Tap "Not Now"
      await tester.tap(find.text('Not Now'));
      await tester.pump();
      expect(dismissed, isTrue);
    });

    testWidgets('UISettingsPanel has entry navigating to RegionManagerScreen', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final screenManager = ScreenManagerService();
      final trackingService = FlightTrackingService();
      final service = RegionManagerService(
        customAppSupportDir: customBasePath,
        requestTimeout: null,
        httpClient: MockClient((request) async {
          return http.Response(jsonEncode(testCatalogJson), 200);
        }),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: UISettingsPanel(
            screenManager: screenManager,
            trackingService: trackingService,
            regionManagerService: service,
          ),
        ),
      );

      await tester.pump();

      final offlineCard = find.byKey(const Key('offline_regions_entry_card'));
      await tester.scrollUntilVisible(
        offlineCard,
        200.0,
        scrollable: find.byType(Scrollable).first,
      );
      expect(offlineCard, findsOneWidget);

      await tester.tap(offlineCard);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(RegionManagerScreen), findsOneWidget);
    });
  });
}
