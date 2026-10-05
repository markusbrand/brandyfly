import 'dart:ui' as ui;
import 'dart:io';
import 'dart:typed_data';

import 'package:brandyfly/data/thermal/region_bounds_provider.dart';
import 'package:brandyfly/data/thermal/thermal_tile_store.dart';
import 'package:brandyfly/data/thermal/transparent_tile.dart';
import 'package:brandyfly/domain/thermal/geo_bounds.dart';
import 'package:brandyfly/domain/thermal/thermal_variant.dart';

import 'package:flutter_test/flutter_test.dart';

import '../support/pmtiles_fixture.dart';

void main() {
  late Directory tmp;
  final jul07 = ThermalVariant(ThermalSeason.jul, ThermalTimeOfDay.midday);

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('thermal_store_test');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  group('RegionBoundsProvider', () {
    const alpsEast = GeoBounds(
      west: 12.5,
      south: 46.2,
      east: 16.6,
      north: 48.3,
    );

    test('reads bounds from the PMTiles header of each region', () async {
      await writeHeaderOnlyPmtiles('${tmp.path}/regions/alps-east', alpsEast);
      // Directory without map archive and an in-progress download are ignored.
      await Directory('${tmp.path}/regions/empty').create(recursive: true);
      await writeHeaderOnlyPmtiles(
        '${tmp.path}/regions/alps-west.downloading',
        alpsEast,
      );

      final provider = RegionBoundsProvider(
        regionsBasePath: () async => '${tmp.path}/regions',
      );
      final regions = await provider.listRegions();
      expect(regions, hasLength(1));
      expect(regions.single.id, 'alps-east');
      final b = regions.single.bounds;
      expect(b.west, closeTo(12.5, 1e-6));
      expect(b.south, closeTo(46.2, 1e-6));
      expect(b.east, closeTo(16.6, 1e-6));
      expect(b.north, closeTo(48.3, 1e-6));
    });

    test('prefers catalog bounds when available', () async {
      await writeHeaderOnlyPmtiles('${tmp.path}/regions/alps-east', alpsEast);
      const catalog = GeoBounds(west: 12, south: 46, east: 17, north: 49);
      final provider = RegionBoundsProvider(
        regionsBasePath: () async => '${tmp.path}/regions',
        catalogBounds: (id) => id == 'alps-east' ? catalog : null,
      );
      expect((await provider.listRegions()).single.bounds, catalog);
    });

    test('missing regions directory yields no regions', () async {
      final provider = RegionBoundsProvider(
        regionsBasePath: () async => '${tmp.path}/nope',
      );
      expect(await provider.listRegions(), isEmpty);
    });
  });

  group('ThermalTileStore', () {
    test('cache miss, hit and empty marker', () async {
      final store = ThermalTileStore(appSupportDir: tmp.path);
      expect(await store.readFromCache(jul07, 10, 1, 2), isNull);

      await store.writeToCache(jul07, 10, 1, 2, Uint8List.fromList([1, 2, 3]));
      expect(await store.readFromCache(jul07, 10, 1, 2), [1, 2, 3]);
      expect(
        File('${tmp.path}/thermal_cache/jul_07/10/1/2.png').existsSync(),
        isTrue,
      );
      expect(
        File('${tmp.path}/thermal_cache/jul_07/10/1/2.png.tmp').existsSync(),
        isFalse,
      );

      await store.writeToCache(jul07, 10, 1, 3, Uint8List(0));
      final marker = await store.readFromCache(jul07, 10, 1, 3);
      expect(marker, isNotNull);
      expect(marker, isEmpty);
    });

    test('reads tiles prefetched for any region', () async {
      final store = ThermalTileStore(appSupportDir: tmp.path);
      expect(await store.readFromRegions(jul07, 8, 4, 5), isNull);
      await ThermalTileStore.writeAtomic(
        File('${tmp.path}/regions/r1/thermals/jul_07/8/4/5.png'),
        [9, 9],
      );
      store.invalidateRegionList();
      expect(await store.readFromRegions(jul07, 8, 4, 5), [9, 9]);
    });

    test('LRU eviction keeps the cache below its cap', () async {
      final store = ThermalTileStore(
        appSupportDir: tmp.path,
        maxCacheBytes: 1000,
      );
      final payload = Uint8List(300);
      for (var i = 0; i < 3; i++) {
        await store.writeToCache(jul07, 10, i, 0, payload);
        // Make modification times strictly increasing.
        await File(
          '${tmp.path}/thermal_cache/jul_07/10/$i/0.png',
        ).setLastModified(DateTime(2026, 1, 1, 0, i));
      }
      // Touch tile 0 so it becomes most recently used.
      await File(
        '${tmp.path}/thermal_cache/jul_07/10/0/0.png',
      ).setLastModified(DateTime(2026, 1, 1, 1));
      await store.writeToCache(jul07, 10, 3, 0, payload); // 1200 > 1000

      expect(await store.cacheSizeBytes(), lessThanOrEqualTo(800));
      expect(await store.readFromCache(jul07, 10, 1, 0), isNull); // oldest
      expect(await store.readFromCache(jul07, 10, 0, 0), isNotNull);
      expect(await store.readFromCache(jul07, 10, 3, 0), isNotNull);
    });
  });

  testWidgets('transparent tile is a valid, fully transparent 256x256 PNG', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(transparentTilePng);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 256);
      expect(frame.image.height, 256);
      final rgba = await frame.image.toByteData();
      expect(rgba!.buffer.asUint8List().every((b) => b == 0), isTrue);
    });
  });
}
