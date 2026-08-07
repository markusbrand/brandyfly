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

  @override
  Future<void> configureLocalMockFlightMode(MockFlightModeConfig config) async {
    return;
  }
}

void main() {
  final BrandyflyNativePlatform initialPlatform =
      BrandyflyNativePlatform.instance;

  tearDown(() {
    BrandyflyNativePlatform.instance = initialPlatform;
  });

  test('$MethodChannelBrandyflyNative is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelBrandyflyNative>());
  });

  test('getPlatformVersion', () async {
    BrandyflyNative brandyflyNativePlugin = BrandyflyNative();
    MockBrandyflyNativePlatform fakePlatform = MockBrandyflyNativePlatform();
    BrandyflyNativePlatform.instance = fakePlatform;

    expect(await brandyflyNativePlugin.getPlatformVersion(), '42');
  });

  test('configureLocalMockFlightMode forwards config to the platform', () async {
    final config = MockFlightModeConfig(
      enabled: true,
      fixtureVersion: 'mock-flight-v1',
      seed: 7,
      logicalClockStep: const Duration(milliseconds: 500),
      startTime: DateTime.parse('2026-08-07T00:00:00Z'),
      provenance: 'synthetic-anonymized',
      sessionLabel: 'simulated',
    );
    final brandyflyNativePlugin = BrandyflyNative();
    final fakePlatform = MockBrandyflyNativePlatform();
    BrandyflyNativePlatform.instance = fakePlatform;

    await expectLater(
      brandyflyNativePlugin.configureLocalMockFlightMode(config),
      completes,
    );
  });
}
