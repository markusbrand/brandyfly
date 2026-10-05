import 'package:brandyfly/domain/thermal/geo_bounds.dart';
import 'package:brandyfly/domain/thermal/thermal_prefetch_planner.dart';
import 'package:brandyfly/domain/thermal/thermal_variant.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('requiredVariants', () {
    test('July -> the four jul variants', () {
      final v = ThermalPrefetchPlanner.requiredVariants(DateTime(2026, 7, 15));
      expect(v.map((e) => e.key), ['jul_all', 'jul_04', 'jul_07', 'jul_10']);
    });

    test('10 August (last month of season) -> jul + oct lookahead', () {
      final v = ThermalPrefetchPlanner.requiredVariants(DateTime(2026, 8, 10));
      expect(v.map((e) => e.key), [
        'jul_all',
        'jul_04',
        'jul_07',
        'jul_10',
        'oct_all',
        'oct_04',
        'oct_07',
        'oct_10',
      ]);
    });

    test('November lookahead wraps to the winter bin', () {
      final v = ThermalPrefetchPlanner.requiredVariants(DateTime(2026, 11, 20));
      expect(v.map((e) => e.season).toSet(), {
        ThermalSeason.oct,
        ThermalSeason.jan,
      });
      expect(
        ThermalPrefetchPlanner.requiredVariants(
          DateTime(2026, 9, 5),
        ).map((e) => e.season).toSet(),
        {ThermalSeason.oct},
      );
    });
  });

  group('tiles', () {
    // Reference counts computed independently (Python, slippy-map formula).
    const alpsEast = GeoBounds(
      west: 12.5,
      south: 46.2,
      east: 16.6,
      north: 48.3,
    );
    const dachstein = GeoBounds(
      west: 13.5,
      south: 47.4,
      east: 13.9,
      north: 47.6,
    );

    test('tile count for known bounding boxes, z0-12', () {
      expect(ThermalPrefetchPlanner.tileCount(alpsEast), 2312);
      expect(ThermalPrefetchPlanner.tileCount(dachstein), 47);
      expect(ThermalPrefetchPlanner.tiles(alpsEast).length, 2312);
    });

    test('enumeration is unique and covers the bbox corners', () {
      final tiles = ThermalPrefetchPlanner.tiles(dachstein).toList();
      expect(tiles.toSet().length, tiles.length);
      expect(tiles.first, const TileCoord(0, 0, 0));
      expect(
        tiles,
        contains(
          TileCoord(12, TileMath.lonToX(13.5, 12), TileMath.latToY(47.6, 12)),
        ),
      );
      expect(
        tiles,
        contains(
          TileCoord(12, TileMath.lonToX(13.9, 12), TileMath.latToY(47.4, 12)),
        ),
      );
      expect(tiles.every((t) => t.z <= 12), isTrue);
    });
  });
}
