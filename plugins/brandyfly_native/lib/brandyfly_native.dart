import 'brandyfly_native_platform_interface.dart';

class BrandyflyNative {
  Future<String?> getPlatformVersion() {
    return BrandyflyNativePlatform.instance.getPlatformVersion();
  }
}
