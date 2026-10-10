import 'dart:typed_data';
import 'dart:ui' show Canvas;

import 'package:maplibre_platform_interface/maplibre_platform_interface.dart';

/// [StyleController] fake that records sources, layers and GeoJSON updates.
class RecordingStyleController extends StyleController {
  RecordingStyleController({this.failUpdates = false});

  /// When true, [updateGeoJsonSource] throws (failure-path tests).
  bool failUpdates;

  final Map<String, String> sourceData = {};
  final List<String> layerIds = [];
  final Map<String, String?> layerBelow = {};
  final Map<String, StyleLayer> layers = {};
  final List<(String, String)> updates = [];
  final List<String> images = [];

  int updatesFor(String id) => updates.where((u) => u.$1 == id).length;

  @override
  Future<void> addSource(Source source) async {
    if (sourceData.containsKey(source.id)) {
      throw Exception('A Source with the id "${source.id}" already exists.');
    }
    sourceData[source.id] = source is GeoJsonSource ? source.data : '';
  }

  @override
  Future<void> addLayer(
    StyleLayer layer, {
    String? belowLayerId,
    String? aboveLayerId,
    int? atIndex,
  }) async {
    if (layers.containsKey(layer.id)) {
      throw Exception('A Layer with the id "${layer.id}" already exists.');
    }
    layers[layer.id] = layer;
    layerBelow[layer.id] = belowLayerId;
    final idx = belowLayerId == null ? -1 : layerIds.indexOf(belowLayerId);
    if (idx >= 0) {
      layerIds.insert(idx, layer.id);
    } else {
      layerIds.add(layer.id);
    }
  }

  @override
  Future<void> updateGeoJsonSource({
    required String id,
    required String data,
  }) async {
    if (failUpdates) throw Exception('update failed');
    updates.add((id, data));
    sourceData[id] = data;
  }

  @override
  Future<void> removeLayer(String id) async {
    layers.remove(id);
    layerIds.remove(id);
  }

  @override
  Future<void> removeSource(String id) async => sourceData.remove(id);

  @override
  Future<List<String>> getAttributions() async => const [];

  @override
  List<String> getAttributionsSync() => const [];

  @override
  List<String> getLayerIds() => List.of(layerIds);

  @override
  Future<void> addImage(String id, Uint8List bytes) async => images.add(id);

  @override
  Future<void> addImageFromCanvas({
    required String id,
    required void Function(Canvas canvas) painter,
    int width = 200,
    int height = 200,
  }) async {
    // Rasterizing needs a real engine; just record the request.
    images.add(id);
  }

  @override
  Future<void> removeImage(String id) async => images.remove(id);

  @override
  void setProjection(MapProjection projection) {}

  @override
  void dispose() {}
}
