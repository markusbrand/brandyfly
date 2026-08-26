import 'brandyfly_native_platform_interface.dart';
import 'mock_flight_mode.dart';

export 'mock_flight_mode.dart';
export 'skydrop1_models.dart';

class BrandyflyNative {
  const BrandyflyNative();

  Future<String?> getPlatformVersion() {
    return BrandyflyNativePlatform.instance.getPlatformVersion();
  }

  Future<void> configureLocalMockFlightMode(
    MockFlightModeConfig config,
  ) {
    return BrandyflyNativePlatform.instance.configureLocalMockFlightMode(
      config,
    );
  }

  Future<int?> getMonotonicTimeNanos() {
    return BrandyflyNativePlatform.instance.getMonotonicTimeNanos();
  }

  Future<Map<String, Object?>?> runNativeBenchmark() {
    return BrandyflyNativePlatform.instance.runNativeBenchmark();
  }

  Future<bool> startSkyDrop1Transport({
    bool developerModeOnly = true,
    String? deviceAddress,
  }) {
    return BrandyflyNativePlatform.instance.startSkyDrop1Transport(
      developerModeOnly: developerModeOnly,
      deviceAddress: deviceAddress,
    );
  }

  Future<void> stopSkyDrop1Transport() {
    return BrandyflyNativePlatform.instance.stopSkyDrop1Transport();
  }

  Future<Map<String, Object?>?> runSkyDrop1HardwareBenchmark() {
    return BrandyflyNativePlatform.instance.runSkyDrop1HardwareBenchmark();
  }
}
