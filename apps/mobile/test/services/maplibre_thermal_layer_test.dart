import 'dart:convert';
import 'dart:io';

import 'package:brandyfly/domain/thermal/thermal_layer_spec.dart';
import 'package:brandyfly/domain/thermal/thermal_variant.dart';
import 'package:brandyfly/services/maplibre_map_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre/maplibre.dart';

/// Records style mutations performed by the service.
class RecordingStyleController implements StyleController {
  final calls = <String>[];
  final sources = <Source>[];
  final layers = <(StyleLayer, String?)>[];

  @override
  Future<void> addSource(Source source) async {
    calls.add('addSource:${source.id}');
    sources.add(source);
  }

  @override
  Future<void> addLayer(
    StyleLayer layer, {
    String? belowLayerId,
    String? aboveLayerId,
    int? atIndex,
  }) async {
    calls.add('addLayer:${layer.id}');
    layers.add((layer, belowLayerId));
  }

  @override
  Future<void> removeLayer(String id) async => calls.add('removeLayer:$id');

  @override
  Future<void> removeSource(String id) async => calls.add('removeSource:$id');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _template = '''
{
  "version": 8,
  "sources": {"openmaptiles": {"type": "vector", "url": "x"}},
  "layers": [
    {"id": "background", "type": "background"},
    {"id": "water", "type": "fill", "source": "openmaptiles"},
    {"id": "peaks", "type": "circle", "source": "openmaptiles"},
    {"id": "labels", "type": "symbol", "source": "openmaptiles"}
  ]
}
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late MapLibreMapService service;
  final jul07 = ThermalLayerSpec(
    variant: ThermalVariant(ThermalSeason.jul, ThermalTimeOfDay.midday),
    opacity: 0.6,
  );

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('maplibre_thermal_test');
    service = MapLibreMapService(customAppSupportDir: tmp.path);
  });

  tearDown(() async {
    service.dispose();
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  List<dynamic> layerIds(Map<String, dynamic> style) =>
      (style['layers'] as List).map((l) => l['id']).toList();

  group('style JSON', () {
    test(
      'thermal on: raster source + layer below first label/point layer',
      () async {
        final json = await service.buildStyleJson(
          baseTemplateJson: _template,
          thermal: jul07,
        );
        final style = jsonDecode(json) as Map<String, dynamic>;
        final src = style['sources'][MapLibreMapService.thermalSourceId];
        expect(src['type'], 'raster');
        expect(src['tileSize'], 256);
        expect(src['maxzoom'], 12);
        expect(src.containsKey('scheme'), isFalse); // loopback serves XYZ
        expect(
          (src['tiles'] as List).single,
          '${service.tileServer.baseUrl}/thermals/jul_07/{z}/{x}/{y}.png',
        );
        expect(src['attribution'], contains('thermal.kk7.ch'));
        expect(layerIds(style), [
          'background',
          'water',
          MapLibreMapService.thermalLayerId,
          'peaks',
          'labels',
        ]);
        final layer = (style['layers'] as List).firstWhere(
          (l) => l['id'] == MapLibreMapService.thermalLayerId,
        );
        expect(layer['type'], 'raster');
        expect(layer['paint']['raster-opacity'], 0.6);
        expect(service.thermalBelowLayerId, 'peaks');
      },
    );

    test('opacity is taken from the spec', () async {
      final json = await service.buildStyleJson(
        baseTemplateJson: _template,
        thermal: ThermalLayerSpec(variant: jul07.variant, opacity: 0.3),
      );
      final style = jsonDecode(json) as Map<String, dynamic>;
      final layer = (style['layers'] as List).firstWhere(
        (l) => l['id'] == MapLibreMapService.thermalLayerId,
      );
      expect(layer['paint']['raster-opacity'], 0.3);
    });

    test('thermal off: no thermal source or layer', () async {
      final json = await service.buildStyleJson(baseTemplateJson: _template);
      final style = jsonDecode(json) as Map<String, dynamic>;
      expect(
        (style['sources'] as Map).containsKey(
          MapLibreMapService.thermalSourceId,
        ),
        isFalse,
      );
      expect(
        layerIds(style),
        isNot(contains(MapLibreMapService.thermalLayerId)),
      );
    });

    test(
      'bundled alpine relief style gets the layer below peak points',
      () async {
        final json = await service.buildStyleJson(thermal: jul07);
        final ids = layerIds(jsonDecode(json) as Map<String, dynamic>);
        final idx = ids.indexOf(MapLibreMapService.thermalLayerId);
        expect(idx, greaterThan(ids.indexOf('hillshade')));
        expect(ids[idx + 1], 'mountain-peak-point');
      },
    );
  });

  group('runtime layer swap', () {
    test(
      'swaps variant via StyleController without rebuilding the style',
      () async {
        final initialJson = await service.buildStyleJson(
          baseTemplateJson: _template,
          thermal: jul07,
        );
        final style = RecordingStyleController();
        service.onStyleLoaded(style);
        await service.setThermalLayer(jul07); // unchanged -> no-op
        expect(style.calls, isEmpty);

        final midday = ThermalLayerSpec(
          variant: ThermalVariant(ThermalSeason.jul, ThermalTimeOfDay.evening),
          opacity: 0.6,
        );
        await service.setThermalLayer(midday);
        expect(style.calls, [
          'removeLayer:kk7-thermals',
          'removeSource:kk7-thermals',
          'addSource:kk7-thermals',
          'addLayer:kk7-thermals',
        ]);
        final src = style.sources.single as RasterSource;
        expect(src.tiles!.single, contains('/thermals/jul_10/'));
        expect(src.maxZoom, 12);
        expect(style.layers.single.$2, 'peaks');
        expect(service.lastLoadedStyleJson, initialJson);
      },
    );

    test('hiding and showing the layer', () async {
      await service.buildStyleJson(baseTemplateJson: _template);
      final style = RecordingStyleController();
      service.onStyleLoaded(style);
      await service.setThermalLayer(jul07);
      expect(style.calls, ['addSource:kk7-thermals', 'addLayer:kk7-thermals']);
      style.calls.clear();
      await service.setThermalLayer(null);
      expect(style.calls, [
        'removeLayer:kk7-thermals',
        'removeSource:kk7-thermals',
      ]);
    });

    test(
      'changes requested before the style loads are applied on load',
      () async {
        await service.buildStyleJson(
          baseTemplateJson: _template,
          thermal: jul07,
        );
        await service.setThermalLayer(null);
        final style = RecordingStyleController();
        service.onStyleLoaded(style);
        await service.setThermalLayer(null);
        expect(style.calls, [
          'removeLayer:kk7-thermals',
          'removeSource:kk7-thermals',
        ]);
      },
    );
  });
}
