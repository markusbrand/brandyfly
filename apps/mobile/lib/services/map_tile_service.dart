import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:path_provider/path_provider.dart';

import '../models/ui_config.dart';

/// Configuration definition for each map widget visual style.
class MapTileStyleConfig {
  const MapTileStyleConfig({
    required this.urlTemplate,
    this.fallbackUrl,
    this.subdomains = const [],
    required this.attribution,
    this.maxZoom = 18.0,
    this.minZoom = 3.0,
    required this.label,
  });

  final String urlTemplate;
  final String? fallbackUrl;
  final List<String> subdomains;
  final String attribution;
  final double maxZoom;
  final double minZoom;
  final String label;

  static const String defaultUserAgent = 'BrandyFly/0.1.0';

  static MapTileStyleConfig forStyle(
    MapWidgetStyle style, {
    bool showContours = true,
  }) {
    switch (style) {
      case MapWidgetStyle.topoContours:
        if (!showContours) {
          return const MapTileStyleConfig(
            label: 'OpenStreetMap Standard (Vector HUD)',
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: [],
            attribution: '© OpenStreetMap contributors',
            maxZoom: 19.0,
            minZoom: 3.0,
          );
        }
        return const MapTileStyleConfig(
          label: 'OpenTopoMap (Alpine Contours)',
          urlTemplate: 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png',
          fallbackUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: ['a', 'b', 'c'],
          attribution: '© OpenTopoMap (CC-BY-SA), © OpenStreetMap contributors',
          maxZoom: 17.0,
          minZoom: 3.0,
        );
      case MapWidgetStyle.minimalVector:
        return const MapTileStyleConfig(
          label: 'OpenStreetMap Standard (Vector HUD)',
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: [],
          attribution: '© OpenStreetMap contributors',
          maxZoom: 19.0,
          minZoom: 3.0,
        );
      case MapWidgetStyle.thermalHeatmap:
        return const MapTileStyleConfig(
          label: 'CARTO Dark HUD (Thermal Radar)',
          urlTemplate:
              'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
          fallbackUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: ['a', 'b', 'c', 'd'],
          attribution: '© OpenStreetMap contributors, © CARTO',
          maxZoom: 19.0,
          minZoom: 3.0,
        );
      case MapWidgetStyle.satelliteTerrain:
        return const MapTileStyleConfig(
          label: 'OpenTopo Relief Shaded',
          urlTemplate: 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png',
          fallbackUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: ['a', 'b', 'c'],
          attribution: '© OpenTopoMap (CC-BY-SA), © OpenStreetMap contributors',
          maxZoom: 17.0,
          minZoom: 3.0,
        );
    }
  }
}

/// Disk-backed offline map tile cache provider that implements [MapCachingProvider].
class BrandyFlyTileCacheService implements MapCachingProvider {
  BrandyFlyTileCacheService({this.customCacheDir});

  static BrandyFlyTileCacheService? _instance;
  static BrandyFlyTileCacheService get instance =>
      _instance ??= BrandyFlyTileCacheService();

  final String? customCacheDir;
  String? _resolvedCacheDir;

  @override
  bool get isSupported => true;

  /// Resolves or initializes the directory used to persist cached map tiles.
  Future<String> getCacheDirectoryPath() async {
    if (_resolvedCacheDir != null) {
      return _resolvedCacheDir!;
    }
    if (customCacheDir != null) {
      _resolvedCacheDir = customCacheDir;
    } else {
      try {
        final supportDir = await getApplicationSupportDirectory();
        _resolvedCacheDir = '${supportDir.path}/map_tile_cache';
      } catch (_) {
        _resolvedCacheDir = '${Directory.systemTemp.path}/brandyfly_tile_cache';
      }
    }

    final dir = Directory(_resolvedCacheDir!);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return _resolvedCacheDir!;
  }

  /// Calculates a stable disk filename based on the tile URL.
  String getFilenameForUrl(String url) {
    final digest = md5.convert(utf8.encode(url));
    return '$digest.tile';
  }

