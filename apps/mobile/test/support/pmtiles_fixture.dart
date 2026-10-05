import 'dart:io';
import 'dart:typed_data';

import 'package:brandyfly/domain/thermal/geo_bounds.dart';

/// Writes a minimal (header-only) PMTiles v3 archive with [bounds] to
/// `<regionDir>/map.pmtiles`. Enough for code that only reads the header.
Future<File> writeHeaderOnlyPmtiles(String regionDir, GeoBounds bounds) async {
  final bytes = Uint8List(127);
  bytes.setRange(0, 7, 'PMTiles'.codeUnits);
  bytes[7] = 3;
  final data = ByteData.sublistView(bytes);
  bytes[99] = 1; // mvt
  bytes[100] = 0;
  bytes[101] = 14;
  data.setInt32(102, (bounds.west * 1e7).round(), Endian.little);
  data.setInt32(106, (bounds.south * 1e7).round(), Endian.little);
  data.setInt32(110, (bounds.east * 1e7).round(), Endian.little);
  data.setInt32(114, (bounds.north * 1e7).round(), Endian.little);
  final file = File('$regionDir/map.pmtiles');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes, flush: true);
  return file;
}
