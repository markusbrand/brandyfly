import 'brandyfly_native_platform_interface.dart';
import 'mock_flight_mode.dart';

export 'mock_flight_mode.dart';

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
}
