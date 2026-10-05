import 'dart:math' as math;

/// Geographic bounding box in WGS84 degrees.
class GeoBounds {
  const GeoBounds({
    required this.west,
    required this.south,
    required this.east,
    required this.north,
  });

  final double west;
  final double south;
  final double east;
  final double north;

  bool get isValid =>
      west < east && south < north && south >= -90 && north <= 90;

  @override
  bool operator ==(Object other) =>
      other is GeoBounds &&
      other.west == west &&
      other.south == south &&
      other.east == east &&
      other.north == north;

  @override
  int get hashCode => Object.hash(west, south, east, north);

  @override
  String toString() => 'GeoBounds($west, $south, $east, $north)';
}

/// Web-Mercator XYZ tile address.
class TileCoord {
  const TileCoord(this.z, this.x, this.y);

  final int z;
  final int x;
  final int y;

  @override
  bool operator ==(Object other) =>
      other is TileCoord && other.z == z && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(z, x, y);

  @override
  String toString() => '$z/$x/$y';
}

/// Slippy-map tile math (XYZ, rows counted from the north).
class TileMath {
  const TileMath._();

  static const double maxMercatorLat = 85.0511287798;

  static int lonToX(double lon, int z) {
    final n = 1 << z;
    final x = ((lon + 180.0) / 360.0 * n).floor();
    return x.clamp(0, n - 1);
  }

  static int latToY(double lat, int z) {
    final n = 1 << z;
    final clamped = lat.clamp(-maxMercatorLat, maxMercatorLat);
    final rad = clamped * math.pi / 180.0;
    final y =
        ((1.0 - math.log(math.tan(rad) + 1.0 / math.cos(rad)) / math.pi) /
                2.0 *
                n)
            .floor();
    return y.clamp(0, n - 1);
  }

  /// Inclusive tile range covering [bounds] at zoom [z].
  static ({int minX, int maxX, int minY, int maxY}) range(
    GeoBounds bounds,
    int z,
  ) => (
    minX: lonToX(bounds.west, z),
    maxX: lonToX(bounds.east, z),
    minY: latToY(bounds.north, z),
    maxY: latToY(bounds.south, z),
  );
}
