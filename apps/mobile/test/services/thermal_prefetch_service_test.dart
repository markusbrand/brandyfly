import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:brandyfly/data/thermal/region_bounds_provider.dart';
import 'package:brandyfly/data/thermal/thermal_tile_store.dart';
import 'package:brandyfly/domain/thermal/geo_bounds.dart';
import 'package:brandyfly/domain/thermal/thermal_prefetch_planner.dart';
import 'package:brandyfly/domain/thermal/thermal_variant.dart';
import 'package:brandyfly/services/local_tile_server.dart';
import 'package:brandyfly/services/thermal_prefetch_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pmtiles_fixture.dart';

const _dachstein = GeoBounds(west: 13.5, south: 47.4, east: 13.9, north: 47.6);
const _tilesPerVariant = 47; // see thermal_prefetch_planner_test

/// Deterministic time source: sleeping advances the clock instantly.
class _FakeTime {
  _FakeTime(this.now);
  DateTime now;
  final sleeps = <Duration>[];
  Future<void> sleep(Duration d) async {
    sleeps.add(d);
    now = now.add(d);
  }
}

/// Scriptable KK7 fetcher.
class _FakeKk7 {
  _FakeKk7(this.time);
  final _FakeTime time;
  final requests = <Uri>[];
  final requestTimes = <DateTime>[];
  int inFlight = 0;
  int maxInFlight = 0;

  /// Return value / exception per call; default returns a small PNG.
  FutureOr<Uint8List?> Function(Uri uri, int call)? behaviour;

  Future<Uint8List?> call(Uri uri) async {
    requests.add(uri);
    requestTimes.add(time.now);
    inFlight++;
    if (inFlight > maxInFlight) maxInFlight = inFlight;
    try {
      await Future<void>.delayed(Duration.zero);
      final b = behaviour;
      if (b != null) return await b(uri, requests.length);
      return Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]);
    } finally {
      inFlight--;
    }
  }
}