  @override
  Future<CachedMapTile?> getTile(String url) async {
    try {
      final cacheDir = await getCacheDirectoryPath();
      final filename = getFilenameForUrl(url);
      final file = File('$cacheDir/$filename');

      if (!await file.exists()) {
        return null;
      }

      final rawBytes = await file.readAsBytes();
      if (rawBytes.length < 4) {
        return null;
      }

      final byteData = ByteData.sublistView(rawBytes);
      final metaLength = byteData.getUint32(0);

      if (rawBytes.length < 4 + metaLength) {
        return null;
      }

      final metaJsonStr =
          utf8.decode(rawBytes.sublist(4, 4 + metaLength), allowMalformed: true);
      final metaMap = jsonDecode(metaJsonStr) as Map<String, dynamic>;
      final metadata = CachedMapTileMetadata(
        staleAt: metaMap['staleAt'] != null
            ? (DateTime.tryParse(metaMap['staleAt'] as String) ??
                DateTime.timestamp().add(const Duration(days: 7)))
            : DateTime.timestamp().add(const Duration(days: 7)),
        lastModified: metaMap['lastModified'] != null
            ? DateTime.tryParse(metaMap['lastModified'] as String)
            : null,
        etag: metaMap['etag'] as String?,
      );

      final imageBytes = rawBytes.sublist(4 + metaLength);
      return (bytes: imageBytes, metadata: metadata);
    } catch (_) {
      // Graceful offline fallback on any read / parse corruption
      return null;
    }
  }

  @override
  Future<void> putTile({
    required String url,
    required CachedMapTileMetadata metadata,
    Uint8List? bytes,
  }) async {
    if (bytes == null || bytes.isEmpty) {
      return;
    }

    try {
      final cacheDir = await getCacheDirectoryPath();
      final filename = getFilenameForUrl(url);
      final targetFile = File('$cacheDir/$filename');
      final tempFile = File('$cacheDir/$filename.tmp');

      final metaMap = {
        'staleAt': metadata.staleAt.toIso8601String(),
        if (metadata.lastModified != null)
          'lastModified': metadata.lastModified!.toIso8601String(),
        if (metadata.etag != null) 'etag': metadata.etag,
      };

      final metaBytes = utf8.encode(jsonEncode(metaMap));
      final header = ByteData(4)..setUint32(0, metaBytes.length);

      final builder = BytesBuilder(copy: false)
        ..add(header.buffer.asUint8List())
        ..add(metaBytes)
        ..add(bytes);

      await tempFile.writeAsBytes(builder.toBytes(), flush: true);
      await tempFile.rename(targetFile.path);
    } catch (_) {
      // Non-blocking catch to ensure flight HUD remains responsive
    }
  }

  /// Checks if a tile for [url] exists in local disk cache.
  Future<bool> isTileCached(String url) async {
    try {
      final cacheDir = await getCacheDirectoryPath();
      final filename = getFilenameForUrl(url);
      return await File('$cacheDir/$filename').exists();
    } catch (_) {
      return false;
    }
  }

  /// Returns total number of cached tiles in storage.
  Future<int> getCachedTileCount() async {
    try {
      final cacheDir = await getCacheDirectoryPath();
      final dir = Directory(cacheDir);
      if (!await dir.exists()) return 0;
      int count = 0;
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.endsWith('.tile')) {
          count++;
        }
      }
      return count;
    } catch (_) {
      return 0;
    }
  }

  /// Calculates aggregate size of all cached map tiles in bytes.
  Future<int> getCacheSizeBytes() async {
    try {
      final cacheDir = await getCacheDirectoryPath();
      final dir = Directory(cacheDir);
      if (!await dir.exists()) return 0;
      int total = 0;
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.endsWith('.tile')) {
          total += await entity.length();
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  /// Clears all cached tiles from local disk.
  Future<void> clearCache() async {
    try {
      final cacheDir = await getCacheDirectoryPath();
      final dir = Directory(cacheDir);
      if (await dir.exists()) {
        await for (final entity in dir.list()) {
          if (entity is File) {
            await entity.delete();
          }
        }
      }
    } catch (_) {}
  }
}

/// Dedicated BrandyFly TileProvider configuring OpenStreetMap compliant User-Agent
/// and disk-backed offline tile caching.
class BrandyFlyTileProvider extends NetworkTileProvider {
  BrandyFlyTileProvider({
    String? userAgent,
    super.httpClient,
    MapCachingProvider? cachingProvider,
    super.headers,
  }) : super(
          silenceExceptions: true,
          attemptDecodeOfHttpErrorResponses: true,
          abortObsoleteRequests: false,
          cachingProvider:
              cachingProvider ?? BrandyFlyTileCacheService.instance,
        ) {
    headers['User-Agent'] = userAgent ?? MapTileStyleConfig.defaultUserAgent;
  }
}
