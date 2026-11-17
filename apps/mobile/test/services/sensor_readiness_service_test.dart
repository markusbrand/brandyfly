import 'dart:async';

import 'package:brandyfly/data/repositories/telemetry_repository.dart';
import 'package:brandyfly/domain/models/sensor_readiness.dart';
import 'package:brandyfly/services/flight_replay_service.dart';
import 'package:brandyfly/services/sensor_readiness_service.dart';
import 'package:brandyfly/services/telemetry/telemetry_source.dart';
import 'package:brandyfly/services/telemetry/telemetry_types.dart';
import 'package:brandyfly_native/brandyfly_native.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeTelemetrySource implements ITelemetrySource {
  _FakeTelemetrySource({required this.sourceType, required this.name});

  @override
  final TelemetrySourceType sourceType;

  @override
  final String name;

  final _telemetryCtrl = StreamController<TelemetrySnapshot>.broadcast();
  final _rawCtrl = StreamController<dynamic>.broadcast();
  bool _running = false;
  bool _paused = false;

  @override
  Stream<TelemetrySnapshot> get telemetryStream => _telemetryCtrl.stream;

  @override
  Stream<dynamic> get rawSensorStream => _rawCtrl.stream;

  @override
  bool get isRunning => _running;

  @override
  bool get isPaused => _paused;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> start() async => _running = true;

  @override
  Future<void> pause() async => _paused = true;

  @override
  Future<void> stop() async => _running = false;

  void emit(TelemetrySnapshot snapshot) => _telemetryCtrl.add(snapshot);

  @override
  void dispose() {
    _telemetryCtrl.close();
    _rawCtrl.close();
  }
}

void main() {
  group('SensorReadinessService', () {
    late FlightReplayService replayService;
    late TelemetryRepository telemetryRepo;
    late DateTime now;

    setUp(() {
      now = DateTime.utc(2026, 11, 16, 15, 0, 0);
      replayService = FlightReplayService();
      telemetryRepo = TelemetryRepository(replayService: replayService);
    });

    tearDown(() {
      telemetryRepo.dispose();
      replayService.dispose();
    });

    test('probes capabilities and clears banner when Bluetooth vario connects with GPS', () async {
      final service = SensorReadinessService(
        telemetryRepository: telemetryRepo,
        probeCapabilities: () async => const NativeSensorCapabilities(
          hasBarometer: false,
          hasGps: true,
          locationEnabled: true,
          locationPermissionGranted: true,
          bluetoothAvailable: true,
        ),
        clock: () => now,
        enableWatchdog: false,
      );
      addTearDown(service.dispose);

      await service.refreshCapabilities();
      expect(service.state.shouldShowBanner, isTrue);
      expect(service.state.barometerStatus, SensorDomainStatus.hardwareMissing);
      expect(service.state.gpsStatus, SensorDomainStatus.waitingForFix);

      // Connect a BLE vario and emit a valid combined sample
      final bleSource = _FakeTelemetrySource(
        sourceType: TelemetrySourceType.ble,
        name: 'SkyDrop 1',
      );
      addTearDown(bleSource.dispose);
      telemetryRepo.attachSource(bleSource);
      service.updateExternalVarioState(ExternalVarioConnectionState.connected);

      bleSource.emit(
        TelemetrySnapshot(
          timestamp: now,
          altitude: 1200.0,
          pressureHpa: 877.2,
          vario: 1.5,
          speed: 36.0,
          heading: 180.0,
          latitude: 47.2692,
          longitude: 11.4041,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(service.state.isReady, isTrue);
      expect(service.state.shouldShowBanner, isFalse);

      // Simulate BLE vario disconnecting mid-session
      service.updateExternalVarioState(ExternalVarioConnectionState.disconnected);
      expect(service.state.isReady, isFalse);
      expect(service.state.shouldShowBanner, isTrue);
      expect(service.state.barometerStatus, SensorDomainStatus.disconnected);
    });

    test('transitions to stale after 5 seconds without samples', () async {
      final service = SensorReadinessService(
        telemetryRepository: telemetryRepo,
        probeCapabilities: () async => const NativeSensorCapabilities(
          hasBarometer: true,
          hasGps: true,
          locationEnabled: true,
          locationPermissionGranted: true,
        ),
        clock: () => now,
        enableWatchdog: false,
      );
      addTearDown(service.dispose);

      await service.refreshCapabilities();

      final internal = _FakeTelemetrySource(
        sourceType: TelemetrySourceType.internalSensor,
        name: 'Internal',
      );
      addTearDown(internal.dispose);
      telemetryRepo.attachSource(internal);

      internal.emit(
        TelemetrySnapshot(
          timestamp: now,
          altitude: 900.0,
          pressureHpa: 910.0,
          vario: 0.0,
          speed: 0.0,
          heading: 0.0,
          latitude: 47.26,
          longitude: 11.40,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(service.state.shouldShowBanner, isFalse);

      now = now.add(const Duration(seconds: 6));
      service.checkReadinessNow();
      expect(service.state.barometerStatus, SensorDomainStatus.stale);
      expect(service.state.gpsStatus, SensorDomainStatus.stale);
      expect(service.state.shouldShowBanner, isTrue);
    });

    test('suppresses banner during replay and restores on exit', () async {
      final service = SensorReadinessService(
        telemetryRepository: telemetryRepo,
        probeCapabilities: () async => NativeSensorCapabilities.unknown,
        clock: () => now,
        enableWatchdog: false,
      );
      addTearDown(service.dispose);

      await service.refreshCapabilities();
      expect(service.state.shouldShowBanner, isTrue);

      telemetryRepo.setReplayActive(true);
      expect(service.state.isReplayActive, isTrue);
      expect(service.state.shouldShowBanner, isFalse);

      telemetryRepo.setReplayActive(false);
      expect(service.state.isReplayActive, isFalse);
      expect(service.state.shouldShowBanner, isTrue);
    });
  });
}
