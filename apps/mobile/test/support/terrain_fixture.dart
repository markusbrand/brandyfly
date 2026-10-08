import 'dart:io';
import 'dart:typed_data';

import 'package:brandyfly/domain/thermal/geo_bounds.dart';
import 'package:brandyfly/services/elevation_service.dart';
import 'package:brandyfly/services/pmtiles_reader.dart';

/// Helper to write varint (LEB128) into [BytesBuilder].
void _writeVarint(BytesBuilder builder, int value) {
  int v = value;
  while (v >= 0x80) {
    builder.addByte((v & 0x7F) | 0x80);
    v >>= 7;
  }
  builder.addByte(v & 0x7F);
}

/// Encodes an RGBA PNG with given dimensions and elevation calculation function.
Uint8List encodeTerrainPng({
  required int width,
  required int height,
  required double Function(int x, int y) elevationAt,
}) {
  final out = BytesBuilder();
  out.add(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

  final ihdr = ByteData(13)
    ..setUint32(0, width)
    ..setUint32(4, height)
    ..setUint8(8, 8) // bit depth
    ..setUint8(9, 6) // RGBA
    ..setUint8(10, 0)
    ..setUint8(11, 0)
    ..setUint8(12, 0);
  _writePngChunk(out, 'IHDR', ihdr.buffer.asUint8List());

  final rawScanlines = BytesBuilder();
  for (int y = 0; y < height; y++) {
    rawScanlines.addByte(0); // Filter type: None
    for (int x = 0; x < width; x++) {
      final elev = elevationAt(x, y);
      final (r, g, b) = TerrainRgb.encodeElevation(elev);
      rawScanlines.addByte(r);
      rawScanlines.addByte(g);
      rawScanlines.addByte(b);
      rawScanlines.addByte(255); // Alpha
    }
  }

  final idat = zlib.encode(rawScanlines.takeBytes());
  _writePngChunk(out, 'IDAT', Uint8List.fromList(idat));
  _writePngChunk(out, 'IEND', Uint8List(0));

  return out.takeBytes();
}

void _writePngChunk(BytesBuilder out, String type, Uint8List data) {
  final len = ByteData(4)..setUint32(0, data.length);
  out.add(len.buffer.asUint8List());
  final typeAndData = Uint8List(4 + data.length)
    ..setAll(0, type.codeUnits)
    ..setAll(4, data);
  out.add(typeAndData);
  final crc = ByteData(4)..setUint32(0, _crc32(typeAndData));
  out.add(crc.buffer.asUint8List());
}

final List<int> _crcTable = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc32(Uint8List bytes) {
  var c = 0xFFFFFFFF;
  for (final b in bytes) {
    c = _crcTable[(c ^ b) & 0xFF] ^ (c >> 8);
  }
  return (c ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}

/// Serializes a single-entry PMTiles directory.
Uint8List serializeSingleEntryDirectory({
  required int tileId,
  required int tileLength,
}) {
  final b = BytesBuilder();
  _writeVarint(b, 1); // numEntries = 1
  _writeVarint(b, tileId); // delta
  _writeVarint(b, 1); // runLength = 1
  _writeVarint(b, tileLength); // length
  _writeVarint(b, 0); // offset = 0
  return b.takeBytes();
}

/// Writes a valid PMTiles v3 archive with one terrain-RGB tile at [z], [x], [y].
Future<File> writeTerrainPmtiles(
  String filePath, {
  required int z,
  required int x,
  required int y,
  required Uint8List pngBytes,
  required GeoBounds bounds,
}) async {
  final tileId = PMTilesReader.zxyToTileId(z, x, y);
  final rootDirRaw = serializeSingleEntryDirectory(
    tileId: tileId,
    tileLength: pngBytes.length,
  );
  // Root dir with compression none
  final rootDir = rootDirRaw;

  final rootDirOffset = 127;
  final rootDirBytes = rootDir.length;
  final jsonMetaOffset = rootDirOffset + rootDirBytes;
  final jsonMetaBytes = 0;
  final leafDirsOffset = jsonMetaOffset + jsonMetaBytes;
  final leafDirsBytes = 0;
  final tileDataOffset = leafDirsOffset + leafDirsBytes;
  final tileDataBytes = pngBytes.length;

  final header = Uint8List(127);
  header.setRange(0, 7, 'PMTiles'.codeUnits);
  header[7] = 3; // version 3
  final bd = ByteData.sublistView(header);

  // rootDirOffset (8 bytes uint64 little-endian)
  bd.setUint32(8, rootDirOffset, Endian.little);
  bd.setUint32(12, 0, Endian.little);
  bd.setUint32(16, rootDirBytes, Endian.little);
  bd.setUint32(20, 0, Endian.little);

  // jsonMeta
  bd.setUint32(24, jsonMetaOffset, Endian.little);
  bd.setUint32(28, 0, Endian.little);
  bd.setUint32(32, jsonMetaBytes, Endian.little);
  bd.setUint32(36, 0, Endian.little);

  // leafDirs
  bd.setUint32(40, leafDirsOffset, Endian.little);
  bd.setUint32(44, 0, Endian.little);
  bd.setUint32(48, leafDirsBytes, Endian.little);
  bd.setUint32(52, 0, Endian.little);

  // tileData
  bd.setUint32(56, tileDataOffset, Endian.little);
  bd.setUint32(60, 0, Endian.little);
  bd.setUint32(64, tileDataBytes, Endian.little);
  bd.setUint32(68, 0, Endian.little);

  // numAddressedTiles, numTileEntries, numTileContents
  bd.setUint32(72, 1, Endian.little); // addressed
  bd.setUint32(76, 0, Endian.little);
  bd.setUint32(80, 1, Endian.little); // entries
  bd.setUint32(84, 0, Endian.little);
  bd.setUint32(88, 1, Endian.little); // contents
  bd.setUint32(92, 0, Endian.little);

  header[96] = 1; // clustered
  header[97] = 1; // internalCompression = none
  header[98] = 1; // tileCompression = none
  header[99] = 2; // tileType = png
  header[100] = z; // minZoom
  header[101] = z; // maxZoom

  bd.setInt32(102, (bounds.west * 1e7).round(), Endian.little);
  bd.setInt32(106, (bounds.south * 1e7).round(), Endian.little);
  bd.setInt32(110, (bounds.east * 1e7).round(), Endian.little);
  bd.setInt32(114, (bounds.north * 1e7).round(), Endian.little);
  header[118] = z; // centerZoom
  bd.setInt32(119, (((bounds.west + bounds.east) / 2) * 1e7).round(), Endian.little);
  bd.setInt32(123, (((bounds.south + bounds.north) / 2) * 1e7).round(), Endian.little);

  final file = File(filePath);
  await file.parent.create(recursive: true);
  final raf = await file.open(mode: FileMode.write);
  await raf.writeFrom(header);
  await raf.writeFrom(rootDir);
  await raf.writeFrom(pngBytes);
  await raf.close();

  return file;
}
