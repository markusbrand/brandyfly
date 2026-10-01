import 'dart:async';
import 'dart:convert';

import 'package:brandyfly/data/repositories/layout_repository.dart';
import 'package:brandyfly/data/repositories/telemetry_repository.dart';
import 'package:brandyfly/data/services/ui_persistence_service.dart';
import 'package:brandyfly/domain/models/ui_config.dart';
import 'package:brandyfly/models/flight_model.dart';
import 'package:brandyfly/services/flight_replay_service.dart';
import 'package:brandyfly/services/telemetry/telemetry_source.dart';
import 'package:brandyfly/services/telemetry/telemetry_types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _key = 'brandyfly_ui_config_v1';

class _FailingPersistence extends UIPersistenceService {
  _FailingPersistence(super.prefs);
  @override
  Future<bool> writeRaw(String raw) async => throw StateError('disk full');
}

Map<String, dynamic> _legacy8Config() => {
  'navBarStyle': 'translucentDrawer',
  'activeScreenId': 'normal_flight',
  'screens': [
    {
      'id': 'normal_flight',
      'name': 'Normal',
      'gridResolution': 8,
      'widgets': [
        {'id': 'm', 'type': 'map', 'x': 0, 'y': 0, 'w': 8, 'h': 8},
        {'id': 'a', 'type': 'altitude', 'x': 6, 'y': 2, 'w': 2, 'h': 2},
      ],
    },
  ],
};

