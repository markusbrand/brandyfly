import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'brandyfly_native_platform_interface.dart';

/// An implementation of [BrandyflyNativePlatform] that uses method channels.
class MethodChannelBrandyflyNative extends BrandyflyNativePlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('brandyfly_native');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
