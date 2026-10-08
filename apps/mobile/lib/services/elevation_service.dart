import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'pmtiles_reader.dart';

/// Web Mercator coordinate projection for DEM tile and sub-pixel queries.
class WebMercator {
  const WebMercator._();

  static const double maxLatitude = 85.0511287798066;
  static const double minLatitude = -85.0511287798066;

  /// Projects latitude and longitude to tile (x, y) and in-tile pixel coordinates (px, py).
  static ({int tileX, int tileY, double pixelX, double pixelY}) latLonToTilePixel(
    double lat,
    double lon, {
    int zoom = 12,
    int tileSize = 256,
  }) {
    final clampedLat = lat.clamp(minLatitude, maxLatitude);
    double normalizedLon = lon;
    while (normalizedLon < -180.0) {
      normalizedLon += 360.0;
    }
    while (normalizedLon > 180.0) {
      normalizedLon -= 360.0;
    }

    final n = 1 << zoom;
    final x = (normalizedLon + 180.0) / 360.0 * n;
    final latRad = clampedLat * math.pi / 180.0;
    final y = (1.0 -
            math.log(math.tan(latRad) + 1.0 / math.cos(latRad)) / math.pi) /
        2.0 *
        n;

    final tileX = x.floor().clamp(0, n - 1);
    final tileY = y.floor().clamp(0, n - 1);

    final pixelX = (x - tileX) * tileSize;
    final pixelY = (y - tileY) * tileSize;

    return (
      tileX: tileX,
      tileY: tileY,
      pixelX: pixelX.clamp(0.0, tileSize.toDouble()),
      pixelY: pixelY.clamp(0.0, tileSize.toDouble()),
    );
  }
}

/// Raw RGBA image buffer decoded from raster tile bytes.
class RgbaBuffer {
  const RgbaBuffer({
    required this.width,
    required this.height,
    required this.pixels,
  });

  final int width;
  final int height;

  /// Packed RGBA bytes of length `width * height * 4`.
  final Uint8List pixels;

  /// Returns (R, G, B, A) at pixel coordinate (x, y).
  (int r, int g, int b, int a) getPixel(int x, int y) {
    final idx = (y * width + x) * 4;
    return (
      pixels[idx],
      pixels[idx + 1],
      pixels[idx + 2],
      pixels[idx + 3],
    );
  }
}

/// Decoder for 8-bit truecolor (RGB / RGBA) PNG raster tiles.
class PngDecoder {
  const PngDecoder._();

  static const List<int> _pngSignature = [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
  ];

