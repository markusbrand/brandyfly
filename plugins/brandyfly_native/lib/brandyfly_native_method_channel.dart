import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'brandyfly_native_platform_interface.dart';
import 'mock_flight_mode.dart';

/// An implementation of [BrandyflyNativePlatform] that uses method channels.
class MethodChannelBrandyflyNative extends BrandyflyNativePlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('brandyfly_native');

  @override
  Future<String?> getPlatformVersion() async {
    try {
      final version = await methodChannel.invokeMethod<String>(
        'getPlatformVersion',
      );
      return version;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<void> configureLocalMockFlightMode(MockFlightModeConfig config) async {
    try {
      await methodChannel.invokeMethod<void>(
        'configureLocalMockFlightMode',
        config.toMap(),
      );
    } on MissingPluginException {
      // Fallback on platforms where native method channel is unhandled
    }
  }
}
