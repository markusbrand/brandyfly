import 'dart:convert';
import 'dart:io';

import 'package:brandyfly/services/pmtiles_reader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PMTiles Hilbert Math', () {
    test('converts z=0 and z=1 coordinates correctly', () {
      expect(PMTilesReader.zxyToTileId(0, 0, 0), equals(0));
      expect(PMTilesReader.zxyToTileId(1, 0, 0), equals(1));
      expect(PMTilesReader.zxyToTileId(1, 0, 1), equals(2));
      expect(PMTilesReader.zxyToTileId(1, 1, 1), equals(3));
      expect(PMTilesReader.zxyToTileId(1, 1, 0), equals(4));

      expect(PMTilesReader.tileIdToZxy(0), equals((0, 0, 0)));
      expect(PMTilesReader.tileIdToZxy(1), equals((1, 0, 0)));
      expect(PMTilesReader.tileIdToZxy(2), equals((1, 0, 1)));
      expect(PMTilesReader.tileIdToZxy(3), equals((1, 1, 1)));
      expect(PMTilesReader.tileIdToZxy(4), equals((1, 1, 0)));
    });

    test('roundtrips all coordinates for zoom levels 0 through 4', () {
      for (int z = 0; z <= 4; z++) {
        final maxCoord = 1 << z;
        for (int x = 0; x < maxCoord; x++) {
          for (int y = 0; y < maxCoord; y++) {
            final tileId = PMTilesReader.zxyToTileId(z, x, y);
            final (rz, rx, ry) = PMTilesReader.tileIdToZxy(tileId);
            expect(rz, equals(z));
            expect(rx, equals(x));
            expect(ry, equals(y));
          }
        }
      }
    });

    test('rejects invalid zoom and out-of-bounds coordinates', () {
      expect(() => PMTilesReader.zxyToTileId(-1, 0, 0), throwsArgumentError);
      expect(() => PMTilesReader.zxyToTileId(27, 0, 0), throwsArgumentError);
      expect(() => PMTilesReader.zxyToTileId(2, 4, 0), throwsArgumentError);
      expect(() => PMTilesReader.zxyToTileId(2, 0, 4), throwsArgumentError);
      expect(() => PMTilesReader.tileIdToZxy(-1), throwsArgumentError);
    });
  });

  group('PMTilesReader with global_overview.pmtiles', () {
    late File overviewFile;

    setUp(() {
      overviewFile = File('assets/map_data/global_overview.pmtiles');
      if (!overviewFile.existsSync()) {
        overviewFile = File('apps/mobile/assets/map_data/global_overview.pmtiles');
      }
    });

    test('reads header correctly', () async {
      final reader = await PMTilesReader.open(overviewFile);
      try {
        final header = reader.header;
        expect(header.version, equals(3));
        expect(header.minZoom, equals(0));
        expect(header.maxZoom, equals(6));
        expect(header.numAddressedTiles, equals(1));
        expect(header.numTileEntries, equals(1));
        expect(header.tileType, equals(PMTilesTileType.mvt));
        expect(header.clustered, isTrue);
        expect(header.minLon, closeTo(-180.0, 0.001));
        expect(header.minLat, closeTo(-85.0, 0.001));
        expect(header.maxLon, closeTo(180.0, 0.001));
        expect(header.maxLat, closeTo(85.0, 0.001));
      } finally {
        await reader.close();
      }
    });

    test('extracts metadata JSON', () async {
      final reader = await PMTilesReader.open(overviewFile);
      try {
        final metadataStr = await reader.getMetadataJson();
        final metadata = jsonDecode(metadataStr) as Map<String, dynamic>;
        expect(metadata['name'], equals('BrandyFly Global Overview'));
        expect(metadata['format'], equals('pbf'));
      } finally {
        await reader.close();
      }
    });

    test('extracts tile payload at (0, 0, 0)', () async {
      final reader = await PMTilesReader.open(overviewFile);
      try {
        final tileBytes = await reader.getTile(0, 0, 0);
        expect(tileBytes, isNotNull);
        expect(tileBytes!.length, greaterThan(0));

        // Payload is gzip-compressed MVT layer
        final decompressed = gzip.decode(tileBytes);
        expect(decompressed, equals([0x1a, 0x04, 0x74, 0x65, 0x73, 0x74])); // \x1a\x04test

        // Non-existent tile at zoom 1 returns null
        final missingTile = await reader.getTile(1, 0, 0);
        expect(missingTile, isNull);

        // Tile outside zoom range returns null
        final outOfBoundsTile = await reader.getTile(10, 0, 0);
        expect(outOfBoundsTile, isNull);
      } finally {
        await reader.close();
      }
    });
  });

  group('PMTilesReader Error Handling', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('pmtiles_err_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('throws FileSystemException when file does not exist', () async {
      final missingFile = File('${tempDir.path}/nonexistent.pmtiles');
      expect(
        () => PMTilesReader.open(missingFile),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('throws FormatException when file is smaller than 127 bytes', () async {
      final shortFile = File('${tempDir.path}/short.pmtiles');
      await shortFile.writeAsBytes(List.filled(100, 0));
      expect(
        () => PMTilesReader.open(shortFile),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException when magic identifier is invalid', () async {
      final corruptFile = File('${tempDir.path}/corrupt_magic.pmtiles');
      final bytes = List.filled(127, 0);
      bytes.setRange(0, 7, utf8.encode('NOTPMT!'));
      await corruptFile.writeAsBytes(bytes);
      expect(
        () => PMTilesReader.open(corruptFile),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException when version is not 3', () async {
      final oldVersionFile = File('${tempDir.path}/v2.pmtiles');
      final bytes = List.filled(127, 0);
      bytes.setRange(0, 7, utf8.encode('PMTiles'));
      bytes[7] = 2; // version 2
      await oldVersionFile.writeAsBytes(bytes);
      expect(
        () => PMTilesReader.open(oldVersionFile),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws StateError when querying after close', () async {
      final overviewFile = File('assets/map_data/global_overview.pmtiles').existsSync()
          ? File('assets/map_data/global_overview.pmtiles')
          : File('apps/mobile/assets/map_data/global_overview.pmtiles');
      final reader = await PMTilesReader.open(overviewFile);
      await reader.close();
      expect(reader.isClosed, isTrue);
      expect(() => reader.getTile(0, 0, 0), throwsStateError);
      expect(() => reader.getMetadataJson(), throwsStateError);
    });
  });
}