  /// Decodes raw PNG bytes into an [RgbaBuffer].
  static RgbaBuffer decode(Uint8List bytes) {
    if (bytes.length < 8) {
      throw const FormatException('PNG data is too short');
    }
    for (int i = 0; i < 8; i++) {
      if (bytes[i] != _pngSignature[i]) {
        throw const FormatException('Invalid PNG signature');
      }
    }

    final byteData = ByteData.sublistView(bytes);
    int offset = 8;
    int? width;
    int? height;
    int? bitDepth;
    int? colorType;
    final idatChunks = <Uint8List>[];

    while (offset < bytes.length) {
      if (offset + 8 > bytes.length) break;
      final chunkLength = byteData.getUint32(offset);
      offset += 4;
      final chunkType = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      offset += 4;

      final chunkDataEnd = offset + chunkLength;
      if (chunkDataEnd > bytes.length) {
        throw const FormatException('Truncated PNG chunk');
      }

      final chunkData = bytes.sublist(offset, chunkDataEnd);
      offset = chunkDataEnd + 4; // skip CRC

      if (chunkType == 'IHDR') {
        final ihdr = ByteData.sublistView(chunkData);
        width = ihdr.getUint32(0);
        height = ihdr.getUint32(4);
        bitDepth = ihdr.getUint8(8);
        colorType = ihdr.getUint8(9);
      } else if (chunkType == 'IDAT') {
        idatChunks.add(chunkData);
      } else if (chunkType == 'IEND') {
        break;
      }
    }

    if (width == null || height == null || bitDepth == null || colorType == null) {
      throw const FormatException('Missing IHDR chunk in PNG');
    }
    if (bitDepth != 8) {
      throw FormatException('Unsupported PNG bit depth: $bitDepth (expected 8)');
    }
    if (colorType != 2 && colorType != 6 && colorType != 0) {
      throw FormatException('Unsupported PNG color type: $colorType');
    }

    final idatCombined = BytesBuilder();
    for (final c in idatChunks) {
      idatCombined.add(c);
    }

    final decompressed = Uint8List.fromList(
      zlib.decode(idatCombined.takeBytes()),
    );

    final bytesPerPixel = switch (colorType) {
      2 => 3, // RGB
      6 => 4, // RGBA
      0 => 1, // Grayscale
      _ => 4,
    };

    final scanlineLength = 1 + width * bytesPerPixel;
    final expectedTotal = height * scanlineLength;
    if (decompressed.length < expectedTotal) {
      throw FormatException(
        'Decompressed IDAT too short: ${decompressed.length} < $expectedTotal',
      );
    }

    final outPixels = Uint8List(width * height * 4);
    final prevRow = Uint8List(width * bytesPerPixel);
    final currRow = Uint8List(width * bytesPerPixel);

    int inOffset = 0;
    for (int y = 0; y < height; y++) {
      final filterType = decompressed[inOffset++];
      final rawScanline = decompressed.sublist(
        inOffset,
        inOffset + width * bytesPerPixel,
      );
      inOffset += width * bytesPerPixel;

      _unfilterScanline(
        filterType,
        rawScanline,
        prevRow,
        currRow,
        bytesPerPixel,
      );

      // Copy currRow to outPixels as RGBA
      final rowStartOut = y * width * 4;
      for (int x = 0; x < width; x++) {
        final outIdx = rowStartOut + x * 4;
        final inIdx = x * bytesPerPixel;
        if (bytesPerPixel == 4) {
          outPixels[outIdx] = currRow[inIdx];
          outPixels[outIdx + 1] = currRow[inIdx + 1];
          outPixels[outIdx + 2] = currRow[inIdx + 2];
          outPixels[outIdx + 3] = currRow[inIdx + 3];
        } else if (bytesPerPixel == 3) {
          outPixels[outIdx] = currRow[inIdx];
          outPixels[outIdx + 1] = currRow[inIdx + 1];
          outPixels[outIdx + 2] = currRow[inIdx + 2];
          outPixels[outIdx + 3] = 255;
        } else {
          final g = currRow[inIdx];
          outPixels[outIdx] = g;
          outPixels[outIdx + 1] = g;
          outPixels[outIdx + 2] = g;
          outPixels[outIdx + 3] = 255;
        }
      }

      prevRow.setAll(0, currRow);
    }

    return RgbaBuffer(width: width, height: height, pixels: outPixels);
  }

  static void _unfilterScanline(
    int filterType,
    Uint8List raw,
    Uint8List prev,
    Uint8List curr,
    int bpp,
  ) {
    final len = raw.length;
    switch (filterType) {
      case 0: // None
        curr.setRange(0, len, raw);
        break;
      case 1: // Sub
        for (int i = 0; i < len; i++) {
          final a = i >= bpp ? curr[i - bpp] : 0;
          curr[i] = (raw[i] + a) & 0xFF;
        }
        break;
      case 2: // Up
        for (int i = 0; i < len; i++) {
          final b = prev[i];
          curr[i] = (raw[i] + b) & 0xFF;
        }
        break;
      case 3: // Average
        for (int i = 0; i < len; i++) {
          final a = i >= bpp ? curr[i - bpp] : 0;
          final b = prev[i];
          curr[i] = (raw[i] + ((a + b) >> 1)) & 0xFF;
        }
        break;
      case 4: // Paeth
        for (int i = 0; i < len; i++) {
          final a = i >= bpp ? curr[i - bpp] : 0;
          final b = prev[i];
          final c = i >= bpp ? prev[i - bpp] : 0;
          curr[i] = (raw[i] + _paeth(a, b, c)) & 0xFF;
        }
        break;
      default:
        throw FormatException('Unsupported PNG filter type: $filterType');
    }
  }

  static int _paeth(int a, int b, int c) {
    final p = a + b - c;
    final pa = (p - a).abs();
    final pb = (p - b).abs();
    final pc = (p - c).abs();
    if (pa <= pb && pa <= pc) return a;
    if (pb <= pc) return b;
    return c;
  }
}

/// Decodes Mapbox Terrain-RGB pixel colors to elevation in meters and performs bilinear interpolation.
class TerrainRgb {
  const TerrainRgb._();

  /// Mapbox Terrain-RGB formula:
  /// `elevation = -10000 + ((R * 65536 + G * 256 + B) * 0.1)`
  static double decodeElevation(int r, int g, int b) {
    return -10000.0 + ((r * 65536 + g * 256 + b) * 0.1);
  }

