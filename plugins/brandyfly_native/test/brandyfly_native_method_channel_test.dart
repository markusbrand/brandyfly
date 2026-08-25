import 'package:brandyfly_native/brandyfly_native.dart';
import 'package:brandyfly_native/brandyfly_native_method_channel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final MethodChannelBrandyflyNative platform = MethodChannelBrandyflyNative();
  const MethodChannel channel = MethodChannel('brandyfly_native');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          if (methodCall.method == 'getPlatformVersion') {
            return '42';
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });

  test('configureLocalMockFlightMode', () async {
    final config = MockFlightModeConfig(
      enabled: true,
      fixtureVersion: 'mock-flight-v1',
      seed: 42,
      logicalClockStep: const Duration(milliseconds: 1000),
      startTime: DateTime.parse('2026-08-07T00:00:00Z'),
      provenance: 'synthetic-anonymized',
      sessionLabel: 'simulated',
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          expect(methodCall.method, 'configureLocalMockFlightMode');
          final arguments = methodCall.arguments as Map<dynamic, dynamic>;
          expect(arguments['enabled'], true);
          expect(arguments['fixtureVersion'], 'mock-flight-v1');
          expect(arguments['seed'], 42);
          expect(arguments['logicalClockStepMs'], 1000);
          expect(arguments['provenance'], 'synthetic-anonymized');
          expect(arguments['sessionLabel'], 'simulated');
          return null;
        });

    await platform.configureLocalMockFlightMode(config);
  });

  test('startSkyDrop1Transport', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          expect(methodCall.method, 'startSkyDrop1Transport');
          final arguments = methodCall.arguments as Map<dynamic, dynamic>;
          expect(arguments['developerModeOnly'], true);
          expect(arguments['deviceAddress'], '00:11:22:33:44:55');
          return true;
        });

    final started = await platform.startSkyDrop1Transport(
      developerModeOnly: true,
      deviceAddress: '00:11:22:33:44:55',
    );
    expect(started, true);
  });

  test('stopSkyDrop1Transport', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          expect(methodCall.method, 'stopSkyDrop1Transport');
          return null;
        });

    await platform.stopSkyDrop1Transport();
  });

  test('runSkyDrop1HardwareBenchmark', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          expect(methodCall.method, 'runSkyDrop1HardwareBenchmark');
          return {
            'platform': 'android',
            'allGatesPassed': true,
          };
        });

    final res = await platform.runSkyDrop1HardwareBenchmark();
    expect(res?['platform'], 'android');
    expect(res?['allGatesPassed'], true);
  });
}
