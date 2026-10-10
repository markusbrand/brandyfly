import 'dart:convert';

import '../../../../models/flight_model.dart';
import '../../../../models/lat_lng.dart';
import 'vario_track_palette.dart';

/// Per-point encoded coordinates and colors of one (growing) track, so full
/// GeoJSON rebuilds of long tracks only join cached strings instead of
/// formatting every number again.
class TrackEncodingCache {
  final List<String> _coords = [];
  final List<String> _colors = [];
  List<FlightPoint>? _source;
  DateTime? _firstTs;

  int get length => _coords.length;

  /// Encodes points added since the last call; starts over when [points] is
  /// a different or reset track.
  void sync(List<FlightPoint> points) {
    final first = points.isEmpty ? null : points.first.timestamp;
    if (!identical(points, _source) ||
        first != _firstTs ||
        points.length < _coords.length) {
      _coords.clear();
      _colors.clear();
      _source = points;
      _firstTs = first;
    }
    for (var i = _coords.length; i < points.length; i++) {
      final p = points[i];
      _coords.add(
        '[${p.longitude.toStringAsFixed(6)},${p.latitude.toStringAsFixed(6)}]',
      );
      _colors.add(VarioTrackPalette.hexFor(p.vario));
    }
  }

  String coord(int i) => _coords[i];
  String color(int i) => _colors[i];
}

/// Pure GeoJSON builders for the native flight overlay layers.
abstract final class TrackGeoJson {
  static const String empty = '{"type":"FeatureCollection","features":[]}';

  /// Index of the first point inside the history window ending at the last
  /// point's timestamp. [historyMinutes] 0 = full flight (index 0).
  static int windowStartIndex(List<FlightPoint> points, int historyMinutes) {
    if (points.isEmpty || historyMinutes <= 0) return 0;
    final cutoff = points.last.timestamp.subtract(
      Duration(minutes: historyMinutes),
    );
    // Binary search for the first timestamp >= cutoff (points are ordered).
    var lo = 0;
    var hi = points.length - 1;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (points[mid].timestamp.isBefore(cutoff)) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  static void _coord(StringBuffer b, double lon, double lat) {
    b
      ..write('[')
      ..write(lon.toStringAsFixed(6))
      ..write(',')
      ..write(lat.toStringAsFixed(6))
      ..write(']');
  }

  /// Vario-colored segments for points `[from, to)`: segment `i` joins
  /// `points[i-1]` and `points[i]` and takes the color of `points[i].vario`.
  /// Consecutive segments with the same quantized color are merged into one
  /// LineString feature with property `c` (`#rrggbb`).
  static String segments(
    List<FlightPoint> points,
    int from,
    int to, {
    TrackEncodingCache? cache,
  }) {
    final start = from < 0 ? 0 : from;
    final end = to > points.length ? points.length : to;
    if (end - start < 2) return empty;
    if (cache != null) {
      cache.sync(points);
      return _segmentsCached(cache, start, end);
    }
    final b = StringBuffer('{"type":"FeatureCollection","features":[');
    var first = true;
    String? color;
    void close() {
      if (color != null) b.write(']}}');
    }

    for (var i = start + 1; i < end; i++) {
      final c = VarioTrackPalette.hexFor(points[i].vario);
      if (c != color) {
        close();
        if (!first) b.write(',');
        first = false;
        color = c;
        b
          ..write('{"type":"Feature","properties":{"c":"')
          ..write(c)
          ..write('"},"geometry":{"type":"LineString","coordinates":[');
        final p = points[i - 1];
        _coord(b, p.longitude, p.latitude);
      }
      b.write(',');
      _coord(b, points[i].longitude, points[i].latitude);
    }
    close();
    b.write(']}');
    return b.toString();
  }

  static String _segmentsCached(TrackEncodingCache c, int start, int end) {
    final b = StringBuffer('{"type":"FeatureCollection","features":[');
    String? color;
    for (var i = start + 1; i < end; i++) {
      final col = c.color(i);
      if (col != color) {
        if (color != null) b.write(']}},');
        color = col;
        b
          ..write('{"type":"Feature","properties":{"c":"')
          ..write(col)
          ..write('"},"geometry":{"type":"LineString","coordinates":[')
          ..write(c.coord(i - 1));
      }
      b
        ..write(',')
        ..write(c.coord(i));
    }
    if (color != null) b.write(']}}');
    b.write(']}');
    return b.toString();
  }

  /// One muted LineString through points `[0, toInclusive]`.
  static String tail(
    List<FlightPoint> points,
    int toInclusive, {
    TrackEncodingCache? cache,
  }) {
    final end = toInclusive >= points.length ? points.length - 1 : toInclusive;
    if (end < 1) return empty;
    if (cache != null) {
      cache.sync(points);
      final b = StringBuffer(
        '{"type":"FeatureCollection","features":[{"type":"Feature",'
        '"properties":{},"geometry":{"type":"LineString","coordinates":[',
      );
      for (var i = 0; i <= end; i++) {
        if (i > 0) b.write(',');
        b.write(cache.coord(i));
      }
      b.write(']}}]}');
      return b.toString();
    }
    final b = StringBuffer(
      '{"type":"FeatureCollection","features":[{"type":"Feature",'
      '"properties":{},"geometry":{"type":"LineString","coordinates":[',
    );
    for (var i = 0; i <= end; i++) {
      if (i > 0) b.write(',');
      _coord(b, points[i].longitude, points[i].latitude);
    }
    b.write(']}}]}');
    return b.toString();
  }

  /// Closed polygon feature collection.
  static String polygon(List<LatLng> ring) {
    if (ring.length < 3) return empty;
    final coords = [
      for (final p in ring) [p.longitude, p.latitude],
      [ring.first.longitude, ring.first.latitude],
    ];
    return jsonEncode({
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'properties': <String, Object?>{},
          'geometry': {
            'type': 'Polygon',
            'coordinates': [coords],
          },
        },
      ],
    });
  }

  /// Single point with rotation property `r` (degrees from north).
  static String point(LatLng p, double rotationDeg) {
    final b = StringBuffer(
      '{"type":"FeatureCollection","features":[{"type":"Feature",'
      '"properties":{"r":',
    )..write(rotationDeg.toStringAsFixed(1));
    b.write('},"geometry":{"type":"Point","coordinates":');
    _coord(b, p.longitude, p.latitude);
    b.write('}}]}');
    return b.toString();
  }
}
