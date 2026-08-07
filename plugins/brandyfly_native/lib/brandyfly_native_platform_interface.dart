import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'brandyfly_native_method_channel.dart';
import 'mock_flight_mode.dart';

abstract class BrandyflyNativePlatform extends PlatformInterface {
  /// Constructs a BrandyflyNativePlatform.
  BrandyflyNativePlatform() : super(token: _token);

  static final Object _token = Object();

  static BrandyflyNativePlatform _instance = MethodChannelBrandyflyNative();

  /// The default instance of [BrandyflyNativePlatform] to use.
  ///
  /// Defaults to [MethodChannelBrandyflyNative].
  static BrandyflyNativePlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [BrandyflyNativePlatform] when
  /// they register themselves.
  static set instance(BrandyflyNativePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<void> configureLocalMockFlightMode(MockFlightModeConfig config) {
    throw UnimplementedError(
      'configureLocalMockFlightMode() has not been implemented.',
    );
  }
}
