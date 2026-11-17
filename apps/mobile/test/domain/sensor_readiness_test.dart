import 'package:brandyfly/domain/models/sensor_readiness.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 11, 16, 12, 0, 0);

  group('SensorReadinessEvaluator', () {
    test('reports missing barometer and missing GPS when hardware is absent', () {
      final state = SensorReadinessEvaluator.evaluate(
        capabilities: SensorCapabilities.unknown,
        input: const LiveSensorInput(hasLiveSource: false),
        now: now,
      );

      expect(state.barometerStatus, SensorDomainStatus.hardwareMissing);
      expect(state.gpsStatus, SensorDomainStatus.hardwareMissing);
      expect(state.isReady, isFalse);
      expect(state.shouldShowBanner, isTrue);
      expect(state.missingDomains, ['Barometer', 'GPS']);
      expect(state.warningMessage, contains('No barometer'));
      expect(state.warningMessage, contains('GPS missing'));
    });

    test('reports missing barometer when onboard GPS is active', () {
      final state = SensorReadinessEvaluator.evaluate(
        capabilities: const SensorCapabilities(
          hasBarometer: false,
          hasGps: true,
          locationEnabled: true,
          locationPermissionGranted: true,
        ),
        input: LiveSensorInput(
          hasLiveSource: true,
          hasBaroSample: false,
          hasGpsSample: true,
          lastGpsSampleAt: now,
          isSampleValid: true,
        ),
        now: now,
      );

      expect(state.barometerStatus, SensorDomainStatus.hardwareMissing);
      expect(state.gpsStatus, SensorDomainStatus.availableReady);
      expect(state.isReady, isFalse);
      expect(state.shouldShowBanner, isTrue);
      expect(state.missingDomains, ['Barometer']);
      expect(state.warningMessage, contains('Bluetooth vario'));
    });

    test('reports permissionDenied or disabled when barometer is ready but GPS lacks permission or toggle', () {
      final denied = SensorReadinessEvaluator.evaluate(
        capabilities: const SensorCapabilities(
          hasBarometer: true,
          hasGps: true,
          locationEnabled: true,
          locationPermissionGranted: false,
        ),
        input: LiveSensorInput(
          hasLiveSource: true,
          hasBaroSample: true,
          lastBaroSampleAt: now,
          hasGpsSample: false,
          isSampleValid: true,
        ),
        now: now,
      );

      expect(denied.barometerStatus, SensorDomainStatus.availableReady);
      expect(denied.gpsStatus, SensorDomainStatus.permissionDenied);
      expect(denied.shouldShowBanner, isTrue);
      expect(denied.warningMessage, contains('GPS permission required'));

      final disabled = SensorReadinessEvaluator.evaluate(
        capabilities: const SensorCapabilities(
          hasBarometer: true,
          hasGps: true,
          locationEnabled: false,
          locationPermissionGranted: true,
        ),
        input: LiveSensorInput(
          hasLiveSource: true,
          hasBaroSample: true,
          lastBaroSampleAt: now,
          hasGpsSample: false,
          isSampleValid: true,
        ),
        now: now,
      );

      expect(disabled.gpsStatus, SensorDomainStatus.disabled);
      expect(disabled.shouldShowBanner, isTrue);
      expect(disabled.warningMessage, contains('GPS disabled'));
    });

    test('satisfies readiness when onboard GPS is paired with external Bluetooth vario', () {
      final state = SensorReadinessEvaluator.evaluate(
        capabilities: const SensorCapabilities(
          hasBarometer: false,
          hasGps: true,
          locationEnabled: true,
          locationPermissionGranted: true,
          bluetoothAvailable: true,
        ),
        input: LiveSensorInput(
          hasLiveSource: true,
          isExternalVarioSource: true,
          externalVarioState: ExternalVarioConnectionState.connected,
          hasBaroSample: true,
          lastBaroSampleAt: now.subtract(const Duration(milliseconds: 500)),
          hasGpsSample: true,
          lastGpsSampleAt: now.subtract(const Duration(milliseconds: 500)),
          isSampleValid: true,
        ),
        now: now,
      );

      expect(state.barometerStatus, SensorDomainStatus.availableReady);
      expect(state.gpsStatus, SensorDomainStatus.availableReady);
      expect(state.isReady, isTrue);
      expect(state.shouldShowBanner, isFalse);
      expect(state.externalVarioConnected, isTrue);
      expect(state.missingDomains, isEmpty);
    });

    test('satisfies readiness when external Bluetooth vario provides both barometer and GPS', () {
      final state = SensorReadinessEvaluator.evaluate(
        capabilities: const SensorCapabilities(
          hasBarometer: false,
          hasGps: false,
          locationEnabled: false,
          locationPermissionGranted: false,
          bluetoothAvailable: true,
        ),
        input: LiveSensorInput(
          hasLiveSource: true,
          isExternalVarioSource: true,
          externalVarioState: ExternalVarioConnectionState.connected,
          hasBaroSample: true,
          lastBaroSampleAt: now,
          hasGpsSample: true,
          lastGpsSampleAt: now,
          isSampleValid: true,
        ),
        now: now,
      );

      expect(state.isReady, isTrue);
      expect(state.shouldShowBanner, isFalse);
    });

    test('transitions to stale when samples exceed staleness threshold', () {
      final state = SensorReadinessEvaluator.evaluate(
        capabilities: const SensorCapabilities(
          hasBarometer: true,
          hasGps: true,
          locationEnabled: true,
          locationPermissionGranted: true,
        ),
        input: LiveSensorInput(
          hasLiveSource: true,
          hasBaroSample: true,
          lastBaroSampleAt: now.subtract(const Duration(seconds: 6)),
          hasGpsSample: true,
          lastGpsSampleAt: now.subtract(const Duration(seconds: 6)),
          isSampleValid: true,
        ),
        now: now,
      );

      expect(state.barometerStatus, SensorDomainStatus.stale);
      expect(state.gpsStatus, SensorDomainStatus.stale);
      expect(state.shouldShowBanner, isTrue);
    });

    test('transitions to disconnected when external vario disconnects mid-session', () {
      final state = SensorReadinessEvaluator.evaluate(
        capabilities: const SensorCapabilities(
          hasBarometer: false,
          hasGps: true,
          locationEnabled: true,
          locationPermissionGranted: true,
          bluetoothAvailable: true,
        ),
        input: LiveSensorInput(
          hasLiveSource: true,
          isExternalVarioSource: true,
          externalVarioState: ExternalVarioConnectionState.disconnected,
          hasBaroSample: false,
          hasGpsSample: true,
          lastGpsSampleAt: now,
          isSampleValid: true,
        ),
        now: now,
      );

      expect(state.barometerStatus, SensorDomainStatus.disconnected);
      expect(state.gpsStatus, SensorDomainStatus.availableReady);
      expect(state.shouldShowBanner, isTrue);
      expect(state.warningMessage, contains('Bluetooth vario disconnected'));
    });

    test('suppresses banner during mock flight mode and IGC replay mode', () {
      final mockState = SensorReadinessEvaluator.evaluate(
        capabilities: SensorCapabilities.unknown,
        input: const LiveSensorInput(isMockFlightMode: true),
        now: now,
      );
      expect(mockState.isReady, isFalse);
      expect(mockState.shouldShowBanner, isFalse);

      final replayState = SensorReadinessEvaluator.evaluate(
        capabilities: SensorCapabilities.unknown,
        input: const LiveSensorInput(isReplayActive: true),
        now: now,
      );
      expect(replayState.isReady, isFalse);
      expect(replayState.shouldShowBanner, isFalse);
    });

    test('isValidGpsCoordinates rejects zero-zero, NaN, and out-of-range values', () {
      expect(LiveSensorInput.isValidGpsCoordinates(null, 13.0), isFalse);
      expect(LiveSensorInput.isValidGpsCoordinates(0.0, 0.0), isFalse);
      expect(LiveSensorInput.isValidGpsCoordinates(double.nan, 13.0), isFalse);
      expect(LiveSensorInput.isValidGpsCoordinates(91.0, 13.0), isFalse);
      expect(LiveSensorInput.isValidGpsCoordinates(47.2, 181.0), isFalse);
      expect(LiveSensorInput.isValidGpsCoordinates(47.2692, 11.4041), isTrue);
    });
  });
}
