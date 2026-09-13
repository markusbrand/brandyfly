import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:maplibre/maplibre.dart';
import 'package:path_provider/path_provider.dart';

import '../models/lat_lng.dart';
import 'local_tile_server.dart';

/// Service managing MapLibre GL controller lifecycle, style JSON compilation,
/// PMTiles local source configuration, camera operations, and offline fallback detection.
class MapLibreMapService extends ChangeNotifier {
  MapLibreMapService({
    this.customAppSupportDir,
    LocalTileServer? tileServer,
  }) : _tileServer = tileServer ?? LocalTileServer();

  final String? customAppSupportDir;
  final LocalTileServer _tileServer;

  LocalTileServer get tileServer => _tileServer;

  MapController? _controller;
  StyleController? _styleController;
  bool _isStyleLoaded = false;
  bool _isFallbackActive = true;
  String? _activeRegionId;
  String? _lastLoadedStyleJson;

  MapController? get controller => _controller;
  StyleController? get styleController => _styleController;
  bool get isStyleLoaded => _isStyleLoaded;
  bool get isFallbackActive => _isFallbackActive;
  String? get activeRegionId => _activeRegionId;
  String? get lastLoadedStyleJson => _lastLoadedStyleJson;

  /// Sets or updates the active MapController.
  void onMapCreated(MapController controller) {
    _controller = controller;
    notifyListeners();
  }

  /// Sets or updates the active StyleController when the style has loaded.
  void onStyleLoaded(StyleController style) {
    _styleController = style;
    _isStyleLoaded = true;
    notifyListeners();
  }

  /// Resolves the base path for regional offline storage.
  Future<String> getRegionsBasePath() async {
    if (customAppSupportDir != null) {
      return '$customAppSupportDir/regions';
    }
    try {
      final dir = await getApplicationSupportDirectory();
      return '${dir.path}/regions';
    } catch (_) {
      return '/tmp/brandyfly/regions';
    }
  }

  /// Checks whether a downloaded region archive exists on disk.
  Future<bool> regionExists(String regionId) async {
    final basePath = await getRegionsBasePath();
    final mapFile = File('$basePath/$regionId/map.pmtiles');
    return mapFile.existsSync() && mapFile.lengthSync() > 0;
  }

  /// Resolves local path to the bundled global overview PMTiles archive.
  Future<String?> resolveOverviewArchivePath() async {
    for (final path in [
      'assets/map_data/global_overview.pmtiles',
      'apps/mobile/assets/map_data/global_overview.pmtiles',
    ]) {
      final f = File(path);
      if (f.existsSync() && f.lengthSync() > 0) {
        return f.path;
      }
    }

    try {
      final basePath = await getRegionsBasePath();
      final cachedFile = File('$basePath/global_overview.pmtiles');
      if (cachedFile.existsSync() && cachedFile.lengthSync() > 0) {
        return cachedFile.path;
      }
      final data = await rootBundle.load('assets/map_data/global_overview.pmtiles');
      await cachedFile.parent.create(recursive: true);
      await cachedFile.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
      return cachedFile.path;
    } catch (_) {
      return null;
    }
  }

