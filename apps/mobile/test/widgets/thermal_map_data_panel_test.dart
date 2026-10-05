import 'dart:io';
import 'dart:typed_data';

import 'package:brandyfly/data/thermal/region_bounds_provider.dart';
import 'package:brandyfly/data/thermal/thermal_tile_store.dart';
import 'package:brandyfly/domain/thermal/geo_bounds.dart';
import 'package:brandyfly/services/screen_manager_service.dart';
import 'package:brandyfly/services/thermal_prefetch_service.dart';
import 'package:brandyfly/widgets/settings/thermal_map_data_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pmtiles_fixture.dart';

/// Prefetch service with scripted states; records manual prefetch calls.
class _ScriptedService extends ThermalPrefetchService {
  _ScriptedService(String root)
    : super(
        store: ThermalTileStore(appSupportDir: root),
        regions: RegionBoundsProvider(regionsBasePath: () async => '$root/x'),
        fetcher: (_) async => Uint8List(0),
      );

  final manualCalls = <String>[];
  Map<String, RegionThermalState> scripted = {};

  @override
  Map<String, RegionThermalState> get states => scripted;

  void set(Map<String, RegionThermalState> s) {
    scripted = s;
    notifyListeners();
  }

  @override
  Future<void> prefetchRegion(String regionId) async {
    manualCalls.add(regionId);
  }

  @override
  Future<void> runAutomatic() async {}
}

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('thermal_panel_test');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  testWidgets('renders every prefetch state and retry triggers the service', (
    tester,
  ) async {
    final manager = ScreenManagerService();
    final service = _ScriptedService(tmp.path);
    service.set({
      'a-new': const RegionThermalState(regionId: 'a-new'),
      'b-busy': const RegionThermalState(
        regionId: 'b-busy',
        status: ThermalPrefetchStatus.inProgress,
        totalTiles: 100,
        storedTiles: 40,
      ),
      'c-done': const RegionThermalState(
        regionId: 'c-done',
        status: ThermalPrefetchStatus.complete,
        totalTiles: 4,
        storedTiles: 4,
        bytes: 12 * 1024 * 1024,
        completeVariants: {'jul_all', 'jul_04', 'jul_07', 'jul_10'},
      ),
      'd-partial': const RegionThermalState(
        regionId: 'd-partial',
        status: ThermalPrefetchStatus.partial,
        totalTiles: 10,
        storedTiles: 6,
        bytes: 2048,
        lastError: 'offline',
      ),
      'e-failed': const RegionThermalState(
        regionId: 'e-failed',
        status: ThermalPrefetchStatus.failed,
        lastError: 'KK7 unavailable (HTTP 503)',
      ),
    });

    await tester.pumpWidget(
      _host(ThermalMapDataPanel(screenManager: manager, service: service)),
    );

    expect(find.text('Not downloaded'), findsOneWidget);
    expect(find.text('Downloading… 40 %'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Complete · 12.0 MB · Summer (Jun-Aug)'), findsOneWidget);
    expect(find.text('Partial (60 %) · 2 KB · offline'), findsOneWidget);
    expect(find.text('Failed · KK7 unavailable (HTTP 503)'), findsOneWidget);

    // Busy regions cannot be re-triggered.
    final busyButton = tester.widget<IconButton>(
      find.byKey(const Key('thermal_retry_b-busy')),
    );
    expect(busyButton.onPressed, isNull);

    await tester.tap(find.byKey(const Key('thermal_retry_e-failed')));
    await tester.tap(find.byKey(const Key('thermal_retry_d-partial')));
    await tester.pump();
    expect(service.manualCalls, ['e-failed', 'd-partial']);

    // Progress updates are reflected live.
    service.set({
      'b-busy': const RegionThermalState(
        regionId: 'b-busy',
        status: ThermalPrefetchStatus.inProgress,
        totalTiles: 100,
        storedTiles: 75,
      ),
    });
    await tester.pump();
    expect(find.text('Downloading… 75 %'), findsOneWidget);
    service.dispose();
  });

  testWidgets('auto-prefetch switch updates the persisted setting', (
    tester,
  ) async {
    final manager = ScreenManagerService();
    final service = _ScriptedService(tmp.path);
    await tester.pumpWidget(
      _host(ThermalMapDataPanel(screenManager: manager, service: service)),
    );
    expect(find.text('No offline map regions downloaded yet.'), findsOneWidget);
    expect(manager.config.thermalAutoPrefetch, isTrue);
    await tester.tap(find.byKey(const Key('thermal_auto_prefetch_switch')));
    await tester.pump();
    expect(manager.config.thermalAutoPrefetch, isFalse);
    service.dispose();
  });

  testWidgets('real service lists a downloaded region as not downloaded', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await writeHeaderOnlyPmtiles(
        '${tmp.path}/regions/dachstein',
        const GeoBounds(west: 13.5, south: 47.4, east: 13.9, north: 47.6),
      );
    });
    final store = ThermalTileStore(appSupportDir: tmp.path);
    final service = ThermalPrefetchService(
      store: store,
      regions: RegionBoundsProvider(regionsBasePath: store.regionsBasePath),
      fetcher: (_) async => Uint8List(0),
      autoPrefetchEnabled: () => false,
    );
    await tester.runAsync(service.refreshStates);
    await tester.pumpWidget(
      _host(
        ThermalMapDataPanel(
          screenManager: ScreenManagerService(),
          service: service,
        ),
      ),
    );
    expect(find.text('dachstein'), findsOneWidget);
    expect(find.text('Not downloaded'), findsOneWidget);
    service.dispose();
  });

  testWidgets('web / unsupported platform message', (tester) async {
    await tester.pumpWidget(
      _host(
        ThermalMapDataPanel(
          screenManager: ScreenManagerService(),
          service: null,
        ),
      ),
    );
    expect(
      find.text('Thermal map prefetch is not available on this platform.'),
      findsOneWidget,
    );
  });
}
