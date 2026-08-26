import 'package:brandyfly/main.dart';
import 'package:brandyfly_native/brandyfly_native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeMissingPluginNative extends BrandyflyNative {
  @override
  Future<String?> getPlatformVersion() async => throw MissingPluginException(
        'No implementation found for method getPlatformVersion on channel brandyfly_native',
      );

  @override
  Future<void> configureLocalMockFlightMode(
    MockFlightModeConfig config,
  ) async => throw MissingPluginException(
        'No implementation found for method configureLocalMockFlightMode on channel brandyfly_native',
      );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Web and Platform Fallback Integration Tests', () {
    testWidgets('App boots gracefully and falls back to platform defaults when native plugins are absent', (tester) async {
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
          native: FakeMissingPluginNative(),
        ),
      );

      // Settle loading and bootstrap
      await tester.pump();
      await tester.pump();
      await tester.pump();

      // Ensure no unhandled exception crash and dashboard renders
      expect(find.text('BrandyFly'), findsOneWidget);
      expect(find.textContaining('Running on: Platform Fallback'), findsOneWidget);
      expect(find.text('LIVE'), findsOneWidget);
    });

    testWidgets('App auto-activates synthetic telemetry mode under simulated / fallback environment', (tester) async {
      await tester.pumpWidget(
        BrandyFlyApp(
          config: MockFlightModeConfig(
            enabled: true,
            fixtureVersion: 'mock-flight-v1',
            seed: 42,
            logicalClockStep: const Duration(seconds: 1),
            startTime: DateTime.parse('2026-08-07T00:00:00Z'),
            provenance: 'synthetic-anonymized',
          ),
          native: FakeMissingPluginNative(),
        ),
      );

      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.text('BrandyFly'), findsOneWidget);
      expect(find.text('SIMULATED'), findsOneWidget);
      expect(find.textContaining('Mock flight session'), findsOneWidget);
    });
  });
}
