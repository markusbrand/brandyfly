import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'pmtiles_reader.dart';

/// Embedded loopback HTTP tile server running on `127.0.0.1` on an ephemeral port.
///
/// Serves standard OpenMapTiles vector tiles (`/tiles/{z}/{x}/{y}.pbf`) and
/// raster DEM terrain tiles (`/terrain/{z}/{x}/{y}.png`) from local PMTiles
/// archives, persistent disk cache, or online providers directly to MapLibre Native.
class LocalTileServer {
  LocalTileServer({
    this.onlineFallbackEnabled = true,
    String? onlineFallbackUrlTemplate,
    String? onlineTerrainFallbackUrlTemplate,
    this.cacheDirectoryPath,
    HttpClient? httpClient,
  })  : _configuredOnlineFallbackUrlTemplate = onlineFallbackUrlTemplate,
        _configuredOnlineTerrainFallbackUrlTemplate =
            onlineTerrainFallbackUrlTemplate,
        _httpClient = httpClient ?? HttpClient() {
    _httpClient.connectionTimeout = const Duration(seconds: 3);
    _httpClient.autoUncompress = false;
  }

  static const String defaultSnapshotTemplate =
      'https://tiles.openfreemap.org/planet/20260906_080001_pt/{z}/{x}/{y}.pbf';
  static const String defaultTerrainTemplate =
      'https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png';
  static const String dynamicDiscoveryUrl =
      'https://tiles.openfreemap.org/planet';

  final bool onlineFallbackEnabled;
  final String? _configuredOnlineFallbackUrlTemplate;
  final String? _configuredOnlineTerrainFallbackUrlTemplate;
  final String? cacheDirectoryPath;
  final HttpClient _httpClient;

  String _activeOnlineFallbackUrlTemplate = defaultSnapshotTemplate;
  String? _resolvedCacheDirectoryPath;

  HttpServer? _server;
  StreamSubscription<HttpRequest>? _serverSubscription;
  PMTilesReader? _primaryReader;
  PMTilesReader? _fallbackReader;
  PMTilesReader? _terrainReader;
  String? _primaryArchivePath;
  String? _fallbackArchivePath;
  String? _terrainArchivePath;
  bool _isRunning = false;

  final ValueNotifier<bool> onlinePreviewNotifier = ValueNotifier<bool>(false);

  bool get isRunning => _isRunning;
  bool get isOnlinePreviewActive => onlinePreviewNotifier.value;
  int get port => _server?.port ?? 0;
  String get baseUrl => 'http://127.0.0.1:$port';
  String get tilesUrlTemplate => '$baseUrl/tiles/{z}/{x}/{y}.pbf';
  String get terrainUrlTemplate => '$baseUrl/terrain/{z}/{x}/{y}.png';
  String get onlineFallbackUrlTemplate =>
      _configuredOnlineFallbackUrlTemplate ?? _activeOnlineFallbackUrlTemplate;
  String get onlineTerrainFallbackUrlTemplate =>
      _configuredOnlineTerrainFallbackUrlTemplate ?? defaultTerrainTemplate;

  /// Asynchronously queries OpenFreeMap for the currently active snapshot URL template.
  Future<void> discoverSnapshot() async {
    if (!onlineFallbackEnabled || _configuredOnlineFallbackUrlTemplate != null) {
      return;
    }
    try {
      final req = await _httpClient
          .getUrl(Uri.parse(dynamicDiscoveryUrl))
          .timeout(const Duration(seconds: 2));
      req.headers.set(HttpHeaders.acceptEncodingHeader, 'gzip');
      final resp = await req.close().timeout(const Duration(seconds: 2));
      if (resp.statusCode == HttpStatus.ok) {
        final builder = BytesBuilder();
        await for (final chunk in resp) {
          builder.add(chunk);
        }
        final bytes = builder.takeBytes();
        final content = _isGzip(bytes)
            ? utf8.decode(gzip.decode(bytes))
            : utf8.decode(bytes, allowMalformed: true);
        final json = jsonDecode(content) as Map<String, dynamic>;
        final tiles = json['tiles'] as List<dynamic>?;
        if (tiles != null && tiles.isNotEmpty && tiles.first is String) {
          _activeOnlineFallbackUrlTemplate = tiles.first as String;
          debugPrint(
            '[LocalTileServer] Discovered active OpenFreeMap snapshot: $_activeOnlineFallbackUrlTemplate',
          );
        }
      }
    } catch (e) {
      debugPrint(
        '[LocalTileServer] Dynamic snapshot discovery failed: $e (using fallback: $_activeOnlineFallbackUrlTemplate)',
      );
    }
  }

