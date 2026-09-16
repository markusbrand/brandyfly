import 'dart:convert';
import 'dart:io';

import 'package:brandyfly/models/lat_lng.dart';
import 'package:brandyfly/services/maplibre_map_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

    test('regionExists returns true when region files are present', () async {
      final regionDir = Directory('${tempDir.path}/regions/austria_dachstein');
      await regionDir.create(recursive: true);
      final mapFile = File('${regionDir.path}/map.pmtiles');
      await mapFile.writeAsBytes([1, 2, 3, 4]);

      final exists = await service.regionExists('austria_dachstein');
      expect(exists, isTrue);
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
      await mapFile.writeAsBytes(List.filled(127, 0));
      final terrainFile = File('${regionDir.path}/terrain.pmtiles');
      await terrainFile.writeAsBytes(List.filled(127, 0));

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
