import 'thermal_variant.dart';

/// Single source of truth for the thermal.kk7.ch thermal probability tiles.
///
/// Licence: CC BY-NC-SA 4.0 (non-commercial, attribution, share-alike).
/// Tiles are fetched unmodified by each device; BrandyFly never redistributes
/// them. Every remote request must carry the `src` tracking parameter.
class Kk7Provider {
  const Kk7Provider._();

  /// Production tile host.
  static const String defaultBaseUrl = 'https://thermal.kk7.ch';

  /// Value of the mandatory `src` tracking query parameter.
  static const String sourceTag = 'brandyfly';

  /// Highest zoom level KK7 renders natively; MapLibre overzooms beyond it.
  static const int maxNativeZoom = 12;

  /// KK7 tiles are 256 px PNGs in TMS row orientation.
  static const int tileSize = 256;
  static const bool isTms = true;

  static const String attributionText =
      'Thermal map © thermal.kk7.ch, CC BY-NC-SA 4.0';
  static const String attributionUrl = 'https://thermal.kk7.ch/';

  /// Converts an XYZ (slippy map) row to the TMS row used by KK7.
  static int xyzToTmsY(int z, int y) => (1 << z) - 1 - y;

  /// Builds the remote KK7 URL for an XYZ-addressed tile of [variant].
  static Uri tileUri(
    ThermalVariant variant,
    int z,
    int x,
    int y, {
    String baseUrl = defaultBaseUrl,
  }) {
    final tmsY = xyzToTmsY(z, y);
    return Uri.parse(
      '$baseUrl/tiles/${variant.layerId}/$z/$x/$tmsY.png?src=$sourceTag',
    );
  }

  /// URL template for clients that talk to KK7 directly (web build), using
  /// MapLibre's `scheme: tms` to flip rows.
  static String directTemplate(
    ThermalVariant variant, {
    String baseUrl = defaultBaseUrl,
  }) => '$baseUrl/tiles/${variant.layerId}/{z}/{x}/{y}.png?src=$sourceTag';
}