  /// Starts the HTTP server on `InternetAddress.loopbackIPv4` on an ephemeral port (`0`).
  Future<int> start() async {
    if (_isRunning && _server != null) {
      return _server!.port;
    }

    _server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      0,
      shared: false,
    );
    _isRunning = true;

    _serverSubscription = _server!.listen(
      _handleRequest,
      onError: (error) {
        debugPrint('[LocalTileServer] Error in HTTP stream: $error');
      },
    );

    if (onlineFallbackEnabled && _configuredOnlineFallbackUrlTemplate == null) {
      unawaited(discoverSnapshot());
    }

    debugPrint('[LocalTileServer] Started listening on $baseUrl');
    return _server!.port;
  }

  /// Sets or updates the primary regional PMTiles archive.
  Future<void> setPrimaryArchive(String? path) async {
    if (_primaryArchivePath == path && _primaryReader != null) {
      return;
    }

    await _primaryReader?.close();
    _primaryReader = null;
    _primaryArchivePath = path;

    if (path != null && path.isNotEmpty) {
      final file = File(path);
      if (await file.exists() && await file.length() >= 127) {
        try {
          _primaryReader = await PMTilesReader.open(file);
          _setOnlinePreviewActive(false);
          debugPrint('[LocalTileServer] Loaded primary archive: $path');
        } catch (e) {
          debugPrint('[LocalTileServer] Failed to open primary archive $path: $e');
        }
      }
    }
  }

  /// Sets or updates the fallback overview PMTiles archive (e.g. global overview).
  Future<void> setFallbackArchive(String? path) async {
    if (_fallbackArchivePath == path && _fallbackReader != null) {
      return;
    }

    await _fallbackReader?.close();
    _fallbackReader = null;
    _fallbackArchivePath = path;

    if (path != null && path.isNotEmpty) {
      final file = File(path);
      if (await file.exists() && await file.length() >= 127) {
        try {
          _fallbackReader = await PMTilesReader.open(file);
          debugPrint('[LocalTileServer] Loaded fallback archive: $path');
        } catch (e) {
          debugPrint('[LocalTileServer] Failed to open fallback archive $path: $e');
        }
      }
    }
  }

  /// Sets or updates the terrain DEM PMTiles archive.
  Future<void> setTerrainArchive(String? path) async {
    if (_terrainArchivePath == path && _terrainReader != null) {
      return;
    }

    await _terrainReader?.close();
    _terrainReader = null;
    _terrainArchivePath = path;

    if (path != null && path.isNotEmpty) {
      final file = File(path);
      if (await file.exists() && await file.length() >= 127) {
        try {
          _terrainReader = await PMTilesReader.open(file);
          debugPrint('[LocalTileServer] Loaded terrain archive: $path');
        } catch (e) {
          debugPrint('[LocalTileServer] Failed to open terrain archive $path: $e');
        }
      }
    }
  }

  /// Shuts down the HTTP server and releases open file handles.
  Future<void> stop() async {
    if (!_isRunning) return;
    _isRunning = false;

    _setOnlinePreviewActive(false);

    await _serverSubscription?.cancel();
    _serverSubscription = null;

    await _server?.close(force: true);
    _server = null;

    await _primaryReader?.close();
    _primaryReader = null;
    _primaryArchivePath = null;

    await _fallbackReader?.close();
    _fallbackReader = null;
    _fallbackArchivePath = null;

    await _terrainReader?.close();
    _terrainReader = null;
    _terrainArchivePath = null;

    try {
      _httpClient.close(force: true);
    } catch (_) {}

    debugPrint('[LocalTileServer] Stopped');
  }

  /// Resolves the root directory path used for caching online vector tiles.
  Future<String?> _getCacheDirectoryPath() async {
    if (cacheDirectoryPath != null) {
      return cacheDirectoryPath;
    }
    if (_resolvedCacheDirectoryPath != null) {
      return _resolvedCacheDirectoryPath;
    }
    try {
      final temp = await getTemporaryDirectory();
      _resolvedCacheDirectoryPath = '${temp.path}/cache';
      return _resolvedCacheDirectoryPath;
    } catch (_) {
      final temp = Directory.systemTemp;
      _resolvedCacheDirectoryPath = '${temp.path}/brandyfly_cache';
      return _resolvedCacheDirectoryPath;
    }
  }

  /// Checks local disk cache for previously downloaded vector tile.
  Future<Uint8List?> _getCachedVectorTile(int z, int x, int y) async {
    try {
      final cacheDir = await _getCacheDirectoryPath();
      if (cacheDir == null) return null;
      final file = File('$cacheDir/vector_tiles/$z/$x/$y.pbf');
      if (await file.exists() && await file.length() > 0) {
        return await file.readAsBytes();
      }
    } catch (e) {
      debugPrint('[LocalTileServer] Error reading cached vector tile $z/$x/$y: $e');
    }
    return null;
  }

  /// Checks local disk cache for previously downloaded terrain raster DEM tile.
  Future<Uint8List?> _getCachedTerrainTile(int z, int x, int y) async {
    try {
      final cacheDir = await _getCacheDirectoryPath();
      if (cacheDir == null) return null;
      final file = File('$cacheDir/terrain_tiles/$z/$x/$y.png');
      if (await file.exists() && await file.length() > 0) {
        return await file.readAsBytes();
      }
    } catch (e) {
      debugPrint('[LocalTileServer] Error reading cached terrain tile $z/$x/$y: $e');
    }
    return null;
  }

  /// Persists a downloaded vector tile to the local disk cache.
  Future<void> _saveVectorTileToDiskCache(int z, int x, int y, Uint8List bytes) async {
    try {
      final cacheDir = await _getCacheDirectoryPath();
      if (cacheDir == null) return;
      final file = File('$cacheDir/vector_tiles/$z/$x/$y.pbf');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
    } catch (e) {
      debugPrint('[LocalTileServer] Failed to write vector tile cache for $z/$x/$y: $e');
    }
  }

  /// Persists a downloaded terrain raster tile to the local disk cache.
  Future<void> _saveTerrainTileToDiskCache(int z, int x, int y, Uint8List bytes) async {
    try {
      final cacheDir = await _getCacheDirectoryPath();
      if (cacheDir == null) return;
      final file = File('$cacheDir/terrain_tiles/$z/$x/$y.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
    } catch (e) {
      debugPrint('[LocalTileServer] Failed to write terrain tile cache for $z/$x/$y: $e');
    }
  }

  /// Clears all cached tiles on disk.
  Future<void> clearDiskCache() async {
    try {
      final cacheDir = await _getCacheDirectoryPath();
      if (cacheDir != null) {
        final dir = Directory(cacheDir);
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      }
    } catch (_) {}
  }

  void _setOnlinePreviewActive(bool active) {
    if (onlinePreviewNotifier.value != active) {
      onlinePreviewNotifier.value = active;
    }
  }

  /// Routes incoming HTTP requests to handlers.
  Future<void> _handleRequest(HttpRequest request) async {
    try {
      final path = request.uri.path;

      if (path == '/health') {
        _respondJson(request, HttpStatus.ok, {
          'status': 'ok',
          'port': port,
          'primaryLoaded': _primaryReader != null,
          'fallbackLoaded': _fallbackReader != null,
          'terrainLoaded': _terrainReader != null,
          'isOnlinePreviewActive': isOnlinePreviewActive,
        });
        return;
      }

      if (path == '/tiles.json') {
        await _handleTileJson(request);
        return;
      }

      final vectorMatch =
          RegExp(r'^/tiles/(\d+)/(\d+)/(\d+)\.pbf$').firstMatch(path);
      if (vectorMatch != null) {
        final z = int.parse(vectorMatch.group(1)!);
        final x = int.parse(vectorMatch.group(2)!);
        final y = int.parse(vectorMatch.group(3)!);
        await _handleVectorTileRequest(request, z, x, y);
        return;
      }

      final terrainMatch =
          RegExp(r'^/terrain/(\d+)/(\d+)/(\d+)\.png$').firstMatch(path);
      if (terrainMatch != null) {
        final z = int.parse(terrainMatch.group(1)!);
        final x = int.parse(terrainMatch.group(2)!);
        final y = int.parse(terrainMatch.group(3)!);
        await _handleTerrainTileRequest(request, z, x, y);
        return;
      }

      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    } catch (e) {
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      } catch (_) {}
    }
  }

  /// Serves TileJSON metadata for the active or fallback archive.
  Future<void> _handleTileJson(HttpRequest request) async {
    String? metaJson;
    if (_primaryReader != null) {
      try {
        metaJson = await _primaryReader!.getMetadataJson();
      } catch (_) {}
    }
    if (metaJson == null && _fallbackReader != null) {
      try {
        metaJson = await _fallbackReader!.getMetadataJson();
      } catch (_) {}
    }

    Map<String, dynamic> metadata = {};
    if (metaJson != null) {
      try {
        metadata = jsonDecode(metaJson) as Map<String, dynamic>;
      } catch (_) {}
    }

    metadata['tilejson'] = '3.0.0';
    metadata['tiles'] = [tilesUrlTemplate];

    _respondJson(request, HttpStatus.ok, metadata);
  }

  /// Serves vector tile payloads from primary PMTiles, fallback PMTiles, disk cache, or online proxy.
  Future<void> _handleVectorTileRequest(
    HttpRequest request,
    int z,
    int x,
    int y,
  ) async {
    // 1. Check primary archive
    if (_primaryReader != null) {
      try {
        final tileBytes = await _primaryReader!.getTile(z, x, y);
        if (tileBytes != null && tileBytes.isNotEmpty) {
          _setOnlinePreviewActive(false);
          await _serveVectorBytes(request, tileBytes);
          return;
        }
      } catch (e) {
        debugPrint('[LocalTileServer] Primary tile fetch error ($z/$x/$y): $e');
      }
    }

    // 2. Check fallback archive
    if (_fallbackReader != null) {
      try {
        final tileBytes = await _fallbackReader!.getTile(z, x, y);
        if (tileBytes != null && tileBytes.isNotEmpty) {
          await _serveVectorBytes(request, tileBytes);
          return;
        }
      } catch (e) {
        debugPrint('[LocalTileServer] Fallback tile fetch error ($z/$x/$y): $e');
      }
    }

    // 3. Check persistent disk cache
    final cachedBytes = await _getCachedVectorTile(z, x, y);
    if (cachedBytes != null && cachedBytes.isNotEmpty) {
      _setOnlinePreviewActive(true);
      await _serveVectorBytes(request, cachedBytes);
      return;
    }

    // 4. Optional online vector tile fallback during simulation / dev
    if (onlineFallbackEnabled) {
      final handled = await _proxyOnlineVectorTile(request, z, x, y);
      if (handled) return;
    }

    // 5. Return 204 No Content for missing tiles
    request.response.statusCode = HttpStatus.noContent;
    await request.response.close();
  }

  /// Serves terrain DEM raster tiles from terrain PMTiles, disk cache, or online proxy.
  Future<void> _handleTerrainTileRequest(
    HttpRequest request,
    int z,
    int x,
    int y,
  ) async {
    // 1. Check local terrain archive
    if (_terrainReader != null) {
      try {
        final tileBytes = await _terrainReader!.getTile(z, x, y);
        if (tileBytes != null && tileBytes.isNotEmpty) {
          await _serveRasterBytes(request, tileBytes);
          return;
        }
      } catch (e) {
        debugPrint('[LocalTileServer] Terrain archive fetch error ($z/$x/$y): $e');
      }
    }

    // 2. Check persistent disk cache
    final cachedBytes = await _getCachedTerrainTile(z, x, y);
    if (cachedBytes != null && cachedBytes.isNotEmpty) {
      await _serveRasterBytes(request, cachedBytes);
      return;
    }

    // 3. Online terrain DEM proxy (AWS Terrarium)
    if (onlineFallbackEnabled) {
      final handled = await _proxyOnlineTerrainTile(request, z, x, y);
      if (handled) return;
    }

    // 4. Return 204 No Content for missing terrain tiles
    request.response.statusCode = HttpStatus.noContent;
    await request.response.close();
  }

  /// Serves compressed vector tile payload directly to MapLibre.
  Future<void> _serveVectorBytes(HttpRequest request, Uint8List tileBytes) async {
    final response = request.response;
    response.statusCode = HttpStatus.ok;
    response.headers.set(HttpHeaders.contentTypeHeader, 'application/x-protobuf');
    if (_isGzip(tileBytes)) {
      response.headers.set(HttpHeaders.contentEncodingHeader, 'gzip');
    }
    response.headers.set(HttpHeaders.cacheControlHeader, 'public, max-age=86400');
    response.headers.set(HttpHeaders.accessControlAllowOriginHeader, '*');
    response.add(tileBytes);
    await response.close();
  }

  /// Serves raster PNG terrain tile payload directly to MapLibre.
  Future<void> _serveRasterBytes(HttpRequest request, Uint8List tileBytes) async {
    final response = request.response;
    response.statusCode = HttpStatus.ok;
    response.headers.set(HttpHeaders.contentTypeHeader, 'image/png');
    if (_isGzip(tileBytes)) {
      response.headers.set(HttpHeaders.contentEncodingHeader, 'gzip');
    }
    response.headers.set(HttpHeaders.cacheControlHeader, 'public, max-age=86400');
    response.headers.set(HttpHeaders.accessControlAllowOriginHeader, '*');
    response.add(tileBytes);
    await response.close();
  }

  static bool _isGzip(List<int> bytes) =>
      bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b;

  /// Fetches vector tile from online provider when outside local bounds.
  Future<bool> _proxyOnlineVectorTile(
    HttpRequest request,
    int z,
    int x,
    int y,
  ) async {
    final upstreamUrl = onlineFallbackUrlTemplate
        .replaceAll('{z}', '$z')
        .replaceAll('{x}', '$x')
        .replaceAll('{y}', '$y');

    try {
      final upstreamReq = await _httpClient
          .getUrl(Uri.parse(upstreamUrl))
          .timeout(const Duration(seconds: 3));
      upstreamReq.headers.set(HttpHeaders.acceptEncodingHeader, 'gzip');
      final upstreamResp = await upstreamReq
          .close()
          .timeout(const Duration(seconds: 3));

      if (upstreamResp.statusCode == HttpStatus.ok) {
        final builder = BytesBuilder();
        await for (final chunk in upstreamResp) {
          builder.add(chunk);
        }
        final bytes = builder.takeBytes();
        if (bytes.isNotEmpty) {
          unawaited(_saveVectorTileToDiskCache(z, x, y, bytes));
          _setOnlinePreviewActive(true);
          await _serveVectorBytes(request, bytes);
          return true;
        }
      }
    } catch (e) {
      debugPrint('[LocalTileServer] Online vector proxy error ($z/$x/$y): $e');
    }
    return false;
  }

  /// Fetches raster DEM terrain tile from online provider (AWS Terrarium).
  Future<bool> _proxyOnlineTerrainTile(
    HttpRequest request,
    int z,
    int x,
    int y,
  ) async {
    final upstreamUrl = onlineTerrainFallbackUrlTemplate
        .replaceAll('{z}', '$z')
        .replaceAll('{x}', '$x')
        .replaceAll('{y}', '$y');

    try {
      final upstreamReq = await _httpClient
          .getUrl(Uri.parse(upstreamUrl))
          .timeout(const Duration(seconds: 3));
      final upstreamResp = await upstreamReq
          .close()
          .timeout(const Duration(seconds: 3));

      if (upstreamResp.statusCode == HttpStatus.ok) {
        final builder = BytesBuilder();
        await for (final chunk in upstreamResp) {
          builder.add(chunk);
        }
        final bytes = builder.takeBytes();
        if (bytes.isNotEmpty) {
          unawaited(_saveTerrainTileToDiskCache(z, x, y, bytes));
          await _serveRasterBytes(request, bytes);
          return true;
        }
      }
    } catch (e) {
      debugPrint('[LocalTileServer] Online terrain proxy error ($z/$x/$y): $e');
    }
    return false;
  }

  void _respondJson(HttpRequest request, int status, Map<String, dynamic> data) {
    final response = request.response;
    response.statusCode = status;
    response.headers.contentType = ContentType.json;
    response.headers.set(HttpHeaders.accessControlAllowOriginHeader, '*');
    response.write(jsonEncode(data));
    response.close();
  }
}
