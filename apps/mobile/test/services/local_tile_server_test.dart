import 'dart:convert';
import 'dart:io';

import 'package:brandyfly/services/local_tile_server.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalTileServer', () {
    late LocalTileServer server;
    late HttpClient client;
    late String overviewPath;

    setUp(() {
      client = HttpClient();
      server = LocalTileServer(onlineFallbackEnabled: false);
      overviewPath = File('assets/map_data/global_overview.pmtiles').existsSync()
          ? 'assets/map_data/global_overview.pmtiles'
          : 'apps/mobile/assets/map_data/global_overview.pmtiles';
    });

    tearDown(() async {
      client.close(force: true);
      await server.stop();
    });

    test('allocates loopback port and responds to /health', () async {
      expect(server.isRunning, isFalse);
      final port = await server.start();
      expect(port, greaterThan(0));
      expect(server.isRunning, isTrue);
      expect(server.port, equals(port));
      expect(server.baseUrl, equals('http://127.0.0.1:$port'));

      final req = await client.getUrl(Uri.parse('${server.baseUrl}/health'));
      final resp = await req.close();
      expect(resp.statusCode, equals(HttpStatus.ok));
      final body = await resp.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      expect(json['status'], equals('ok'));
      expect(json['port'], equals(port));
    });

    test('serves local PMTiles tile with gzip and protobuf headers', () async {
      await server.start();
      await server.setFallbackArchive(overviewPath);

      // Disable auto-decompress on client so we can verify raw Content-Encoding
      client.autoUncompress = false;

      final req = await client.getUrl(Uri.parse('${server.baseUrl}/tiles/0/0/0.pbf'));
      final resp = await req.close();
      expect(resp.statusCode, equals(HttpStatus.ok));
      expect(resp.headers.value(HttpHeaders.contentTypeHeader), equals('application/x-protobuf'));
      expect(resp.headers.value(HttpHeaders.contentEncodingHeader), equals('gzip'));
      expect(resp.headers.value(HttpHeaders.cacheControlHeader), contains('public'));

      final bytes = <int>[];
      await for (final chunk in resp) {
        bytes.addAll(chunk);
      }
      expect(bytes.isNotEmpty, isTrue);
      final decompressed = gzip.decode(bytes);
      expect(decompressed, equals([0x1a, 0x04, 0x74, 0x65, 0x73, 0x74]));
    });

    test('serves /tiles.json with correct TileJSON schema and tiles URL', () async {
      await server.start();
      await server.setFallbackArchive(overviewPath);

      final req = await client.getUrl(Uri.parse('${server.baseUrl}/tiles.json'));
      final resp = await req.close();
      expect(resp.statusCode, equals(HttpStatus.ok));

      final body = await resp.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      expect(json['tilejson'], equals('3.0.0'));
      expect(json['tiles'], equals(['${server.baseUrl}/tiles/{z}/{x}/{y}.pbf']));
      expect(json['name'], equals('BrandyFly Global Overview'));
    });

    test('returns 204 No Content for missing tile when online fallback is disabled', () async {
      await server.start();
      await server.setFallbackArchive(overviewPath);

      final req = await client.getUrl(Uri.parse('${server.baseUrl}/tiles/1/0/0.pbf'));
      final resp = await req.close();
      expect(resp.statusCode, equals(HttpStatus.noContent));
    });

    test('returns 404 for unknown route', () async {
      await server.start();

      final req = await client.getUrl(Uri.parse('${server.baseUrl}/unknown-path'));
      final resp = await req.close();
      expect(resp.statusCode, equals(HttpStatus.notFound));
    });

    test('supports setting primary archive and updates status', () async {
      await server.start();
      await server.setPrimaryArchive(overviewPath);

      final req = await client.getUrl(Uri.parse('${server.baseUrl}/health'));
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      expect(json['primaryLoaded'], isTrue);
      expect(json['fallbackLoaded'], isFalse);
    });

    test('stop shuts down server cleanly', () async {
      await server.start();
      expect(server.isRunning, isTrue);
      await server.stop();
      expect(server.isRunning, isFalse);
    });

    test('retains resilient default snapshot template and supports dynamic discovery', () async {
      final defaultServer = LocalTileServer();
      expect(
        defaultServer.onlineFallbackUrlTemplate,
        contains('20260906_080001_pt'),
      );
    });

    test('proxies online tile, caches to disk, and serves offline on subsequent requests', () async {
      final mockUpstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      int upstreamHits = 0;
      final fakeGzipTile = gzip.encode([0x1a, 0x02, 0x03, 0x04]);

      mockUpstream.listen((req) async {
        upstreamHits++;
        if (req.uri.path == '/tiles/5/10/15.pbf') {
          req.response.statusCode = HttpStatus.ok;
          req.response.headers.set(HttpHeaders.contentTypeHeader, 'application/x-protobuf');
          req.response.headers.set(HttpHeaders.contentEncodingHeader, 'gzip');
          req.response.add(fakeGzipTile);
          await req.response.close();
        } else {
          req.response.statusCode = HttpStatus.notFound;
          await req.response.close();
        }
      });

      final tempDir = await Directory.systemTemp.createTemp('tile_cache_test');
      final fallbackServer = LocalTileServer(
        onlineFallbackEnabled: true,
        onlineFallbackUrlTemplate: 'http://127.0.0.1:${mockUpstream.port}/tiles/{z}/{x}/{y}.pbf',
        cacheDirectoryPath: tempDir.path,
      );

      client.autoUncompress = false;

      try {
        await fallbackServer.start();
        expect(fallbackServer.isOnlinePreviewActive, isFalse);

        // 1. Initial request triggers online proxy
        final req1 = await client.getUrl(Uri.parse('${fallbackServer.baseUrl}/tiles/5/10/15.pbf'));
        final resp1 = await req1.close();
        expect(resp1.statusCode, equals(HttpStatus.ok));
        final body1 = await resp1.fold<List<int>>([], (acc, c) => acc..addAll(c));
        expect(body1, equals(fakeGzipTile));
        expect(upstreamHits, equals(1));
        expect(fallbackServer.isOnlinePreviewActive, isTrue);

        // Wait briefly for async cache write
        final cachedFile = File('${tempDir.path}/vector_tiles/5/10/15.pbf');
        for (int i = 0; i < 20; i++) {
          if (await cachedFile.exists()) break;
          await Future.delayed(const Duration(milliseconds: 50));
        }
        expect(await cachedFile.exists(), isTrue);
        expect(await cachedFile.readAsBytes(), equals(fakeGzipTile));

        // 2. Shut down mock upstream to simulate going completely offline
        await mockUpstream.close(force: true);

        // 3. Subsequent request served directly from disk cache without network
        final req2 = await client.getUrl(Uri.parse('${fallbackServer.baseUrl}/tiles/5/10/15.pbf'));
        final resp2 = await req2.close();
        expect(resp2.statusCode, equals(HttpStatus.ok));
        final body2 = await resp2.fold<List<int>>([], (acc, c) => acc..addAll(c));
        expect(body2, equals(fakeGzipTile));
        expect(fallbackServer.isOnlinePreviewActive, isTrue);

        // 4. Loading a regional primary archive clears isOnlinePreviewActive
        await fallbackServer.setPrimaryArchive(overviewPath);
        expect(fallbackServer.isOnlinePreviewActive, isFalse);
      } finally {
        await fallbackServer.stop();
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      }
    });

    test('returns 204 No Content within timeout when online upstream fails or is disconnected', () async {
      final fallbackServer = LocalTileServer(
        onlineFallbackEnabled: true,
        onlineFallbackUrlTemplate: 'http://127.0.0.1:1/tiles/{z}/{x}/{y}.pbf',
      );

      try {
        await fallbackServer.start();
        final stopwatch = Stopwatch()..start();
        final req = await client.getUrl(Uri.parse('${fallbackServer.baseUrl}/tiles/9/9/9.pbf'));
        final resp = await req.close();
        stopwatch.stop();

        expect(resp.statusCode, equals(HttpStatus.noContent));
        expect(stopwatch.elapsedMilliseconds, lessThan(3500));
      } finally {
        await fallbackServer.stop();
      }
    });

    test('serves terrain tile from online proxy and caches to disk', () async {
      final mockUpstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      int upstreamTerrainHits = 0;
      final fakePngBytes = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x01];

      mockUpstream.listen((req) async {
        upstreamTerrainHits++;
        if (req.uri.path == '/terrain/8/135/88.png') {
          req.response.statusCode = HttpStatus.ok;
          req.response.headers.set(HttpHeaders.contentTypeHeader, 'image/png');
          req.response.add(fakePngBytes);
          await req.response.close();
        } else {
          req.response.statusCode = HttpStatus.notFound;
          await req.response.close();
        }
      });

      final tempDir = await Directory.systemTemp.createTemp('terrain_cache_test');
      final fallbackServer = LocalTileServer(
        onlineFallbackEnabled: true,
        onlineTerrainFallbackUrlTemplate: 'http://127.0.0.1:${mockUpstream.port}/terrain/{z}/{x}/{y}.png',
        cacheDirectoryPath: tempDir.path,
      );

      try {
        await fallbackServer.start();

        // 1. Initial request triggers online proxy
        final req1 = await client.getUrl(Uri.parse('${fallbackServer.baseUrl}/terrain/8/135/88.png'));
        final resp1 = await req1.close();
        expect(resp1.statusCode, equals(HttpStatus.ok));
        expect(resp1.headers.value(HttpHeaders.contentTypeHeader), equals('image/png'));
        final body1 = await resp1.fold<List<int>>([], (acc, c) => acc..addAll(c));
        expect(body1, equals(fakePngBytes));
        expect(upstreamTerrainHits, equals(1));

        // Wait briefly for async cache write
        final cachedFile = File('${tempDir.path}/terrain_tiles/8/135/88.png');
        for (int i = 0; i < 20; i++) {
          if (await cachedFile.exists()) break;
          await Future.delayed(const Duration(milliseconds: 50));
        }
        expect(await cachedFile.exists(), isTrue);
        expect(await cachedFile.readAsBytes(), equals(fakePngBytes));

        // 2. Shut down upstream
        await mockUpstream.close(force: true);

        // 3. Subsequent request served directly from disk cache
        final req2 = await client.getUrl(Uri.parse('${fallbackServer.baseUrl}/terrain/8/135/88.png'));
        final resp2 = await req2.close();
        expect(resp2.statusCode, equals(HttpStatus.ok));
        final body2 = await resp2.fold<List<int>>([], (acc, c) => acc..addAll(c));
        expect(body2, equals(fakePngBytes));
      } finally {
        await fallbackServer.stop();
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      }
    });

    test('returns 204 No Content for missing terrain tile when offline', () async {
      final fallbackServer = LocalTileServer(
        onlineFallbackEnabled: true,
        onlineTerrainFallbackUrlTemplate: 'http://127.0.0.1:1/terrain/{z}/{x}/{y}.png',
      );

      try {
        await fallbackServer.start();
        final req = await client.getUrl(Uri.parse('${fallbackServer.baseUrl}/terrain/10/1/1.png'));
        final resp = await req.close();
        expect(resp.statusCode, equals(HttpStatus.noContent));
      } finally {
        await fallbackServer.stop();
      }
    });
  });
}
