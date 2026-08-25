import 'dart:io';
import 'dart:typed_data';

import 'package:brandyfly/models/ui_config.dart';
import 'package:brandyfly/services/map_tile_service.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MapTileStyleConfig', () {
    test('returns correct URL templates and attributions for each MapWidgetStyle', () {
      final topo = MapTileStyleConfig.forStyle(MapWidgetStyle.topoContours);
      expect(topo.urlTemplate, contains('tile.opentopomap.org'));
      expect(topo.attribution, contains('OpenTopoMap'));
      expect(topo.subdomains, contains('a'));

      final topoNoContours = MapTileStyleConfig.forStyle(
        MapWidgetStyle.topoContours,
        showContours: false,
      );
      expect(topoNoContours.urlTemplate, contains('tile.openstreetmap.org'));
      expect(topoNoContours.label, contains('OpenStreetMap Standard'));

      final osm = MapTileStyleConfig.forStyle(MapWidgetStyle.minimalVector);
      expect(osm.urlTemplate, contains('tile.openstreetmap.org'));
      expect(osm.attribution, contains('OpenStreetMap'));

      final dark = MapTileStyleConfig.forStyle(MapWidgetStyle.thermalHeatmap);
      expect(dark.urlTemplate, contains('cartocdn.com'));
      expect(dark.attribution, contains('CARTO'));

      final relief = MapTileStyleConfig.forStyle(MapWidgetStyle.satelliteTerrain);
      expect(relief.urlTemplate, contains('tile.opentopomap.org'));
      expect(relief.attribution, contains('OpenTopoMap'));
    });
  });

  group('BrandyFlyTileCacheService', () {
    late Directory tempDir;
    late BrandyFlyTileCacheService cacheService;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('brandyfly_tile_test_');
      cacheService = BrandyFlyTileCacheService(customCacheDir: tempDir.path);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('isSupported returns true', () {
      expect(cacheService.isSupported, isTrue);
    });

    test('getTile returns null for missing tile', () async {
      final tile = await cacheService.getTile('https://tile.openstreetmap.org/10/500/300.png');
      expect(tile, isNull);
    });

    test('putTile stores tile and getTile retrieves bytes and metadata correctly', () async {
      const url = 'https://tile.openstreetmap.org/12/2150/1420.png';
      final dummyBytes = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
      final now = DateTime.utc(2026, 8, 25, 20, 0, 0);
      final staleTime = now.add(const Duration(days: 7));
      final metadata = CachedMapTileMetadata(
        staleAt: staleTime,
        lastModified: now,
        etag: '"test-etag-123"',
      );

      await cacheService.putTile(url: url, metadata: metadata, bytes: dummyBytes);

      expect(await cacheService.isTileCached(url), isTrue);
      expect(await cacheService.getCachedTileCount(), 1);
      expect(await cacheService.getCacheSizeBytes(), greaterThan(dummyBytes.length));

      final retrieved = await cacheService.getTile(url);
      expect(retrieved, isNotNull);
      expect(retrieved!.bytes, equals(dummyBytes));
      expect(retrieved.metadata.lastModified, equals(now));
      expect(retrieved.metadata.etag, equals('"test-etag-123"'));
      expect(retrieved.metadata.staleAt, equals(staleTime));
    });

    test('clearCache deletes all cached tile files', () async {
      final dummyBytes = Uint8List.fromList([10, 20, 30]);
      final meta = CachedMapTileMetadata(
        staleAt: DateTime.utc(2026, 8, 25, 20, 0, 0).add(const Duration(days: 7)),
        lastModified: null,
        etag: null,
      );

      await cacheService.putTile(
        url: 'https://tile.openstreetmap.org/1/1/1.png',
        metadata: meta,
        bytes: dummyBytes,
      );
      await cacheService.putTile(
        url: 'https://tile.openstreetmap.org/1/1/2.png',
        metadata: meta,
        bytes: dummyBytes,
      );

      expect(await cacheService.getCachedTileCount(), 2);

      await cacheService.clearCache();
      expect(await cacheService.getCachedTileCount(), 0);
      expect(await cacheService.getCacheSizeBytes(), 0);
    });

    test('getTile gracefully handles corrupted tile files by returning null', () async {
      const url = 'https://tile.openstreetmap.org/corrupt.png';
      final filename = cacheService.getFilenameForUrl(url);
      final file = File('${tempDir.path}/$filename');
      await file.writeAsBytes([1, 2]); // Incomplete / corrupted header

      final result = await cacheService.getTile(url);
      expect(result, isNull);
    });
  });

  group('BrandyFlyTileProvider', () {
    test('initializes with default User-Agent and silenceExceptions', () {
      final provider = BrandyFlyTileProvider();
      expect(provider.headers['User-Agent'], equals(MapTileStyleConfig.defaultUserAgent));
      expect(provider.silenceExceptions, isTrue);
      expect(provider.attemptDecodeOfHttpErrorResponses, isTrue);
    });

    test('respects custom User-Agent and custom headers', () {
      final provider = BrandyFlyTileProvider(
        userAgent: 'CustomAgent/2.0',
        headers: {'X-Custom-Header': 'CustomValue'},
      );
      expect(provider.headers['User-Agent'], equals('CustomAgent/2.0'));
      expect(provider.headers['X-Custom-Header'], equals('CustomValue'));
    });
  });
}
