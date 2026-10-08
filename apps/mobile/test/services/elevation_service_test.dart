import 'dart:io';
import 'dart:typed_data';

import 'package:brandyfly/domain/thermal/geo_bounds.dart';
import 'package:brandyfly/services/elevation_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/terrain_fixture.dart';

void main() {
  group('WebMercator Projection', () {
    test('projects (0, 0) at zoom 12 to center tile', () {
      final coord = WebMercator.latLonToTilePixel(0.0, 0.0, zoom: 12);
      expect(coord.tileX, equals(2048));
      expect(coord.tileY, equals(2048));
      expect(coord.pixelX, closeTo(0.0, 0.001));
      expect(coord.pixelY, closeTo(0.0, 0.001));
    });

    test('projects Krippenstein region (47.52, 13.69) to correct zoom 12 tile', () {
      final coord = WebMercator.latLonToTilePixel(47.52, 13.69, zoom: 12);
      expect(coord.tileX, equals(2203));
      expect(coord.tileY, equals(1431));
      expect(coord.pixelX, greaterThanOrEqualTo(0.0));
      expect(coord.pixelX, lessThanOrEqualTo(256.0));
      expect(coord.pixelY, greaterThanOrEqualTo(0.0));
      expect(coord.pixelY, lessThanOrEqualTo(256.0));
    });

    test('clamps out-of-bounds latitude and wraps longitude', () {
      final northPole = WebMercator.latLonToTilePixel(90.0, 0.0, zoom: 12);
      expect(northPole.tileY, equals(0));

      final southPole = WebMercator.latLonToTilePixel(-90.0, 0.0, zoom: 12);
      expect(southPole.tileY, equals(4095));

      final wrappedLon = WebMercator.latLonToTilePixel(0.0, 360.0, zoom: 12);
      expect(wrappedLon.tileX, equals(2048));
    });
  });

  group('Terrain-RGB Decoding & Encoding', () {
    test('decodes sea level (0m) correctly', () {
      // 0m = 100000 -> R=1, G=134, B=160
      final elev = TerrainRgb.decodeElevation(1, 134, 160);
      expect(elev, closeTo(0.0, 0.05));
    });

    test('decodes minimum elevation (-10000m) for (0, 0, 0)', () {
      final elev = TerrainRgb.decodeElevation(0, 0, 0);
      expect(elev, closeTo(-10000.0, 0.01));
    });

    test('decodes Mount Everest (~8848.8m)', () {
      // 8848.8m -> (8848.8 + 10000) * 10 = 188488 -> R=2, G=224, B=72
      final (r, g, b) = TerrainRgb.encodeElevation(8848.8);
      expect(r, equals(2));
      expect(g, equals(224));
      expect(b, equals(72));

      final decoded = TerrainRgb.decodeElevation(r, g, b);
      expect(decoded, closeTo(8848.8, 0.1));
    });

    test('roundtrips varied elevation levels with 0.1m precision', () {
      final testElevations = [
        -418.0, // Dead Sea
        0.0,
        150.5,
        500.0,
        1450.2, // Launch site
        2108.0, // Krippenstein summit
        4810.0, // Mont Blanc
      ];

      for (final elev in testElevations) {
        final (r, g, b) = TerrainRgb.encodeElevation(elev);
        final decoded = TerrainRgb.decodeElevation(r, g, b);
        expect(decoded, closeTo(elev, 0.1));
      }
    });
  });

  group('PNG Raster Tile Decoding', () {
    test('decodes RGBA PNG generated from terrain fixture', () {
      final pngBytes = encodeTerrainPng(
        width: 4,
        height: 4,
        elevationAt: (x, y) => (x + y * 4) * 100.0,
      );

      final buffer = PngDecoder.decode(pngBytes);
      expect(buffer.width, equals(4));
      expect(buffer.height, equals(4));
      expect(buffer.pixels.length, equals(4 * 4 * 4));

      // Test pixel (0, 0) -> elevation 0
      final (r0, g0, b0, a0) = buffer.getPixel(0, 0);
      expect(a0, equals(255));
      expect(TerrainRgb.decodeElevation(r0, g0, b0), closeTo(0.0, 0.1));

      // Test pixel (3, 3) -> elevation 1500
      final (r15, g15, b15, _) = buffer.getPixel(3, 3);
      expect(TerrainRgb.decodeElevation(r15, g15, b15), closeTo(1500.0, 0.1));
    });

    test('throws FormatException on corrupted PNG data', () {
      expect(() => PngDecoder.decode(Uint8List(4)), throwsFormatException);
      expect(
        () => PngDecoder.decode(Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8])),
        throwsFormatException,
      );
    });
  });

  group('Bilinear Interpolation', () {
    test('returns exact pixel elevation when sampling pixel center', () {
      final buffer = PngDecoder.decode(
        encodeTerrainPng(
          width: 4,
          height: 4,
          elevationAt: (x, y) => 500.0 + x * 100.0 + y * 200.0,
        ),
      );
      final tile = DecodedTerrainTile.fromRgbaBuffer(buffer);

      // Pixel (1, 1) center is at (1.5, 1.5)
      final elev = TerrainRgb.interpolateElevation(tile, 1.5, 1.5);
      expect(elev, closeTo(500.0 + 100.0 + 200.0, 0.1));
    });

    test('interpolates midpoints between four neighboring pixels accurately', () {
      final buffer = PngDecoder.decode(
        encodeTerrainPng(
          width: 4,
          height: 4,
          elevationAt: (x, y) {
            // (0,0)=100, (1,0)=200, (0,1)=300, (1,1)=400
            if (x == 0 && y == 0) return 100.0;
            if (x == 1 && y == 0) return 200.0;
            if (x == 0 && y == 1) return 300.0;
            if (x == 1 && y == 1) return 400.0;
            return 0.0;
          },
        ),
      );
      final tile = DecodedTerrainTile.fromRgbaBuffer(buffer);

      // Midpoint between pixel centers (0.5, 0.5) and (1.5, 1.5) is at (1.0, 1.0)
      // Expected = (100 + 200 + 300 + 400) / 4 = 250.0
      final midElev = TerrainRgb.interpolateElevation(tile, 1.0, 1.0);
      expect(midElev, closeTo(250.0, 0.2));

      // Horizontal midpoint between (0,0) and (1,0) at y=0.5: (1.0, 0.5)
      // Expected = (100 + 200) / 2 = 150.0
      final horizMid = TerrainRgb.interpolateElevation(tile, 1.0, 0.5);
      expect(horizMid, closeTo(150.0, 0.2));
    });

    test('handles edge clamping smoothly', () {
      final buffer = PngDecoder.decode(
        encodeTerrainPng(
          width: 2,
          height: 2,
          elevationAt: (x, y) => 1000.0,
        ),
      );
      final tile = DecodedTerrainTile.fromRgbaBuffer(buffer);

      expect(TerrainRgb.interpolateElevation(tile, 0.0, 0.0), closeTo(1000.0, 0.1));
      expect(TerrainRgb.interpolateElevation(tile, 2.0, 2.0), closeTo(1000.0, 0.1));
    });
  });

  group('LruTileCache Behavior', () {
    test('evicts least recently used tile when capacity is exceeded', () {
      final cache = LruTileCache<String, int>(3);
      cache.put('a', 1);
      cache.put('b', 2);
      cache.put('c', 3);
      expect(cache.length, equals(3));

      // Access 'a' to make it most recently used
      expect(cache.get('a'), equals(1));

      // Insert 'd' -> 'b' should be evicted (as 'a' was accessed more recently)
      cache.put('d', 4);
      expect(cache.length, equals(3));
      expect(cache.containsKey('b'), isFalse);
      expect(cache.containsKey('a'), isTrue);
      expect(cache.containsKey('c'), isTrue);
      expect(cache.containsKey('d'), isTrue);
    });

    test('maintains hit rates and handles clear/remove', () {
      final cache = LruTileCache<String, String>(8);
      for (int i = 0; i < 8; i++) {
        cache.put('tile_$i', 'val_$i');
      }
      expect(cache.length, equals(8));
      expect(cache.get('tile_0'), equals('val_0'));
      expect(cache.get('missing'), isNull);

      cache.remove('tile_0');
      expect(cache.length, equals(7));
      expect(cache.containsKey('tile_0'), isFalse);

      cache.clear();
      expect(cache.length, equals(0));
    });
  });

  group('ElevationService with Mock PMTiles', () {
    late Directory tempDir;
    late File pmtilesFile;
    late ElevationService elevationService;

    const testZ = 12;
    const testX = 2203;
    const testY = 1431;
    // Bounding box covering Krippenstein
    final testBounds = GeoBounds(
      west: 13.6,
      south: 47.45,
      east: 13.8,
      north: 47.6,
    );

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('elevation_svc_test_');
      final pngBytes = encodeTerrainPng(
        width: 256,
        height: 256,
        elevationAt: (x, y) => 1200.0 + x * 2.0, // ramp from 1200m to 1710m
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
      await elevationService.addTerrainSource('dach_alps', pmtilesFile.path);
    });

    tearDown(() async {
      await elevationService.dispose();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('returns correct ground elevation within covered region', () async {
      final elev = await elevationService.getElevation(47.52, 13.69);
      expect(elev, isNotNull);
      expect(elev!, greaterThan(1200.0));
      expect(elev, lessThan(1720.0));

      // Second query should hit memory cache immediately
      final cachedElev = elevationService.getCachedElevation(47.52, 13.69);
      expect(cachedElev, equals(elev));
    });

    test('returns null for coordinates outside covered region', () async {
      // Coordinate far away (e.g. London 51.5, -0.1)
      final outsideElev = await elevationService.getElevation(51.5, -0.1);
      expect(outsideElev, isNull);
    });

    test('computes elevation profile batch queries', () async {
      final points = [
        (lat: 47.52, lon: 13.69),
        (lat: 47.525, lon: 13.695),
        (lat: 51.5, lon: -0.1), // Outside
      ];

      final profile = await elevationService.getElevationProfile(points);
      expect(profile.length, equals(3));
      expect(profile[0], isNotNull);
      expect(profile[1], isNotNull);
      expect(profile[2], isNull);
    });

    test('removes terrain source and ignores subsequent queries', () async {
      expect(elevationService.hasSource('dach_alps'), isTrue);
      await elevationService.removeTerrainSource('dach_alps');
      expect(elevationService.hasSource('dach_alps'), isFalse);

      final elev = await elevationService.getElevation(47.52, 13.69);
      expect(elev, isNull);
    });
  });
}
