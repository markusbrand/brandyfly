import 'package:brandyfly/main.dart';
import 'package:brandyfly_native/brandyfly_native.dart';
import 'package:flutter/material.dart';
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

  testWidgets('renders the simulated flight dashboard and toggles minimize/expand', (tester) async {
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

    // Minimize mock flight session section
    final minimizeButton = find.byKey(const Key('btn_minimize_mock_session'));
    expect(minimizeButton, findsOneWidget);
    await tester.tap(minimizeButton);
    await tester.pumpAndSettle();

    // The detailed replay hash should now be hidden in minimized state
    expect(find.textContaining('Replay hash:'), findsNothing);
    expect(find.byKey(const Key('btn_expand_mock_session')), findsOneWidget);

    // Expand mock flight session section
    final expandButton = find.byKey(const Key('btn_expand_mock_session'));
    await tester.tap(expandButton);
    await tester.pumpAndSettle();

    // Expanded details are visible again
    expect(find.textContaining('Replay hash:'), findsOneWidget);
    expect(find.byKey(const Key('btn_minimize_mock_session')), findsOneWidget);
  });

  testWidgets('simulation overlay supports drag-and-drop, boundary clamping, and retains position across ticks', (tester) async {
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

    final overlayFinder = find.byKey(const Key('simulation_overlay_card'));
    expect(overlayFinder, findsOneWidget);

    final initialRect = tester.getRect(overlayFinder);

    // Drag overlay down and to the left
    await tester.timedDrag(
      overlayFinder,
      const Offset(-120, 80),
      const Duration(milliseconds: 300),
    );
    await tester.pumpAndSettle();

    final draggedRect = tester.getRect(overlayFinder);
    expect(draggedRect.left, lessThan(initialRect.left));
    expect(draggedRect.top, greaterThan(initialRect.top));

    // Advancing scenario tick preserves position
    final preTickRect = tester.getRect(overlayFinder);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    final postTickRect = tester.getRect(overlayFinder);
    expect(postTickRect.topLeft, equals(preTickRect.topLeft));

    // Tap button does not displace position
    final advanceButton = find.byTooltip('Advance scenario');
    expect(advanceButton, findsOneWidget);
    await tester.tap(advanceButton);
    await tester.pumpAndSettle();
    final postTapRect = tester.getRect(overlayFinder);
    expect(postTapRect.topLeft, equals(preTickRect.topLeft));

    // Drag far outside the viewport to verify boundary clamping (top-left)
    await tester.timedDrag(
      overlayFinder,
      const Offset(-2000, -2000),
      const Duration(milliseconds: 300),
    );
    await tester.pumpAndSettle();
    final clampedTopLeft = tester.getRect(overlayFinder);
    expect(clampedTopLeft.left, greaterThanOrEqualTo(0));
    expect(clampedTopLeft.top, greaterThanOrEqualTo(0));

    // Drag far to bottom right
    await tester.timedDrag(
      overlayFinder,
      const Offset(3000, 3000),
      const Duration(milliseconds: 300),
    );
    await tester.pumpAndSettle();
    final clampedBottomRight = tester.getRect(overlayFinder);
    expect(clampedBottomRight.right, lessThanOrEqualTo(800));
    expect(clampedBottomRight.bottom, lessThanOrEqualTo(600));

    // Toggle minimize and expand at boundary
    final minimizeButton = find.byKey(const Key('btn_minimize_mock_session'));
    await tester.tap(minimizeButton);
    await tester.pumpAndSettle();
    final minimizedRect = tester.getRect(overlayFinder);
    expect(minimizedRect.right, lessThanOrEqualTo(800));
    expect(minimizedRect.bottom, lessThanOrEqualTo(600));

    final expandButton = find.byKey(const Key('btn_expand_mock_session'));
    await tester.tap(expandButton);
    await tester.pumpAndSettle();
    final expandedRect = tester.getRect(overlayFinder);
    expect(expandedRect.right, lessThanOrEqualTo(800));
    expect(expandedRect.bottom, lessThanOrEqualTo(600));
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
