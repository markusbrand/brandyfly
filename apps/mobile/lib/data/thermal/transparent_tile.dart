import 'dart:io';
import 'dart:typed_data';

/// A fully transparent 256x256 RGBA PNG, served for thermal tiles that are
/// unavailable so MapLibre renders "no heatmap" instead of an error.
final Uint8List transparentTilePng = _encodeTransparentPng(256);

Uint8List _encodeTransparentPng(int size) {
  final out = BytesBuilder();
  out.add(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

  final ihdr = ByteData(13)
    ..setUint32(0, size)
    ..setUint32(4, size)
    ..setUint8(8, 8) // bit depth
    ..setUint8(9, 6) // colour type RGBA
    ..setUint8(10, 0)
    ..setUint8(11, 0)
    ..setUint8(12, 0);
  _chunk(out, 'IHDR', ihdr.buffer.asUint8List());

  // Each scanline: filter byte 0 + size * 4 zero bytes.
  final raw = Uint8List(size * (size * 4 + 1));
  _chunk(out, 'IDAT', Uint8List.fromList(ZLibEncoder(level: 9).convert(raw)));
  _chunk(out, 'IEND', Uint8List(0));
  return out.takeBytes();
}

void _chunk(BytesBuilder out, String type, Uint8List data) {
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