  /// Builds a dynamic MapLibre Style JSON string configured with local PMTiles sources.
  /// If [regionId] is provided and files exist, uses the region's vector and terrain PMTiles.
  /// Otherwise, falls back to the bundled overview PMTiles without hillshade.
  Future<String> buildStyleJson({
    String? regionId,
    String? baseTemplateJson,
  }) async {
    await _tileServer.start();

    String template = baseTemplateJson ?? '';
    if (template.isEmpty) {
      try {
        template = await rootBundle.loadString(
          'assets/map_styles/alpine_relief.json',
        );
      } catch (_) {
        template = _defaultStyleTemplate();
      }
    }

    final basePath = await getRegionsBasePath();
    bool useRegion = false;
    String? terrainSourceUrl;

    String? effectiveRegionId = regionId;
    if (effectiveRegionId == null || effectiveRegionId.isEmpty) {
      try {
        final baseDir = Directory(basePath);
        if (baseDir.existsSync()) {
          final entries = baseDir.listSync().whereType<Directory>();
          for (final entry in entries) {
            final testFile = File('${entry.path}/map.pmtiles');
            if (testFile.existsSync() && testFile.lengthSync() > 0) {
              effectiveRegionId = entry.path.split(Platform.pathSeparator).last;
              break;
            }
          }
        }
      } catch (_) {}
    }

    if (effectiveRegionId != null && effectiveRegionId.isNotEmpty) {
      final regionDir = '$basePath/$effectiveRegionId';
      final mapFile = File('$regionDir/map.pmtiles');
      final terrainFile = File('$regionDir/terrain.pmtiles');

      if (mapFile.existsSync() && mapFile.lengthSync() > 0) {
        useRegion = true;
        await _tileServer.setPrimaryArchive(mapFile.path);
        if (terrainFile.existsSync() && terrainFile.lengthSync() > 0) {
          terrainSourceUrl = 'pmtiles://$regionDir/terrain.pmtiles';
        }
      } else {
        await _tileServer.setPrimaryArchive(null);
      }
    } else {
      await _tileServer.setPrimaryArchive(null);
    }

    final overviewPath = await resolveOverviewArchivePath();
    if (overviewPath != null) {
      await _tileServer.setFallbackArchive(overviewPath);
    }

    debugPrint('[MapLibreMapService] basePath: $basePath, effectiveRegionId: $effectiveRegionId, useRegion: $useRegion, tileServer: ${_tileServer.baseUrl}');
    _isFallbackActive = !useRegion;
    _activeRegionId = useRegion ? effectiveRegionId : null;

    Map<String, dynamic> styleMap;
    try {
      styleMap = jsonDecode(template) as Map<String, dynamic>;
    } catch (_) {
      styleMap = jsonDecode(_defaultStyleTemplate()) as Map<String, dynamic>;
    }

    final sources = (styleMap['sources'] as Map<String, dynamic>?) ?? {};

    // Configure vector source to point directly to loopback tile server
    final vectorTileUrl = '${_tileServer.baseUrl}/tiles/{z}/{x}/{y}.pbf';
    if (sources.containsKey('openmaptiles')) {
      final om = sources['openmaptiles'] as Map<String, dynamic>;
      om.remove('url');
      om['type'] = 'vector';
      om['tiles'] = [vectorTileUrl];
    } else {
      sources['openmaptiles'] = {
        'type': 'vector',
        'tiles': [vectorTileUrl],
      };
    }

    // Configure terrain raster-dem source if available
    if (terrainSourceUrl != null) {
      if (sources.containsKey('terrain')) {
        final t = sources['terrain'] as Map<String, dynamic>;
        t['url'] = terrainSourceUrl;
      } else {
        sources['terrain'] = {
          'type': 'raster-dem',
          'url': terrainSourceUrl,
          'tileSize': 512,
          'encoding': 'terrarium',
        };
      }
      styleMap['terrain'] = {
        'source': 'terrain',
        'exaggeration': 1.5,
      };
    } else {
      // Remove terrain source and hillshade layer when fallback or no DEM
      sources.remove('terrain');
      styleMap.remove('terrain');
      final layers = (styleMap['layers'] as List<dynamic>?) ?? [];
      layers.removeWhere((l) {
        if (l is Map<String, dynamic>) {
          return l['type'] == 'hillshade' || l['source'] == 'terrain';
        }
        return false;
      });
    }

    styleMap['sources'] = sources;
    _lastLoadedStyleJson = jsonEncode(styleMap);
    notifyListeners();
    return _lastLoadedStyleJson!;
  }

  /// Moves camera to center on given coordinates with optional zoom, bearing, pitch.
  Future<void> moveCamera({
    required LatLng position,
    double? zoom,
    double? bearing,
    double? pitch,
  }) async {
    final c = _controller;
    if (c == null) return;
    try {
      await c.moveCamera(
        center: Geographic(lon: position.longitude, lat: position.latitude),
        zoom: zoom,
        bearing: bearing,
        pitch: pitch,
      );
    } catch (e) {
      debugPrint('[MapLibreMapService] moveCamera error: $e');
    }
  }

  /// Zooms in by one step.
  Future<void> zoomIn() async {
    final c = _controller;
    if (c == null) return;
    try {
      final currentZoom = c.camera?.zoom ?? 13.5;
      await c.moveCamera(zoom: (currentZoom + 1.0).clamp(1.0, 20.0));
    } catch (e) {
      debugPrint('[MapLibreMapService] zoomIn error: $e');
    }
  }

  /// Zooms out by one step.
  Future<void> zoomOut() async {
    final c = _controller;
    if (c == null) return;
    try {
      final currentZoom = c.camera?.zoom ?? 13.5;
      await c.moveCamera(zoom: (currentZoom - 1.0).clamp(1.0, 20.0));
    } catch (e) {
      debugPrint('[MapLibreMapService] zoomOut error: $e');
    }
  }

  /// Default minimal fallback style template.
  static String _defaultStyleTemplate() {
    return '''
{
  "version": 8,
  "name": "BrandyFly Alpine Relief",
  "sources": {
    "openmaptiles": {
      "type": "vector",
      "tiles": ["http://127.0.0.1:0/tiles/{z}/{x}/{y}.pbf"]
    }
  },
  "layers": [
    {
      "id": "background",
      "type": "background",
      "paint": {
        "background-color": "#f0ece4"
      }
    },
    {
      "id": "water",
      "type": "fill",
      "source": "openmaptiles",
      "source-layer": "water",
      "paint": {
        "fill-color": "#a0cfdb"
      }
    }
  ]
}
''';
  }

  @override
  void dispose() {
    _controller = null;
    _styleController = null;
    _isStyleLoaded = false;
    _tileServer.stop();
    super.dispose();
  }
}
