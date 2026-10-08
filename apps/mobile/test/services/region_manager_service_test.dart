import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:brandyfly/services/region_manager_service.dart';

void main() {
  group('RegionManagerService', () {
    late Directory tempDir;
    late String customBasePath;

    final dummyCatalogJson = {
      'catalogVersion': 1,
      'generatedAt': '2026-08-01T00:00:00.000Z',
      'regions': [
        {
          'id': 'alps-east',
          'name': 'Alps - Eastern',
          'description': 'Eastern Austria, Slovenia, SE Bavaria',
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
              'sizeBytes': 200,
              'sha256': '',
            },
            'terrain': {
              'url': 'https://cdn.example/regions/alps-east/terrain.pmtiles',
              'sizeBytes': 150,
              'sha256': '',
            },
          },
        },
        {
          'id': 'dolomites',
          'name': 'Dolomites',
          'description': 'Northern Italy',
          'bounds': {
            'north': 46.8,
            'south': 45.8,
            'west': 11.0,
            'east': 12.5,
          },
          'version': '2026-08',
          'generatedAt': '2026-08-01T00:00:00.000Z',
          'files': {
            'map': {
              'url': 'https://cdn.example/regions/dolomites/map.pmtiles',
              'sizeBytes': 180,
              'sha256': '',
            },
          },
        },
      ],
    };

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('brandyfly_region_test_');
      customBasePath = tempDir.path;
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('fetchCatalog fetches remote catalog and saves local cache', () async {
      final mockClient = MockClient((request) async {
        if (request.url.toString().endsWith('catalog.json')) {
          return http.Response(jsonEncode(dummyCatalogJson), 200);
        }
        return http.Response('Not Found', 404);
      });

      final service = RegionManagerService(
        customAppSupportDir: customBasePath,
        catalogUrl: 'https://cdn.example/catalog.json',
        httpClient: mockClient,
      );

      final catalog = await service.fetchCatalog();
      expect(catalog, isNotNull);
      expect(catalog!.catalogVersion, 1);
      expect(catalog.regions.length, 2);
      expect(catalog.regions.first.id, 'alps-east');

      // Verify cache file was written
      final cacheFile = File('$customBasePath/regions/catalog_cache.json');
      expect(await cacheFile.exists(), isTrue);
      final cacheContent = await cacheFile.readAsString();
      expect(cacheContent, contains('alps-east'));
    });

    test('fetchCatalog falls back to offline cache when network fails', () async {
      final regionsDir = Directory('$customBasePath/regions');
      await regionsDir.create(recursive: true);
      final cacheFile = File('${regionsDir.path}/catalog_cache.json');
      await cacheFile.writeAsString(jsonEncode(dummyCatalogJson));

      final failingClient = MockClient((request) async {
        throw const SocketException('No route to host');
      });

      final service = RegionManagerService(
        customAppSupportDir: customBasePath,
        catalogUrl: 'https://cdn.example/catalog.json',
        httpClient: failingClient,
      );

      final catalog = await service.fetchCatalog();
      expect(catalog, isNotNull);
      expect(catalog!.regions.length, 2);
      expect(catalog.findRegion('alps-east'), isNotNull);
    });

    test('downloadRegion performs resumable HTTP download, checksums, and atomic swap', () async {
      final mapBytes = List<int>.generate(200, (i) => i % 256);
      final mapHash = sha256.convert(mapBytes).toString();

      final terrainBytes = List<int>.generate(150, (i) => (i * 2) % 256);
      final terrainHash = sha256.convert(terrainBytes).toString();

      final dynamicCatalogJson = {
        'catalogVersion': 1,
        'generatedAt': '2026-08-01T00:00:00.000Z',
        'regions': [
          {
            'id': 'alps-east',
            'name': 'Alps - Eastern',
            'description': 'Eastern Austria',
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
                'sizeBytes': 200,
                'sha256': mapHash,
              },
              'terrain': {
                'url': 'https://cdn.example/regions/alps-east/terrain.pmtiles',
                'sizeBytes': 150,
                'sha256': terrainHash,
              },
            },
          },
        ],
      };

      final mockClient = MockClient((request) async {
        final url = request.url.toString();
        if (url.endsWith('catalog.json')) {
          return http.Response(jsonEncode(dynamicCatalogJson), 200);
        }

        if (url.endsWith('map.pmtiles')) {
          final rangeHeader = request.headers['Range'];
          if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
            final start = int.parse(rangeHeader.substring(6).replaceAll('-', ''));
            return http.Response.bytes(
              mapBytes.sublist(start),
              206,
              headers: {'Content-Range': 'bytes $start-${mapBytes.length - 1}/${mapBytes.length}'},
            );
          }
          return http.Response.bytes(mapBytes, 200);
        }

        if (url.endsWith('terrain.pmtiles')) {
          return http.Response.bytes(terrainBytes, 200);
        }

        return http.Response('Not Found', 404);
      });

      final service = RegionManagerService(
        customAppSupportDir: customBasePath,
        catalogUrl: 'https://cdn.example/catalog.json',
        httpClient: mockClient,
      );

      await service.fetchCatalog();

      // Pre-seed 50 bytes of map.pmtiles to test resume logic
      final tempDownloadDir = Directory('$customBasePath/regions/alps-east.downloading');
      await tempDownloadDir.create(recursive: true);
      final partialMapFile = File('${tempDownloadDir.path}/map.pmtiles');
      await partialMapFile.writeAsBytes(mapBytes.sublist(0, 50));

      final progressEvents = <RegionDownloadProgress>[];
      final stream = service.downloadRegion('alps-east');
      await for (final progress in stream) {
        progressEvents.add(progress);
      }

      expect(progressEvents.last.status, DownloadStatus.completed);
      expect(progressEvents.last.bytesDownloaded, 350);

      // Verify files in final directory
      final finalRegionDir = Directory('$customBasePath/regions/alps-east');
      expect(await finalRegionDir.exists(), isTrue);

      final downloadedMap = File('${finalRegionDir.path}/map.pmtiles');
      final downloadedTerrain = File('${finalRegionDir.path}/terrain.pmtiles');
      final downloadedMeta = File('${finalRegionDir.path}/meta.json');

      expect(await downloadedMap.exists(), isTrue);
      expect(await downloadedMap.length(), 200);
      expect(await downloadedTerrain.exists(), isTrue);
      expect(await downloadedTerrain.length(), 150);
      expect(await downloadedMeta.exists(), isTrue);

      // Verify temp downloading dir is cleaned up
      expect(await tempDownloadDir.exists(), isFalse);

      // Test getDownloadedRegions
      final downloadedList = await service.getDownloadedRegions();
      expect(downloadedList.length, 1);
      expect(downloadedList.first.id, 'alps-east');
      expect(downloadedList.first.version, '2026-08');
      expect(downloadedList.first.sizeBytes, 350 + (await downloadedMeta.length()));

      // Test storage usage
      final usage = await service.getStorageUsage();
      expect(usage.totalBytes, downloadedList.first.sizeBytes);
      expect(usage.bytesForRegion('alps-east'), downloadedList.first.sizeBytes);
    });

    test('downloadRegion throws and cleans up when SHA-256 does not match', () async {
      final catalogJson = {
        'catalogVersion': 1,
        'generatedAt': '2026-08-01T00:00:00.000Z',
        'regions': [
          {
            'id': 'corrupt-region',
            'name': 'Corrupt',
            'description': 'Checksum mismatch test',
            'bounds': {'north': 48.0, 'south': 46.0, 'west': 12.0, 'east': 14.0},
            'version': '2026-08',
            'generatedAt': '2026-08-01T00:00:00.000Z',
            'files': {
              'map': {
                'url': 'https://cdn.example/corrupt/map.pmtiles',
                'sizeBytes': 150,
                'sha256': '0000000000000000000000000000000000000000000000000000000000000000',
              },
            },
          },
        ],
      };

      final mockClient = MockClient((request) async {
        if (request.url.toString().endsWith('catalog.json')) {
          return http.Response(jsonEncode(catalogJson), 200);
        }
        return http.Response.bytes(List<int>.filled(150, 42), 200);
      });

      final service = RegionManagerService(
        customAppSupportDir: customBasePath,
        catalogUrl: 'https://cdn.example/catalog.json',
        httpClient: mockClient,
      );

      await service.fetchCatalog();

      final events = await service.downloadRegion('corrupt-region').toList();
      expect(events.last.status, DownloadStatus.failed);
      expect(events.last.errorMessage, contains('Checksum verification failed'));

      // Active region should not have been created
      final activeDir = Directory('$customBasePath/regions/corrupt-region');
      expect(await activeDir.exists(), isFalse);
    });

    test('deleteRegion removes files and reclaims storage', () async {
      final regionDir = Directory('$customBasePath/regions/alps-east');
      await regionDir.create(recursive: true);
      final mapFile = File('${regionDir.path}/map.pmtiles');
      await mapFile.writeAsBytes(List<int>.filled(200, 1));

      final service = RegionManagerService(
        customAppSupportDir: customBasePath,
      );

      var downloaded = await service.getDownloadedRegions();
      expect(downloaded.length, 1);

      await service.deleteRegion('alps-east');
      expect(await regionDir.exists(), isFalse);

      downloaded = await service.getDownloadedRegions();
      expect(downloaded.isEmpty, isTrue);

      final usage = await service.getStorageUsage();
      expect(usage.totalBytes, 0);
    });

    test('isLocationCovered, getSuggestedRegions and pre-flight prompt logic', () async {
      final service = RegionManagerService(
        customAppSupportDir: customBasePath,
        httpClient: MockClient((request) async {
          return http.Response(jsonEncode(dummyCatalogJson), 200);
        }),
      );

      await service.fetchCatalog();

      // Initially no regions are downloaded
      expect(await service.isLocationCovered(47.0, 13.0), isFalse);
      expect(await service.shouldShowPreFlightPrompt(47.0, 13.0), isTrue);

      // Suggestions for (47.0, 13.0) -> Alps East
      final suggestions = service.getSuggestedRegions(47.0, 13.0);
      expect(suggestions.length, 1);
      expect(suggestions.first.id, 'alps-east');

      // Dismiss pre-flight prompt for session
      service.dismissPromptForSession(47.0, 13.0);
      // Prompt should now be suppressed for location near dismissed point (<= 50km)
      expect(await service.shouldShowPreFlightPrompt(47.05, 13.05), isFalse);

      // But location > 50km away should still trigger
      expect(await service.shouldShowPreFlightPrompt(45.0, 11.0), isTrue);

      // Reset dismissal
      service.resetPromptDismissal();
      expect(await service.shouldShowPreFlightPrompt(47.0, 13.0), isTrue);

      // Simulate downloaded region
      final regionDir = Directory('$customBasePath/regions/alps-east');
      await regionDir.create(recursive: true);
      final metaFile = File('${regionDir.path}/meta.json');
      await metaFile.writeAsString(jsonEncode({
        'id': 'alps-east',
        'version': '2026-08',
        'downloadedAt': '2026-08-01T00:00:00.000Z',
        'directoryPath': regionDir.path,
        'mapPath': '${regionDir.path}/map.pmtiles',
        'bounds': {
          'north': 48.3,
          'south': 46.2,
          'west': 12.5,
          'east': 16.6,
        },
      }));
      final mapFile = File('${regionDir.path}/map.pmtiles');
      await mapFile.writeAsBytes(List<int>.filled(200, 1));

      // Now location (47.0, 13.0) is covered
      expect(await service.isLocationCovered(47.0, 13.0), isTrue);
      expect(await service.shouldShowPreFlightPrompt(47.0, 13.0), isFalse);

      // Location outside (45.0, 11.0) is NOT covered
      expect(await service.isLocationCovered(45.0, 11.0), isFalse);
      expect(await service.shouldShowPreFlightPrompt(45.0, 11.0), isTrue);
    });
  });
}
