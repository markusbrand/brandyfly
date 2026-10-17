import 'dart:convert';
import 'dart:io';

import 'package:brandyfly/data/thermal/region_bounds_provider.dart';
import 'package:brandyfly/domain/thermal/geo_bounds.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tmp;
  late File mapFile;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('region_bounds_test_');
    mapFile = File('${tmp.path}/map.pmtiles');
    await mapFile.writeAsBytes(List.filled(130, 0));
  });

  tearDown(() async {
    if (tmp.existsSync()) {
      await tmp.delete(recursive: true);
    }
  });

  test('resolves bounds from catalogBounds provider when valid', () async {
    final provider = RegionBoundsProvider(
      regionsBasePath: () async => tmp.path,
      catalogBounds: (id) =>
          const GeoBounds(west: 10.0, south: 45.0, east: 11.0, north: 46.0),
    );

    final bounds = await provider.boundsFor(
      'test-region',
      tmp.path,
    );

    expect(bounds, isNotNull);
    expect(bounds!.west, 10.0);
    expect(bounds.south, 45.0);
    expect(bounds.east, 11.0);
    expect(bounds.north, 46.0);
  });

  test('resolves bounds from meta.json fallback when catalog is missing', () async {
    final metaFile = File('${tmp.path}/meta.json');
    await metaFile.writeAsString(
      jsonEncode({
        'bounds': {
          'west': 12.0,
          'south': 46.5,
          'east': 13.5,
          'north': 47.5,
        },
      }),
    );

    final provider = RegionBoundsProvider(
      regionsBasePath: () async => tmp.path,
      catalogBounds: (id) => null,
    );

    final bounds = await provider.boundsFor(
      'test-region',
      tmp.path,
    );

    expect(bounds, isNotNull);
    expect(bounds!.west, 12.0);
    expect(bounds.south, 46.5);
    expect(bounds.east, 13.5);
    expect(bounds.north, 47.5);
  });

  test('returns null when no bounds source is valid and map is not a valid PMTiles archive', () async {
    final provider = RegionBoundsProvider(
      regionsBasePath: () async => tmp.path,
      catalogBounds: (id) => null,
    );

    final bounds = await provider.boundsFor(
      'empty-region',
      tmp.path,
    );

    expect(bounds, isNull);
  });
}
