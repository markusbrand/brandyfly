import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:brandyfly/data/thermal/region_bounds_provider.dart';
import 'package:brandyfly/data/thermal/thermal_tile_store.dart';
import 'package:brandyfly/domain/thermal/geo_bounds.dart';
import 'package:brandyfly/services/thermal_prefetch_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pmtiles_fixture.dart';

/// Thermal prefetch runs on the UI isolate with asynchronous I/O only. This
/// test stresses it far beyond the production rate limit (4 req/s) and
/// checks that a 50 Hz telemetry-style timer keeps firing on time, i.e. the
/// event loop is never blocked long enough to cause visible stutter.
void main() {
  test('prefetch I/O does not block a 50 Hz telemetry loop', () async {
    final tmp = await Directory.systemTemp.createTemp('thermal_prefetch_perf');
    addTearDown(() => tmp.delete(recursive: true));
    await writeHeaderOnlyPmtiles(
      '${tmp.path}/regions/dachstein',
      const GeoBounds(west: 13.3, south: 47.3, east: 14.1, north: 47.8),
    );
    final store = ThermalTileStore(appSupportDir: tmp.path);
    final png = Uint8List(1500); // typical KK7 tile size
    final clockBase = DateTime(2026, 7, 15);
    final wall = Stopwatch()..start();
    final service = ThermalPrefetchService(
      store: store,
      regions: RegionBoundsProvider(regionsBasePath: store.regionsBasePath),
      fetcher: (_) async => png,
      clock: () => clockBase.add(wall.elapsed), // July, advancing in real time
      maxRequestsPerSecond: 1000, // stress: 250x the production limit
    );
    addTearDown(service.dispose);

    const period = Duration(milliseconds: 20);
    final lateness = <int>[];
    final sw = Stopwatch()..start();
    var expected = period.inMicroseconds;
    final timer = Timer.periodic(period, (_) {
      lateness.add(sw.elapsedMicroseconds - expected);
      expected += period.inMicroseconds;
    });

    await service.prefetchRegion('dachstein');
    timer.cancel();

    final state = service.states['dachstein']!;
    expect(state.status, ThermalPrefetchStatus.complete);
    expect(lateness.length, greaterThan(5));
    lateness.sort();
    final p95 = lateness[(lateness.length * 0.95).floor()];
    final max = lateness.last;
    // ignore: avoid_print
    print(
      'prefetch ${state.storedTiles} tiles in ${sw.elapsedMilliseconds} ms; '
      'telemetry timer lateness p95=${p95 ~/ 1000} ms max=${max ~/ 1000} ms',
    );
    expect(p95, lessThan(16000), reason: 'p95 lateness exceeds one frame');
    expect(max, lessThan(50000), reason: 'event loop blocked > 50 ms');
  });
}
