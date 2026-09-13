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
  });
}
