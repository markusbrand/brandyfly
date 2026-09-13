import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Compression format used for PMTiles directories and tile payloads.
enum PMTilesCompression {
  unknown,
  none,
  gzip,
  brotli,
  zstd,
}

/// PMTiles tile type indicator.
enum PMTilesTileType {
  unknown,
  mvt,
  png,
  jpeg,
  webp,
  avif,
}

/// Header parsed from the first 127 bytes of a PMTiles v3 archive.
class PMTilesHeader {
  const PMTilesHeader({
    required this.version,
    required this.rootDirOffset,
    required this.rootDirBytes,
    required this.jsonMetadataOffset,
    required this.jsonMetadataBytes,
    required this.leafDirsOffset,
    required this.leafDirsBytes,
    required this.tileDataOffset,
    required this.tileDataBytes,
    required this.numAddressedTiles,
    required this.numTileEntries,
    required this.numTileContents,
    required this.clustered,
    required this.internalCompression,
    required this.tileCompression,
    required this.tileType,
    required this.minZoom,
    required this.maxZoom,
    required this.minLon,
    required this.minLat,
    required this.maxLon,
    required this.maxLat,
    required this.centerZoom,
    required this.centerLon,
    required this.centerLat,
  });

  final int version;
  final int rootDirOffset;
  final int rootDirBytes;
  final int jsonMetadataOffset;
  final int jsonMetadataBytes;
  final int leafDirsOffset;
  final int leafDirsBytes;
  final int tileDataOffset;
  final int tileDataBytes;
  final int numAddressedTiles;
  final int numTileEntries;
  final int numTileContents;
  final bool clustered;
  final PMTilesCompression internalCompression;
  final PMTilesCompression tileCompression;
  final PMTilesTileType tileType;
  final int minZoom;
  final int maxZoom;
  final double minLon;
  final double minLat;
  final double maxLon;
  final double maxLat;
  final int centerZoom;
  final double centerLon;
  final double centerLat;

  /// Decodes a 127-byte header from [bytes].
  factory PMTilesHeader.fromBytes(Uint8List bytes) {
    if (bytes.length < 127) {
      throw const FormatException('PMTiles header must be at least 127 bytes');
    }

    final magic = ascii.decode(bytes.sublist(0, 7));
    if (magic != 'PMTiles') {
      throw FormatException('Invalid PMTiles magic identifier: "$magic"');
    }

    final version = bytes[7];
    if (version != 3) {
      throw FormatException('Unsupported PMTiles version: $version (expected 3)');
    }

    final data = ByteData.sublistView(bytes);

    return PMTilesHeader(
      version: version,
      rootDirOffset: data.getUint64(8, Endian.little),
      rootDirBytes: data.getUint64(16, Endian.little),
      jsonMetadataOffset: data.getUint64(24, Endian.little),
      jsonMetadataBytes: data.getUint64(32, Endian.little),
      leafDirsOffset: data.getUint64(40, Endian.little),
      leafDirsBytes: data.getUint64(48, Endian.little),
      tileDataOffset: data.getUint64(56, Endian.little),
      tileDataBytes: data.getUint64(64, Endian.little),
      numAddressedTiles: data.getUint64(72, Endian.little),
      numTileEntries: data.getUint64(80, Endian.little),
      numTileContents: data.getUint64(88, Endian.little),
      clustered: bytes[96] == 1,
      internalCompression: _decodeCompression(bytes[97]),
      tileCompression: _decodeCompression(bytes[98]),
      tileType: _decodeTileType(bytes[99]),
      minZoom: bytes[100],
      maxZoom: bytes[101],
      minLon: data.getInt32(102, Endian.little) / 10000000.0,
      minLat: data.getInt32(106, Endian.little) / 10000000.0,
      maxLon: data.getInt32(110, Endian.little) / 10000000.0,
      maxLat: data.getInt32(114, Endian.little) / 10000000.0,
      centerZoom: bytes[118],
      centerLon: data.getInt32(119, Endian.little) / 10000000.0,
      centerLat: data.getInt32(123, Endian.little) / 10000000.0,
    );
  }

  static PMTilesCompression _decodeCompression(int val) {
    switch (val) {
      case 1:
        return PMTilesCompression.none;
      case 2:
        return PMTilesCompression.gzip;
      case 3:
        return PMTilesCompression.brotli;
      case 4:
        return PMTilesCompression.zstd;
      default:
        return PMTilesCompression.unknown;
    }
  }

  static PMTilesTileType _decodeTileType(int val) {
    switch (val) {
      case 1:
        return PMTilesTileType.mvt;
      case 2:
        return PMTilesTileType.png;
      case 3:
        return PMTilesTileType.jpeg;
      case 4:
        return PMTilesTileType.webp;
      case 5:
        return PMTilesTileType.avif;
      default:
        return PMTilesTileType.unknown;
    }
  }
}