  /// Inverse mapping: encodes an elevation value into (R, G, B) components.
  static (int r, int g, int b) encodeElevation(double elevation) {
    final val = ((elevation + 10000.0) * 10.0).round().clamp(0, 16777215);
    final r = (val >> 16) & 0xFF;
    final g = (val >> 8) & 0xFF;
    final b = val & 0xFF;
    return (r, g, b);
  }

  /// Bilinear interpolation between the four nearest pixel centers on [tile] for (px, py).
  static double interpolateElevation(
    DecodedTerrainTile tile,
    double px,
    double py,
  ) {
    if (tile.width == 0 || tile.height == 0) return 0.0;

    // Pixel centers are at (x + 0.5, y + 0.5)
    final u = px - 0.5;
    final v = py - 0.5;

    final x0 = u.floor().clamp(0, tile.width - 1);
    final y0 = v.floor().clamp(0, tile.height - 1);
    final x1 = (x0 + 1).clamp(0, tile.width - 1);
    final y1 = (y0 + 1).clamp(0, tile.height - 1);

    final dx = (x1 == x0) ? 0.0 : (u - x0).clamp(0.0, 1.0);
    final dy = (y1 == y0) ? 0.0 : (v - y0).clamp(0.0, 1.0);

    final e00 = tile.elevationAt(x0, y0);
    final e10 = tile.elevationAt(x1, y0);
    final e01 = tile.elevationAt(x0, y1);
    final e11 = tile.elevationAt(x1, y1);

    return e00 * (1.0 - dx) * (1.0 - dy) +
        e10 * dx * (1.0 - dy) +
        e01 * (1.0 - dx) * dy +
        e11 * dx * dy;
  }
}

/// Decoded in-memory elevation grid for one 256x256 terrain tile.
class DecodedTerrainTile {
  DecodedTerrainTile({
    required this.width,
    required this.height,
    required this.elevations,
  });

  factory DecodedTerrainTile.fromRgbaBuffer(RgbaBuffer buffer) {
    final count = buffer.width * buffer.height;
    final elevs = Float32List(count);
    for (int i = 0; i < count; i++) {
      final idx = i * 4;
      final r = buffer.pixels[idx];
      final g = buffer.pixels[idx + 1];
      final b = buffer.pixels[idx + 2];
      elevs[i] = TerrainRgb.decodeElevation(r, g, b);
    }
    return DecodedTerrainTile(
      width: buffer.width,
      height: buffer.height,
      elevations: elevs,
    );
  }

  final int width;
  final int height;
  final Float32List elevations;

  double elevationAt(int x, int y) {
    return elevations[y * width + x];
  }
}

/// Least-recently-used in-memory cache with fixed [capacity].
class LruTileCache<K, V> {
  LruTileCache(this.capacity);

  final int capacity;
  final _map = <K, V>{};

  V? get(K key) {
    final value = _map.remove(key);
    if (value != null) {
      _map[key] = value;
      return value;
    }
    return null;
  }

  void put(K key, V value) {
    _map.remove(key);
    if (_map.length >= capacity) {
      final oldestKey = _map.keys.first;
      _map.remove(oldestKey);
    }
    _map[key] = value;
  }

  bool containsKey(K key) => _map.containsKey(key);

  int get length => _map.length;

  V? remove(K key) => _map.remove(key);

  void clear() => _map.clear();
}

/// A registered terrain PMTiles archive source.
class TerrainSource {
  TerrainSource({
    required this.regionId,
    required this.pmtilesPath,
    required this.reader,
    required this.minLon,
    required this.minLat,
    required this.maxLon,
    required this.maxLat,
    this.ownsReader = true,
  });

  final String regionId;
  final String pmtilesPath;
  final PMTilesReader reader;
  final double minLon;
  final double minLat;
  final double maxLon;
  final double maxLat;
  final bool ownsReader;

  bool containsLocation(double lat, double lon) {
    return lon >= minLon && lon <= maxLon && lat >= minLat && lat <= maxLat;
  }
}

/// Service that decodes ground elevation in meters from local Copernicus DEM terrain-RGB PMTiles.
class ElevationService {
  ElevationService({this.cacheCapacity = 8})
      : _tileCache = LruTileCache<String, DecodedTerrainTile>(cacheCapacity);

  /// Zoom level 12 matches the ~30m Copernicus GLO-30 resolution.
  static const int demZoom = 12;

  final int cacheCapacity;
  final LruTileCache<String, DecodedTerrainTile> _tileCache;
  final Map<String, TerrainSource> _sources = {};

