import 'package:brandyfly/main.dart';
import 'package:brandyfly_native/brandyfly_native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeBrandyflyNative extends BrandyflyNative {
  @override
  Future<String?> getPlatformVersion() async => 'TestOS 1.0';

  @override
  Future<void> configureLocalMockFlightMode(
    MockFlightModeConfig config,
  ) async {}
}

class FakeBrandyflyNativeError extends BrandyflyNative {
  @override
  Future<String?> getPlatformVersion() async => throw PlatformException(
        code: 'TEST_ERROR',
        message: 'Simulated platform bootstrap error',
      );

  @override
  Future<void> configureLocalMockFlightMode(
    MockFlightModeConfig config,
  ) async {}
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  testWidgets('renders the live application shell', (tester) async {
    await tester.pumpWidget(
      BrandyFlyApp(
        config: MockFlightModeConfig(
          enabled: false,
          fixtureVersion: 'mock-flight-v1',
          seed: 7,
          logicalClockStep: const Duration(seconds: 1),
          startTime: DateTime.parse('2026-08-07T00:00:00Z'),
          provenance: 'synthetic-anonymized',
        ),
        native: FakeBrandyflyNative(),
      ),
    );

    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('BrandyFly'), findsOneWidget);
    expect(find.textContaining('Running on:'), findsOneWidget);
    expect(find.text('LIVE'), findsOneWidget);
  });

  testWidgets('renders startup error view on platform exception', (tester) async {
    await tester.pumpWidget(
      BrandyFlyApp(
        config: MockFlightModeConfig(
          enabled: false,
          fixtureVersion: 'mock-flight-v1',
          seed: 7,
          logicalClockStep: const Duration(seconds: 1),
          startTime: DateTime.parse('2026-08-07T00:00:00Z'),
          provenance: 'synthetic-anonymized',
        ),
        native: FakeBrandyflyNativeError(),
      ),
    );

    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('Simulated platform bootstrap error'), findsOneWidget);
  });

  testWidgets('renders the simulated flight dashboard', (tester) async {
    await tester.pumpWidget(
      BrandyFlyApp(
        config: MockFlightModeConfig(
          enabled: true,
          fixtureVersion: 'mock-flight-v1',
          seed: 7,
          logicalClockStep: const Duration(seconds: 1),
          startTime: DateTime.parse('2026-08-07T00:00:00Z'),
          provenance: 'synthetic-anonymized',
        ),
        native: FakeBrandyflyNative(),
      ),
    );

    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('SIMULATED'), findsOneWidget);
    expect(find.textContaining('Mock flight session'), findsOneWidget);
    expect(find.textContaining('Nominal glide'), findsOneWidget);
    expect(find.textContaining('Replay hash:'), findsOneWidget);
  });

  test('rejects mock mode in release builds', () {
    expect(
      () => MockFlightModeConfig(
        enabled: true,
        fixtureVersion: 'mock-flight-v1',
        seed: 7,
        logicalClockStep: const Duration(seconds: 1),
        startTime: DateTime.parse('2026-08-07T00:00:00Z'),
        provenance: 'synthetic-anonymized',
      ).validateBuildMode(isReleaseBuild: true),
      throwsStateError,
    );
  });

  test('rejects mock mode without provenance metadata', () {
    expect(
      () => MockFlightModeConfig(
        enabled: true,
        fixtureVersion: 'mock-flight-v1',
        seed: 7,
        logicalClockStep: const Duration(seconds: 1),
        startTime: DateTime.parse('2026-08-07T00:00:00Z'),
        provenance: '',
      ).validateBuildMode(isReleaseBuild: false),
      throwsStateError,
    );
  });
}