/// PMTiles directory entry.
///
/// If [runLength] == 0, this entry points to a leaf directory with offset
/// relative to `leafDirsOffset`.
/// If [runLength] > 0, this entry represents a tile or contiguous run of tiles
/// with offset relative to `tileDataOffset`.
class PMTilesEntry {
  const PMTilesEntry({
    required this.tileId,
    required this.offset,
    required this.length,
    required this.runLength,
  });

  final int tileId;
  final int offset;
  final int length;
  final int runLength;

  @override
  String toString() =>
      'PMTilesEntry(tileId: $tileId, offset: $offset, length: $length, runLength: $runLength)';
}

/// Helper for reading varints sequentially from a byte buffer.
class _ByteReader {
  _ByteReader(this.bytes);

  final Uint8List bytes;
  int pos = 0;

  int readVarint() {
    int res = 0;
    int shift = 0;
    while (pos < bytes.length) {
      final b = bytes[pos++];
      res |= (b & 0x7F) << shift;
      if ((b & 0x80) == 0) {
        return res;
      }
      shift += 7;
      if (shift > 63) {
        throw const FormatException('Varint exceeds 64-bit integer range');
      }
    }
    throw const FormatException('Unexpected end of varint stream');
  }
}

/// Seek-based random-access reader for PMTiles v3 archives.
class PMTilesReader {
  PMTilesReader._(this._file, this._header);

  final RandomAccessFile _file;
  final PMTilesHeader _header;
  final Map<String, List<PMTilesEntry>> _directoryCache = {};
  bool _isClosed = false;

  PMTilesHeader get header => _header;
  bool get isClosed => _isClosed;

  /// Opens a PMTiles archive from [file].
  static Future<PMTilesReader> open(File file) async {
    if (!await file.exists()) {
      throw FileSystemException('PMTiles file does not exist', file.path);
    }
    final length = await file.length();
    if (length < 127) {
      throw const FormatException('File is too small to be a PMTiles archive');
    }

    final raf = await file.open(mode: FileMode.read);
    try {
      final headerBytes = await raf.read(127);
      final header = PMTilesHeader.fromBytes(Uint8List.fromList(headerBytes));
      return PMTilesReader._(raf, header);
    } catch (_) {
      await raf.close();
      rethrow;
    }
  }

  /// Opens a PMTiles archive from file path [path].
  static Future<PMTilesReader> openPath(String path) {
    return open(File(path));
  }

  /// Closes the underlying file handle and cleans up resources.
  Future<void> close() async {
    if (_isClosed) return;
    _isClosed = true;
    _directoryCache.clear();
    try {
      _file.closeSync();
    } catch (_) {}
  }

  /// Reads and decompresses the JSON metadata section.
  Future<String> getMetadataJson() async {
    if (_isClosed) throw StateError('PMTilesReader is closed');
    if (_header.jsonMetadataBytes == 0) return '{}';

    _file.setPositionSync(_header.jsonMetadataOffset);
    final raw = _file.readSync(_header.jsonMetadataBytes);
    final decompressed = _decompress(
      Uint8List.fromList(raw),
      _header.internalCompression,
    );
    return utf8.decode(decompressed);
  }

  /// Looks up and returns the raw tile payload bytes for [z], [x], [y].
  ///
  /// Returns `null` if the tile is not present in the archive or if [z] is
  /// outside the zoom range.
  Future<Uint8List?> getTile(int z, int x, int y) async {
    if (_isClosed) throw StateError('PMTilesReader is closed');
    if (z < _header.minZoom || z > _header.maxZoom) {
      return null;
    }

    final tileId = zxyToTileId(z, x, y);
    int dirOffset = _header.rootDirOffset;
    int dirLength = _header.rootDirBytes;

    for (int depth = 0; depth <= 3; depth++) {
      final dir = await _getOrLoadDirectory(dirOffset, dirLength);
      final entry = findTile(dir, tileId);
      if (entry == null) {
        return null;
      }

      if (entry.runLength > 0) {
        // Tile payload found!
        final tileAbsOffset = _header.tileDataOffset + entry.offset;
        _file.setPositionSync(tileAbsOffset);
        final raw = _file.readSync(entry.length);
        return Uint8List.fromList(raw);
      }

      // Leaf directory pointer
      dirOffset = _header.leafDirsOffset + entry.offset;
      dirLength = entry.length;
    }

    return null;
  }

  /// Loads and caches a directory section at [offset] with length [length].
  Future<List<PMTilesEntry>> _getOrLoadDirectory(int offset, int length) async {
    final cacheKey = '$offset:$length';
    final cached = _directoryCache[cacheKey];
    if (cached != null) {
      return cached;
    }

    _file.setPositionSync(offset);
    final rawBytes = _file.readSync(length);
    final decompressed = _decompress(
      Uint8List.fromList(rawBytes),
      _header.internalCompression,
    );
    final entries = deserializeDirectory(decompressed);
    _directoryCache[cacheKey] = entries;
    return entries;
  }

