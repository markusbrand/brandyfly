import 'geo_bounds.dart';
import 'kk7_provider.dart';
import 'thermal_variant.dart';
import 'thermal_variant_resolver.dart';

/// Pure planning logic for region thermal prefetch (no I/O).
class ThermalPrefetchPlanner {
  const ThermalPrefetchPlanner._();

  /// Variants that must be stored for a region on local date [date]: the
  /// four time-of-day variants of the current season bin, plus those of the
  /// next season bin during the last month of the current one.
  static List<ThermalVariant> requiredVariants(DateTime date) {
    final season = ThermalVariantResolver.seasonForMonth(date.month);
    return [
      ...ThermalVariant.allTimesOf(season),
      if (ThermalVariantResolver.isLastMonthOfSeason(date.month))
        ...ThermalVariant.allTimesOf(ThermalVariantResolver.nextSeason(season)),
    ];
  }

  /// All XYZ tiles intersecting [bounds] from [minZoom] to [maxZoom].
  static Iterable<TileCoord> tiles(
    GeoBounds bounds, {
    int minZoom = 0,
    int maxZoom = Kk7Provider.maxNativeZoom,
  }) sync* {
    for (var z = minZoom; z <= maxZoom; z++) {
      final r = TileMath.range(bounds, z);
      for (var x = r.minX; x <= r.maxX; x++) {
        for (var y = r.minY; y <= r.maxY; y++) {
          yield TileCoord(z, x, y);
        }
      }
    }
  }

  /// Number of tiles [tiles] yields, computed without enumerating them.
  static int tileCount(
    GeoBounds bounds, {
    int minZoom = 0,
    int maxZoom = Kk7Provider.maxNativeZoom,
  }) {
    var total = 0;
    for (var z = minZoom; z <= maxZoom; z++) {
      final r = TileMath.range(bounds, z);
      total += (r.maxX - r.minX + 1) * (r.maxY - r.minY + 1);
    }
    return total;
  }
}