void main() {
  late Directory tmp;
  late _FakeTime time;
  late _FakeKk7 kk7;
  late ThermalTileStore store;
  late bool autoEnabled;
  late ThermalPrefetchService service;

  String regionDir(String id) => '${tmp.path}/regions/$id';
  File tileFile(String id, String variantKey, TileCoord t) =>
      File('${regionDir(id)}/thermals/$variantKey/${t.z}/${t.x}/${t.y}.png');

  ThermalPrefetchService build() => ThermalPrefetchService(
    store: store,
    regions: RegionBoundsProvider(regionsBasePath: store.regionsBasePath),
    fetcher: kk7.call,
    clock: () => time.now,
    sleep: time.sleep,
    autoPrefetchEnabled: () => autoEnabled,
  );

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('thermal_prefetch_test');
    time = _FakeTime(DateTime(2026, 7, 15, 9));
    kk7 = _FakeKk7(time);
    store = ThermalTileStore(appSupportDir: tmp.path);
    autoEnabled = true;
    await writeHeaderOnlyPmtiles(regionDir('dachstein'), _dachstein);
    service = build();
  });

  tearDown(() async {
    service.dispose();
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('Scenario: coverage for a downloaded region in July', () async {
    await service.prefetchRegion('dachstein');
    final state = service.states['dachstein']!;
    expect(state.status, ThermalPrefetchStatus.complete);
    expect(state.totalTiles, 4 * _tilesPerVariant);
    expect(state.storedTiles, 4 * _tilesPerVariant);
    expect(state.percent, 100);
    expect(state.completeSeasons, [ThermalSeason.jul]);
    expect(state.bytes, 4 * _tilesPerVariant * 4);
    expect(kk7.requests, hasLength(4 * _tilesPerVariant));
    for (final key in ['jul_all', 'jul_04', 'jul_07', 'jul_10']) {
      for (final t in ThermalPrefetchPlanner.tiles(_dachstein)) {
        expect(tileFile('dachstein', key, t).existsSync(), isTrue);
      }
    }
    // Requests carry the src tag and TMS rows.
    expect(
      kk7.requests.every((u) => u.queryParameters['src'] == 'brandyfly'),
      isTrue,
    );
    final saved = jsonDecode(
      File('${regionDir('dachstein')}/thermals/state.json').readAsStringSync(),
    );
    expect(saved['status'], 'complete');
  });

  test('provider "no data" responses are stored as empty markers', () async {
    kk7.behaviour = (uri, call) => Uint8List(0);
    await service.prefetchRegion('dachstein');
    expect(service.states['dachstein']!.status, ThermalPrefetchStatus.complete);
    expect(
      tileFile('dachstein', 'jul_07', const TileCoord(0, 0, 0)).lengthSync(),
      0,
    );
  });

  test(
    'Scenario: interrupted prefetch resumes without re-downloading',
    () async {
      kk7.behaviour = (uri, call) {
        if (call > 100) throw const SocketException('network unreachable');
        return Uint8List.fromList([1]);
      };
      await service.prefetchRegion('dachstein');
      final partial = service.states['dachstein']!;
      expect(partial.status, ThermalPrefetchStatus.partial);
      expect(partial.lastError, 'offline');
      expect(partial.storedTiles, greaterThanOrEqualTo(99));
      expect(partial.storedTiles, lessThan(4 * _tilesPerVariant));

      final storedBefore = partial.storedTiles;
      final callsBefore = kk7.requests.length;
      kk7.behaviour = null; // connectivity restored
      await service.prefetchRegion('dachstein');
      final done = service.states['dachstein']!;
      expect(done.status, ThermalPrefetchStatus.complete);
      expect(done.storedTiles, 4 * _tilesPerVariant);
      expect(
        kk7.requests.length - callsBefore,
        4 * _tilesPerVariant - storedBefore,
      );
      // Same tile set as an uninterrupted run.
      final files = Directory('${regionDir('dachstein')}/thermals')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.png'))
          .length;
      expect(files, 4 * _tilesPerVariant);
    },
  );

  test('Scenario: rate limit (<=4 req/s) and concurrency (<=2)', () async {
    await service.prefetchRegion('dachstein');
    final ts = kk7.requestTimes;
    expect(ts.length, 4 * _tilesPerVariant);
    for (var i = 0; i + 4 < ts.length; i++) {
      expect(
        ts[i + 4].difference(ts[i]),
        greaterThanOrEqualTo(const Duration(seconds: 1)),
        reason: 'more than 4 requests within one second at $i',
      );
    }
    expect(kk7.maxInFlight, lessThanOrEqualTo(2));
    expect(kk7.maxInFlight, 2);
  });

  test('Scenario: throttling backs off exponentially, then succeeds', () async {
    var throttled = 0;
    kk7.behaviour = (uri, call) {
      if (uri.path.endsWith('/thermals_jul_07/5/17/20.png') && throttled < 3) {
        throttled++;
        throw const Kk7HttpException(429);
      }
      return Uint8List.fromList([1]);
    };
    await service.prefetchRegion('dachstein');
    expect(throttled, 3);
    expect(service.states['dachstein']!.status, ThermalPrefetchStatus.complete);
    final backoffs = time.sleeps.where((d) => d >= const Duration(seconds: 1));
    expect(backoffs.toList(), const [
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 4),
    ]);
  });

  test(
    'Scenario: persistent 5xx marks region partial, keeps stored tiles',
    () async {
      kk7.behaviour = (uri, call) {
        if (call > 20) throw const Kk7HttpException(503);
        return Uint8List.fromList([1]);
      };
      await service.prefetchRegion('dachstein');
      final s = service.states['dachstein']!;
      expect(s.status, ThermalPrefetchStatus.partial);
      expect(s.lastError, contains('503'));
      expect(s.storedTiles, greaterThanOrEqualTo(19));
      expect(prefetchBackoff(6), const Duration(seconds: 32));
      expect(prefetchBackoff(20), const Duration(minutes: 5));
      // Tiles stored so far stay usable for rendering.
      expect(
        await store.readFromRegions(
          ThermalVariant(ThermalSeason.jul, ThermalTimeOfDay.all),
          0,
          0,
          0,
        ),
        isNotNull,
      );
    },
  );

  group('season transitions and pruning', () {
    test('Scenario: lookahead in late season (10 August)', () async {
      time.now = DateTime(2026, 8, 10, 9);
      await service.prefetchRegion('dachstein');
      final s = service.states['dachstein']!;
      expect(s.status, ThermalPrefetchStatus.complete);
      expect(s.completeSeasons, [ThermalSeason.jul, ThermalSeason.oct]);
      expect(s.totalTiles, 8 * _tilesPerVariant);
    });

    test('Scenario: stale data kept during failed refresh, pruned after '
        'success', () async {
      await service.prefetchRegion('dachstein'); // July
      expect(
        Directory('${regionDir('dachstein')}/thermals/jul_07').existsSync(),
        isTrue,
      );

      time.now = DateTime(2026, 9, 5, 9); // oct required
      kk7.behaviour = (uri, call) => throw const SocketException('offline');
      await service.prefetchRegion('dachstein');
      expect(service.states['dachstein']!.status, ThermalPrefetchStatus.failed);
      expect(
        Directory('${regionDir('dachstein')}/thermals/jul_07').existsSync(),
        isTrue,
      );
      expect(
        await store.readFromRegions(
          ThermalVariant(ThermalSeason.jul, ThermalTimeOfDay.midday),
          0,
          0,
          0,
        ),
        isNotNull,
      );

      kk7.behaviour = null;
      await service.prefetchRegion('dachstein');
      final s = service.states['dachstein']!;
      expect(s.status, ThermalPrefetchStatus.complete);
      expect(s.completeSeasons, [ThermalSeason.oct]);
      for (final key in ['jul_all', 'jul_04', 'jul_07', 'jul_10']) {
        expect(
          Directory('${regionDir('dachstein')}/thermals/$key').existsSync(),
          isFalse,
        );
      }
    });
  });

  group('triggers', () {
    test('Scenario: automatic prefetch for a newly added region', () async {
      await service.start();
      expect(
        service.states['dachstein']!.status,
        ThermalPrefetchStatus.complete,
      );
      final calls = kk7.requests.length;

      // Re-running with everything complete does not fetch anything.
      await service.runAutomatic();
      expect(kk7.requests.length, calls);

      await writeHeaderOnlyPmtiles(
        regionDir('tiny'),
        const GeoBounds(west: 13.6, south: 47.5, east: 13.61, north: 47.51),
      );
      await service.notifyRegionsChanged();
      expect(service.states['tiny']!.status, ThermalPrefetchStatus.complete);
      expect(kk7.requests.length, greaterThan(calls));
    });

    test(
      'Scenario: required-variant change triggers the next season',
      () async {
        await service.runAutomatic();
        final calls = kk7.requests.length;
        time.now = DateTime(2026, 8, 1, 9); // lookahead window opens
        await service.runAutomatic();
        expect(kk7.requests.length - calls, 4 * _tilesPerVariant);
        expect(service.states['dachstein']!.completeSeasons, [
          ThermalSeason.jul,
          ThermalSeason.oct,
        ]);
      },
    );

    test('Scenario: opt-out suppresses automatic runs only', () async {
      autoEnabled = false;
      await service.start();
      await service.runAutomatic();
      await service.notifyRegionsChanged();
      expect(kk7.requests, isEmpty);
      expect(
        service.states['dachstein']!.status,
        ThermalPrefetchStatus.notPrefetched,
      );

      await service.prefetchRegion('dachstein'); // manual still works
      expect(
        service.states['dachstein']!.status,
        ThermalPrefetchStatus.complete,
      );
    });

    test(
      'offline failure schedules a retry and state survives restart',
      () async {
        kk7.behaviour = (uri, call) => throw TimeoutException('slow');
        await service.prefetchRegion('dachstein');
        expect(service.states['dachstein']!.lastError, 'offline');

        final restarted = build();
        await restarted.refreshStates();
        expect(
          restarted.states['dachstein']!.status,
          ThermalPrefetchStatus.failed,
        );
        restarted.dispose();
      },
    );

    test(
      'Scenario: region deletion removes its thermal tiles and state',
      () async {
        await service.prefetchRegion('dachstein');
        await Directory(regionDir('dachstein')).delete(recursive: true);
        await service.notifyRegionsChanged();
        expect(service.states.containsKey('dachstein'), isFalse);
        expect(
          await store.readFromRegions(
            ThermalVariant(ThermalSeason.jul, ThermalTimeOfDay.all),
            0,
            0,
            0,
          ),
          isNull,
        );
      },
    );
  });
}
