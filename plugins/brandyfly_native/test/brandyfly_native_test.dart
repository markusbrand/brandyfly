import 'package:flutter_test/flutter_test.dart';
import 'package:brandyfly_native/brandyfly_native.dart';
import 'package:brandyfly_native/brandyfly_native_platform_interface.dart';
import 'package:brandyfly_native/brandyfly_native_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockBrandyflyNativePlatform
    with MockPlatformInterfaceMixin
    implements BrandyflyNativePlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final BrandyflyNativePlatform initialPlatform =
      BrandyflyNativePlatform.instance;

  test('$MethodChannelBrandyflyNative is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelBrandyflyNative>());
  });

  test('getPlatformVersion', () async {
    BrandyflyNative brandyflyNativePlugin = BrandyflyNative();
    MockBrandyflyNativePlatform fakePlatform = MockBrandyflyNativePlatform();
    BrandyflyNativePlatform.instance = fakePlatform;

    expect(await brandyflyNativePlugin.getPlatformVersion(), '42');
  });
}
