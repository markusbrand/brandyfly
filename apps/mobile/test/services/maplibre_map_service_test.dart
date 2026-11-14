import 'dart:convert';
import 'dart:io';

import 'package:brandyfly/models/lat_lng.dart';
import 'package:brandyfly/services/maplibre_map_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  List<int> buildValidPmtilesBytes(int size) {
    final bytes = List<int>.filled(size, 0);
    const magic = <int>[0x50, 0x4d, 0x54, 0x69, 0x6c, 0x65, 0x73, 0x03];
    for (var i = 0; i < magic.length; i++) {
      bytes[i] = magic[i];
    }
    return bytes;
  }

  group('MapLibreMapService', () {
    late Directory tempDir;
    late MapLibreMapService service;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('brandyfly_maplibre_test_');
      service = MapLibreMapService(customAppSupportDir: tempDir.path);
    });

    tearDown(() async {
      service.dispose();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });


    test('regionExists returns false when region directory or files do not exist', () async {
      final exists = await service.regionExists('austria_dachstein');
      expect(exists, isFalse);
    });

    test('regionExists returns false for 499-byte stub and true for valid PMTiles v3 archive', () async {
      final regionDir = Directory('${tempDir.path}/regions/austria_dachstein');
      await regionDir.create(recursive: true);
      final mapFile = File('${regionDir.path}/map.pmtiles');
      await mapFile.writeAsBytes(buildValidPmtilesBytes(499));

      expect(await service.regionExists('austria_dachstein'), isFalse);

      await mapFile.writeAsBytes(buildValidPmtilesBytes(4096));
      final exists = await service.regionExists('austria_dachstein');
      expect(exists, isTrue);
    });

    test('buildStyleJson self-heals 499-byte stub region directory and falls back', () async {
      final stubDir = Directory('${tempDir.path}/regions/alps-east');
      await stubDir.create(recursive: true);
      final mapFile = File('${stubDir.path}/map.pmtiles');
      await mapFile.writeAsBytes(buildValidPmtilesBytes(499));

      final styleJson = await service.buildStyleJson(regionId: 'alps-east');
      expect(service.isFallbackActive, isTrue);
      expect(service.activeRegionId, isNull);
      expect(await stubDir.exists(), isFalse);
      expect(styleJson, isNotEmpty);
    });

    test('buildStyleJson returns fallback style when region does not exist', () async {
      final styleJson = await service.buildStyleJson(regionId: 'non_existent_region');
      expect(service.isFallbackActive, isTrue);
      expect(service.tileServer.isRunning, isTrue);

      final styleMap = jsonDecode(styleJson) as Map<String, dynamic>;
      expect(styleMap['version'], equals(8));
      final sources = styleMap['sources'] as Map<String, dynamic>;
      final tiles = sources['openmaptiles']['tiles'] as List<dynamic>;
      expect(tiles.first, contains('http://127.0.0.1:'));
      expect(tiles.first, contains('/tiles/{z}/{x}/{y}.pbf'));
      expect(sources.containsKey('terrain'), isTrue);
      final terrainTiles = sources['terrain']['tiles'] as List<dynamic>;
      expect(terrainTiles.first, contains('http://127.0.0.1:'));
      expect(terrainTiles.first, contains('/terrain/{z}/{x}/{y}.png'));
      expect(styleMap['terrain']['source'], equals('terrain'));
    });

    test('buildStyleJson configures local PMTiles when region files exist', () async {
      final regionDir = Directory('${tempDir.path}/regions/salzkammergut');
      await regionDir.create(recursive: true);
      final mapFile = File('${regionDir.path}/map.pmtiles');
      await mapFile.writeAsBytes(buildValidPmtilesBytes(4096));
      final terrainFile = File('${regionDir.path}/terrain.pmtiles');
      await terrainFile.writeAsBytes(buildValidPmtilesBytes(4096));

      final styleJson = await service.buildStyleJson(regionId: 'salzkammergut');
      expect(service.isFallbackActive, isFalse);
      expect(service.activeRegionId, equals('salzkammergut'));
      expect(service.tileServer.isRunning, isTrue);

      final styleMap = jsonDecode(styleJson) as Map<String, dynamic>;
      final sources = styleMap['sources'] as Map<String, dynamic>;
      final tiles = sources['openmaptiles']['tiles'] as List<dynamic>;
      expect(tiles.first, contains('http://127.0.0.1:'));
      expect(tiles.first, contains('/tiles/{z}/{x}/{y}.pbf'));
      expect(sources.containsKey('terrain'), isTrue);
      final terrainTiles = sources['terrain']['tiles'] as List<dynamic>;
      expect(terrainTiles.first, contains('http://127.0.0.1:'));
      expect(terrainTiles.first, contains('/terrain/{z}/{x}/{y}.png'));
      expect(styleMap['terrain']['source'], equals('terrain'));
    });

    test('camera operation methods handle null controller safely', () async {
      // Calling moveCamera, zoomIn, zoomOut before onMapCreated should not throw
      await service.moveCamera(position: const LatLng(47.5, 13.5), zoom: 14.0);
      await service.zoomIn();
      await service.zoomOut();
      expect(service.controller, isNull);
    });
  });
}
