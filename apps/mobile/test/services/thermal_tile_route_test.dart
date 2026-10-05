import 'dart:io';

import 'package:brandyfly/data/thermal/thermal_tile_store.dart';
import 'package:brandyfly/data/thermal/transparent_tile.dart';
import 'package:brandyfly/domain/thermal/thermal_variant.dart';
import 'package:brandyfly/services/local_tile_server.dart';
import 'package:flutter_test/flutter_test.dart';

Future<(int, List<int>, String?)> _get(HttpClient client, String url) async {
  final req = await client.getUrl(Uri.parse(url));
  final resp = await req.close();
  final body = await resp.fold<List<int>>([], (a, c) => a..addAll(c));
  return (
    resp.statusCode,
    body,
    resp.headers.value(HttpHeaders.contentTypeHeader),
  );
}

void main() {
  group('LocalTileServer thermal route', () {
    late Directory tmp;
    late HttpClient client;
    HttpServer? upstream;
    LocalTileServer? server;
    final fakePng = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 7, 7];

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('thermal_route_test');
      client = HttpClient();
    });

    tearDown(() async {
      client.close(force: true);
      await server?.stop();
      server = null;
      await upstream?.close(force: true);
      upstream = null;
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    Future<LocalTileServer> startServer({
      bool online = true,
      Duration timeout = const Duration(seconds: 5),
    }) async {
      final s = LocalTileServer(
        onlineFallbackEnabled: false,
        thermalStore: ThermalTileStore(appSupportDir: tmp.path),
        thermalBaseUrl: upstream == null
            ? 'http://127.0.0.1:9'
            : 'http://127.0.0.1:${upstream!.port}',
        thermalOnlineEnabled: online,
        thermalTimeout: timeout,
      );
      await s.start();
      server = s;
      return s;
    }

    test(
      'Scenario: offline with prefetched region serves local tile',
      () async {
        await ThermalTileStore.writeAtomic(
          File('${tmp.path}/regions/alps/thermals/jul_07/10/545/664.png'),
          fakePng,
        );
        final s = await startServer(online: false);
        final (status, body, type) = await _get(
          client,
          '${s.baseUrl}/thermals/jul_07/10/545/664.png',
        );
        expect(status, HttpStatus.ok);
        expect(type, 'image/png');
        expect(body, fakePng);
      },
    );

    test(
      'Scenario: offline without local tiles serves transparent 200',
      () async {
        final s = await startServer(online: false);
        final (status, body, _) = await _get(
          client,
          '${s.baseUrl}/thermals/jul_07/10/545/664.png',
        );
        expect(status, HttpStatus.ok);
        expect(body, transparentTilePng);
      },
    );

    test('online fetch uses TMS row, src parameter, no identifiers, and fills '
        'the persistent cache', () async {
      final requests = <HttpRequest>[];
      upstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      upstream!.listen((req) async {
        requests.add(req);
        req.response.headers.contentType = ContentType('image', 'png');
        req.response.add(fakePng);
        await req.response.close();
      });
      final s = await startServer();

      final (status, body, _) = await _get(
        client,
        '${s.baseUrl}/thermals/jul_07/10/545/664.png',
      );
      expect(status, HttpStatus.ok);
      expect(body, fakePng);
      expect(requests, hasLength(1));
      final r = requests.single;
      expect(r.uri.path, '/tiles/thermals_jul_07/10/545/359.png');
      expect(r.uri.queryParameters, {'src': 'brandyfly'});
      expect(r.headers.value(HttpHeaders.userAgentHeader), 'BrandyFly');
      expect(r.headers.value(HttpHeaders.cookieHeader), isNull);
      expect(r.headers.value('x-device-id'), isNull);

      final cached = File('${tmp.path}/thermal_cache/jul_07/10/545/664.png');
      for (var i = 0; i < 20 && !cached.existsSync(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      expect(cached.readAsBytesSync(), fakePng);

      // Scenario: online browsing populates cache -> later offline view.
      await upstream!.close(force: true);
      upstream = null;
      final (status2, body2, _) = await _get(
        client,
        '${s.baseUrl}/thermals/jul_07/10/545/664.png',
      );
      expect(status2, HttpStatus.ok);
      expect(body2, fakePng);
      expect(requests, hasLength(1));
    });

    test(
      'provider 404 is cached as empty marker and served transparent',
      () async {
        var hits = 0;
        upstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        upstream!.listen((req) async {
          hits++;
          req.response.statusCode = HttpStatus.notFound;
          await req.response.close();
        });
        final s = await startServer();
        for (var i = 0; i < 2; i++) {
          final (status, body, _) = await _get(
            client,
            '${s.baseUrl}/thermals/oct_all/9/270/180.png',
          );
          expect(status, HttpStatus.ok);
          expect(body, transparentTilePng);
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        expect(hits, 1);
        expect(
          File('${tmp.path}/thermal_cache/oct_all/9/270/180.png').lengthSync(),
          0,
        );
      },
    );

    test('Scenario: provider unreachable / slow -> transparent tile', () async {
      upstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final pending = <HttpRequest>[];
      upstream!.listen(pending.add); // never answers
      final s = await startServer(timeout: const Duration(milliseconds: 300));
      final sw = Stopwatch()..start();
      final (status, body, _) = await _get(
        client,
        '${s.baseUrl}/thermals/jul_04/8/136/90.png',
      );
      expect(status, HttpStatus.ok);
      expect(body, transparentTilePng);
      expect(sw.elapsed, lessThan(const Duration(seconds: 3)));
      expect(
        File('${tmp.path}/thermal_cache/jul_04/8/136/90.png').existsSync(),
        isFalse,
      );
    });

    test('invalid variants and zoom levels never error', () async {
      final s = await startServer(online: false);
      final (status, _, _) = await _get(
        client,
        '${s.baseUrl}/thermals/foo_07/8/1/1.png',
      );
      expect(status, HttpStatus.notFound);
      final (status2, body2, _) = await _get(
        client,
        '${s.baseUrl}/thermals/jul_07/14/1/1.png',
      );
      expect(status2, HttpStatus.ok);
      expect(body2, transparentTilePng);
    });

    test('thermal URL template points at the loopback route', () async {
      final s = await startServer(online: false);
      expect(
        s.thermalUrlTemplate(
          ThermalVariant(ThermalSeason.jul, ThermalTimeOfDay.midday),
        ),
        '${s.baseUrl}/thermals/jul_07/{z}/{x}/{y}.png',
      );
    });
  });
}
