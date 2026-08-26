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

  @override
  Future<int?> getMonotonicTimeNanos() => Future.value(1234567890);

  @override
  Future<Map<String, Object?>?> runNativeBenchmark() => Future.value({
        'platform': 'mock',
        'allGatesPassed': true,
      });

  @override
  Future<bool> startSkyDrop1Transport({
    bool developerModeOnly = true,
    String? deviceAddress,
  }) =>
      Future.value(true);

  @override
  Future<void> stopSkyDrop1Transport() async => Future.value();

  @override
  Future<Map<String, Object?>?> runSkyDrop1HardwareBenchmark() => Future.value({
        'platform': 'android',
        'allGatesPassed': true,
        'latencyGatePassed': true,
        'reconnectWithoutRestartPassed': true,
        'androidStatus': 'supported',
        'iosStatus': 'unsupported',
      });
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

  test('getMonotonicTimeNanos returns monotonic timestamp', () async {
    final brandyflyNativePlugin = BrandyflyNative();
    final fakePlatform = MockBrandyflyNativePlatform();
    BrandyflyNativePlatform.instance = fakePlatform;

    final nanos = await brandyflyNativePlugin.getMonotonicTimeNanos();
    expect(nanos, 1234567890);
  });

  test('runNativeBenchmark executes and returns results', () async {
    final brandyflyNativePlugin = BrandyflyNative();
    final fakePlatform = MockBrandyflyNativePlatform();
    BrandyflyNativePlatform.instance = fakePlatform;

    final result = await brandyflyNativePlugin.runNativeBenchmark();
    expect(result?['allGatesPassed'], true);
  });

  test('startSkyDrop1Transport, stop, and runSkyDrop1HardwareBenchmark', () async {
    final brandyflyNativePlugin = BrandyflyNative();
    final fakePlatform = MockBrandyflyNativePlatform();
    BrandyflyNativePlatform.instance = fakePlatform;

    final started = await brandyflyNativePlugin.startSkyDrop1Transport(
      developerModeOnly: true,
      deviceAddress: '00:11:22:33:44:55',
    );
    expect(started, true);

    await expectLater(brandyflyNativePlugin.stopSkyDrop1Transport(), completes);

    final benchMap = await brandyflyNativePlugin.runSkyDrop1HardwareBenchmark();
    expect(benchMap, isNotNull);
    final benchResult = SkyDrop1BenchmarkResult.fromMap(benchMap!);
    expect(benchResult.platform, 'android');
    expect(benchResult.allGatesPassed, true);
    expect(benchResult.latencyGatePassed, true);
    expect(benchResult.reconnectWithoutRestartPassed, true);
    expect(benchResult.androidStatus, 'supported');
    expect(benchResult.iosStatus, 'unsupported');
  });
}
