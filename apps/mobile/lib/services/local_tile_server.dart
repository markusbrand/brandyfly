import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'pmtiles_reader.dart';

/// Embedded loopback HTTP tile server running on `127.0.0.1` on an ephemeral port.
///
/// Serves standard OpenMapTiles vector tiles (`/tiles/{z}/{x}/{y}.pbf`) from local
/// PMTiles archives directly to MapLibre Native, bypassing platform URI limitations
/// on Android and iOS while avoiding main-thread disk I/O.
class LocalTileServer {
  LocalTileServer({
    this.onlineFallbackEnabled = true,
    this.onlineFallbackUrlTemplate =
        'https://tiles.openfreemap.org/planet/{z}/{x}/{y}.pbf',
    HttpClient? httpClient,
  }) : _httpClient = httpClient ?? HttpClient() {
    _httpClient.connectionTimeout = const Duration(seconds: 4);
  }

  final bool onlineFallbackEnabled;
  final String onlineFallbackUrlTemplate;
  final HttpClient _httpClient;

  HttpServer? _server;
  StreamSubscription<HttpRequest>? _serverSubscription;
  PMTilesReader? _primaryReader;
  PMTilesReader? _fallbackReader;
  String? _primaryArchivePath;
  String? _fallbackArchivePath;
  bool _isRunning = false;

  bool get isRunning => _isRunning;
  int get port => _server?.port ?? 0;
  String get baseUrl => 'http://127.0.0.1:$port';
  String get tilesUrlTemplate => '$baseUrl/tiles/{z}/{x}/{y}.pbf';

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

  /// Shuts down the HTTP server and releases open file handles.
  Future<void> stop() async {
    if (!_isRunning) return;
    _isRunning = false;

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

    try {
      _httpClient.close(force: true);
    } catch (_) {}

    debugPrint('[LocalTileServer] Stopped');
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
        });
        return;
      }

      if (path == '/tiles.json') {
        await _handleTileJson(request);
        return;
      }

      final tileMatch = RegExp(r'^/tiles/(\d+)/(\d+)/(\d+)\.pbf$').firstMatch(path);
      if (tileMatch != null) {
        final z = int.parse(tileMatch.group(1)!);
        final x = int.parse(tileMatch.group(2)!);
        final y = int.parse(tileMatch.group(3)!);
        await _handleTileRequest(request, z, x, y);
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

  /// Serves vector tile payloads from primary PMTiles, fallback PMTiles, or online proxy.
  Future<void> _handleTileRequest(
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
          await _serveTileBytes(request, tileBytes);
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
          await _serveTileBytes(request, tileBytes);
          return;
        }
      } catch (e) {
        debugPrint('[LocalTileServer] Fallback tile fetch error ($z/$x/$y): $e');
      }
    }

    // 3. Optional online vector tile fallback during simulation / dev
    if (onlineFallbackEnabled) {
      final handled = await _proxyOnlineTile(request, z, x, y);
      if (handled) return;
    }

    // 4. Return 204 No Content for missing tiles (standard in vector map rendering)
    request.response.statusCode = HttpStatus.noContent;
    await request.response.close();
  }

  /// Serves compressed tile payload directly to MapLibre.
  Future<void> _serveTileBytes(HttpRequest request, Uint8List tileBytes) async {
    final response = request.response;
    response.statusCode = HttpStatus.ok;
    response.headers.set(HttpHeaders.contentTypeHeader, 'application/x-protobuf');
    response.headers.set(HttpHeaders.contentEncodingHeader, 'gzip');
    response.headers.set(HttpHeaders.cacheControlHeader, 'public, max-age=86400');
    response.headers.set(HttpHeaders.accessControlAllowOriginHeader, '*');
    response.add(tileBytes);
    await response.close();
  }

  /// Fetches vector tile from online provider when outside local bounds.
  Future<bool> _proxyOnlineTile(HttpRequest request, int z, int x, int y) async {
    final upstreamUrl = onlineFallbackUrlTemplate
        .replaceAll('{z}', '$z')
        .replaceAll('{x}', '$x')
        .replaceAll('{y}', '$y');

    try {
      final upstreamReq = await _httpClient.getUrl(Uri.parse(upstreamUrl));
      upstreamReq.headers.set(HttpHeaders.acceptEncodingHeader, 'gzip');
      final upstreamResp = await upstreamReq.close();

      if (upstreamResp.statusCode == HttpStatus.ok) {
        final response = request.response;
        response.statusCode = HttpStatus.ok;
        response.headers.set(
          HttpHeaders.contentTypeHeader,
          upstreamResp.headers.value(HttpHeaders.contentTypeHeader) ??
              'application/x-protobuf',
        );

        final encoding = upstreamResp.headers.value(HttpHeaders.contentEncodingHeader);
        if (encoding != null) {
          response.headers.set(HttpHeaders.contentEncodingHeader, encoding);
        }

        response.headers.set(HttpHeaders.cacheControlHeader, 'public, max-age=86400');
        response.headers.set(HttpHeaders.accessControlAllowOriginHeader, '*');
        await response.addStream(upstreamResp);
        await response.close();
        return true;
      }
    } catch (e) {
      // Network error or timeout - silently proceed to 204
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