  LruTileCache<String, DecodedTerrainTile> get tileCache => _tileCache;

  /// Registers a terrain PMTiles file on disk.
  Future<void> addTerrainSource(String regionId, String pmtilesPath) async {
    final file = File(pmtilesPath);
    if (!await file.exists()) {
      throw FileSystemException('Terrain PMTiles not found', pmtilesPath);
    }
    final reader = await PMTilesReader.open(file);
    _sources[regionId] = TerrainSource(
      regionId: regionId,
      pmtilesPath: pmtilesPath,
      reader: reader,
      minLon: reader.header.minLon,
      minLat: reader.header.minLat,
      maxLon: reader.header.maxLon,
      maxLat: reader.header.maxLat,
      ownsReader: true,
    );
  }

  /// Registers a terrain source using an existing [PMTilesReader] (useful for testing or embedded readers).
  void registerSourceReader(
    String regionId,
    PMTilesReader reader, {
    double? minLon,
    double? minLat,
    double? maxLon,
    double? maxLat,
  }) {
    _sources[regionId] = TerrainSource(
      regionId: regionId,
      pmtilesPath: '',
      reader: reader,
      minLon: minLon ?? reader.header.minLon,
      minLat: minLat ?? reader.header.minLat,
      maxLon: maxLon ?? reader.header.maxLon,
      maxLat: maxLat ?? reader.header.maxLat,
      ownsReader: false,
    );
  }

  /// Removes a terrain source when a region is deleted or unmounted.
  Future<void> removeTerrainSource(String regionId) async {
    final source = _sources.remove(regionId);
    if (source != null && source.ownsReader) {
      await source.reader.close();
    }
  }

  bool hasSource(String regionId) => _sources.containsKey(regionId);

  /// Returns cached ground elevation immediately if the corresponding tile is in memory.
  double? getCachedElevation(double lat, double lon) {
    final coord = WebMercator.latLonToTilePixel(lat, lon, zoom: demZoom);
    for (final source in _sources.values) {
      if (!source.containsLocation(lat, lon)) continue;
      final cacheKey = '${source.regionId}:$demZoom:${coord.tileX}:${coord.tileY}';
      final tile = _tileCache.get(cacheKey);
      if (tile != null) {
        return TerrainRgb.interpolateElevation(
          tile,
          coord.pixelX,
          coord.pixelY,
        );
      }
    }
    return null;
  }

  /// Returns the ground elevation in meters at [lat], [lon], or `null` if not covered by any source.
  Future<double?> getElevation(double lat, double lon) async {
    final cached = getCachedElevation(lat, lon);
    if (cached != null) return cached;

    final coord = WebMercator.latLonToTilePixel(lat, lon, zoom: demZoom);

    for (final source in _sources.values) {
      if (!source.containsLocation(lat, lon)) continue;
      final cacheKey = '${source.regionId}:$demZoom:${coord.tileX}:${coord.tileY}';

      final cachedTile = _tileCache.get(cacheKey);
      if (cachedTile != null) {
        return TerrainRgb.interpolateElevation(
          cachedTile,
          coord.pixelX,
          coord.pixelY,
        );
      }

      final rawBytes = await source.reader.getTile(
        demZoom,
        coord.tileX,
        coord.tileY,
      );
      if (rawBytes == null) continue;

      Uint8List pngBytes = rawBytes;
      // Handle gzip compressed tile payload
      if (pngBytes.length >= 2 && pngBytes[0] == 0x1f && pngBytes[1] == 0x8b) {
        pngBytes = Uint8List.fromList(gzip.decode(pngBytes));
      }

      final rgbaBuffer = PngDecoder.decode(pngBytes);
      final tile = DecodedTerrainTile.fromRgbaBuffer(rgbaBuffer);
      _tileCache.put(cacheKey, tile);

      return TerrainRgb.interpolateElevation(
        tile,
        coord.pixelX,
        coord.pixelY,
      );
    }

    return null;
  }

  /// Batch query for elevation profiles along a flight track or route.
  Future<List<double?>> getElevationProfile(
    List<({double lat, double lon})> points,
  ) async {
    final results = <double?>[];
    for (final pt in points) {
      results.add(await getElevation(pt.lat, pt.lon));
    }
    return results;
  }

  /// Closes all managed readers and clears the tile cache.
  Future<void> dispose() async {
    _tileCache.clear();
    for (final source in _sources.values) {
      if (source.ownsReader) {
        await source.reader.close();
      }
    }
    _sources.clear();
  }
}