  /// Decompresses [data] according to [compression].
  ///
  /// Automatically checks for GZIP magic (`0x1F 0x8B`) regardless of the flag
  /// to handle archives with compression values set to none or unknown.
  static Uint8List _decompress(
    Uint8List data,
    PMTilesCompression compression,
  ) {
    if (data.isEmpty) return data;
    final isGzip = data.length >= 2 && data[0] == 0x1f && data[1] == 0x8b;
    if (isGzip || compression == PMTilesCompression.gzip) {
      return Uint8List.fromList(gzip.decode(data));
    }
    return data;
  }

  /// Converts tile coordinate (Z, X, Y) to a 64-bit Hilbert TileID.
  static int zxyToTileId(int z, int x, int y) {
    if (z < 0 || z > 26) {
      throw ArgumentError('Tile zoom level $z exceeds max limit (26)');
    }
    final maxCoord = 1 << z;
    if (x < 0 || x >= maxCoord || y < 0 || y >= maxCoord) {
      throw ArgumentError('Tile coordinate ($x, $y) outside bounds for zoom $z');
    }

    int acc = ((1 << z) * (1 << z) - 1) ~/ 3;
    int a = z - 1;
    int tx = x;
    int ty = y;

    for (int s = a >= 0 ? 1 << a : 0; s > 0; s >>= 1) {
      final rx = tx & s;
      final ry = ty & s;
      acc += ((3 * rx) ^ ry) * (1 << a);
      final rotated = _rotate(s, tx, ty, rx, ry);
      tx = rotated[0];
      ty = rotated[1];
      a--;
    }
    return acc;
  }

  /// Converts a Hilbert TileID to tile coordinate (Z, X, Y).
  static (int z, int x, int y) tileIdToZxy(int tileId) {
    if (tileId < 0) {
      throw ArgumentError('Tile ID cannot be negative');
    }

    final c = 3 * tileId + 1;
    final z = (c.bitLength - 1) >> 1;
    if (z > 26) {
      throw ArgumentError('Tile zoom level exceeds max limit (26)');
    }

    final acc = ((1 << z) * (1 << z) - 1) ~/ 3;
    int t = tileId - acc;
    int x = 0;
    int y = 0;
    final n = 1 << z;

    for (int s = 1; s < n; s <<= 1) {
      final rx = s & (t ~/ 2);
      final ry = s & (t ^ rx);
      final rotated = _rotate(s, x, y, rx, ry);
      x = rotated[0];
      y = rotated[1];
      t = t ~/ 2;
      x += rx;
      y += ry;
    }

    return (z, x, y);
  }

  static List<int> _rotate(int n, int x, int y, int rx, int ry) {
    if (ry == 0) {
      if (rx != 0) {
        return [n - 1 - y, n - 1 - x];
      }
      return [y, x];
    }
    return [x, y];
  }

  /// Binary searches [entries] for [tileId] or matching run length / leaf directory.
  static PMTilesEntry? findTile(List<PMTilesEntry> entries, int tileId) {
    if (entries.isEmpty) return null;

    int m = 0;
    int n = entries.length - 1;
    while (m <= n) {
      final k = (n + m) >> 1;
      final cmp = tileId - entries[k].tileId;
      if (cmp > 0) {
        m = k + 1;
      } else if (cmp < 0) {
        n = k - 1;
      } else {
        return entries[k];
      }
    }

    if (n >= 0) {
      if (entries[n].runLength == 0) {
        return entries[n];
      }
      if (tileId - entries[n].tileId < entries[n].runLength) {
        return entries[n];
      }
    }
    return null;
  }

  /// Deserializes decompressed PMTiles directory bytes into a list of [PMTilesEntry].
  static List<PMTilesEntry> deserializeDirectory(Uint8List decompressedBytes) {
    final reader = _ByteReader(decompressedBytes);
    final numEntries = reader.readVarint();
    if (numEntries == 0) return const [];

    int lastId = 0;
    final tileIds = <int>[];
    for (int i = 0; i < numEntries; i++) {
      final delta = reader.readVarint();
      lastId += delta;
      tileIds.add(lastId);
    }

    final runLengths = <int>[];
    for (int i = 0; i < numEntries; i++) {
      runLengths.add(reader.readVarint());
    }

    final lengths = <int>[];
    for (int i = 0; i < numEntries; i++) {
      lengths.add(reader.readVarint());
    }

    final offsets = <int>[];
    for (int i = 0; i < numEntries; i++) {
      final v = reader.readVarint();
      if (v == 0) {
        if (i == 0) {
          offsets.add(0);
        } else {
          offsets.add(offsets[i - 1] + lengths[i - 1]);
        }
      } else {
        offsets.add(v - 1);
      }
    }

    final entries = <PMTilesEntry>[];
    for (int i = 0; i < numEntries; i++) {
      entries.add(PMTilesEntry(
        tileId: tileIds[i],
        offset: offsets[i],
        length: lengths[i],
        runLength: runLengths[i],
      ));
    }
    return entries;
  }
}