void main() {
  group('LayoutRepository', () {
    test('loads defaults when storage is empty', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = LayoutRepository.load(await UIPersistenceService.init());
      expect(repo.loadOutcome, LayoutLoadOutcome.defaults);
      expect(repo.config.screens, isNotEmpty);
    });

    test('migrates v2 payload, keeps backup and saves v3', () async {
      final raw = jsonEncode(_legacy8Config());
      SharedPreferences.setMockInitialValues({_key: raw});
      final persistence = await UIPersistenceService.init();
      final repo = LayoutRepository.load(persistence);

      expect(repo.loadOutcome, LayoutLoadOutcome.migrated);
      final alt = repo.config.screens
          .firstWhere((s) => s.id == 'normal_flight')
          .widgets
          .firstWhere((w) => w.id == 'a');
      expect([alt.x, alt.y, alt.w, alt.h], [12, 8, 4, 8]);

      await pumpEventQueue();
      expect(persistence.readBackup(2), raw);
      final saved = jsonDecode(persistence.readRaw()!) as Map<String, dynamic>;
      expect(saved['schemaVersion'], GridSpec.schemaVersion);
      expect(
        ((saved['screens'] as List).first as Map)['gridResolution'],
        GridSpec.columns,
      );
    });

    test('current schema loads without migration or backup', () async {
      final raw = UIConfig.defaultConfig().encodeJson();
      SharedPreferences.setMockInitialValues({_key: raw});
      final persistence = await UIPersistenceService.init();
      final repo = LayoutRepository.load(persistence);
      await pumpEventQueue();
      expect(repo.loadOutcome, LayoutLoadOutcome.loaded);
      expect(persistence.readBackup(3), isNull);
    });

    test('corrupted payload falls back to defaults and keeps backup', () async {
      SharedPreferences.setMockInitialValues({_key: '{not json'});
      final persistence = await UIPersistenceService.init();
      final repo = LayoutRepository.load(persistence);
      await pumpEventQueue();
      expect(repo.loadOutcome, LayoutLoadOutcome.recoveredFromCorruption);
      expect(repo.config.activeScreenId, 'normal_flight');
      expect(persistence.readBackup(0), '{not json');
    });

    test('replace notifies once and persists', () async {
      SharedPreferences.setMockInitialValues({});
      final persistence = await UIPersistenceService.init();
      final repo = LayoutRepository(persistence: persistence);
      var notifications = 0;
      repo.addListener(() => notifications++);

      repo.replace(repo.config.copyWith(activeScreenId: 'map_screen'));
      repo.replace(repo.config); // identical -> ignored
      await pumpEventQueue();

      expect(notifications, 1);
      expect(
        UIConfig.decodeJson(persistence.readRaw()!).activeScreenId,
        'map_screen',
      );
    });

    test('write failure keeps in-memory change and reports error', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = LayoutRepository(persistence: _FailingPersistence(prefs));

      repo.replace(repo.config.copyWith(activeScreenId: 'thermaling'));
      await pumpEventQueue();

      expect(repo.config.activeScreenId, 'thermaling');
      expect(repo.lastSaveError.value, isA<StateError>());
    });

    test('updateScreen ignores unchanged screens', () {
      final repo = LayoutRepository();
      var notifications = 0;
      repo.addListener(() => notifications++);
      repo.updateScreen('normal_flight', (s) => s);
      expect(notifications, 0);
      repo.updateScreen('normal_flight', (s) => s.copyWith(name: 'Renamed'));
      expect(notifications, 1);
      expect(repo.config.screens.first.name, 'Renamed');
    });
  });

  group('TelemetryRepository', () {
    var tick = 0;
    TelemetrySnapshot snap(double alt) => TelemetrySnapshot(
      timestamp: DateTime.utc(2026).add(Duration(seconds: tick++)),
      altitude: alt,
      vario: 1.0,
      speed: 30,
      heading: 90,
      latitude: 47,
      longitude: 13,
    );

    test('emits one notification per live source tick', () {
      final replay = FlightReplayService();
      final repo = TelemetryRepository(replayService: replay);
      var notifications = 0;
      repo.telemetry.addListener(() => notifications++);

      for (var i = 0; i < 5; i++) {
        repo.onSnapshot(snap(1000.0 + i));
      }
      expect(notifications, 5);
      expect(repo.telemetry.value.altitude, 1004.0);
      expect(repo.telemetry.value.history.length, 5);
      repo.dispose();
      replay.dispose();
    });

    test('history is sampled at 1 Hz without per-tick list allocation', () {
      final replay = FlightReplayService();
      final repo = TelemetryRepository(replayService: replay);
      final base = DateTime.utc(2026);
      final seen = <List<double>>{};
      for (var i = 0; i < 50; i++) {
        repo.onSnapshot(
          TelemetrySnapshot(
            timestamp: base.add(Duration(milliseconds: i * 100)), // 10 Hz
            altitude: 1000.0 + i,
            vario: 0,
            speed: 30,
            heading: 0,
            latitude: 47,
            longitude: 13,
          ),
        );
        seen.add(repo.telemetry.value.history);
      }
      expect(repo.telemetry.value.history.length, 5);
      expect(seen.length, 5, reason: 'one new history list per second');
      repo.dispose();
      replay.dispose();
    });

    test('attached source stream drives telemetry', () async {
      final replay = FlightReplayService();
      final repo = TelemetryRepository(replayService: replay);
      final controller = StreamController<TelemetrySnapshot>();
      final source = _StreamSource(controller.stream);
      repo.attachSource(source);
      controller.add(snap(1234));
      await pumpEventQueue();
      expect(repo.telemetry.value.altitude, 1234);
      repo.detachSource();
      expect(repo.telemetry.value.altitude, 1450.0);
      await controller.close();
      repo.dispose();
      replay.dispose();
    });

    test('replay mode passes replay telemetry through unchanged', () {
      final flight = FlightModel(
        id: 'f',
        title: 'Test',
        date: DateTime.utc(2026),
        points: [
          for (var i = 0; i < 3; i++)
            FlightPoint(
              timestamp: DateTime.utc(2026).add(Duration(seconds: i)),
              latitude: 47 + i * 0.001,
              longitude: 13,
              altitude: 1500.0 + i,
              vario: 0.5,
              speed: 35,
              heading: 10,
            ),
        ],
      );
      final replay = FlightReplayService(flight: flight);
      final repo = TelemetryRepository(replayService: replay);
      repo.setReplayActive(true);
      expect(repo.telemetry.value.altitude, 1500.0);

      replay.seekTo(2);
      expect(repo.telemetry.value.altitude, 1502.0);
      expect(
        repo.telemetry.value.altitude,
        (replay.currentTelemetry['altitude'] as num).toDouble(),
      );

      // Live snapshots are ignored while replaying.
      repo.onSnapshot(snap(10));
      expect(repo.telemetry.value.altitude, 1502.0);

      repo.setReplayActive(false);
      expect(repo.telemetry.value.altitude, 10);
      repo.dispose();
      replay.dispose();
    });
  });
}

class _StreamSource implements ITelemetrySource {
  _StreamSource(this.telemetryStream);
  @override
  final Stream<TelemetrySnapshot> telemetryStream;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
