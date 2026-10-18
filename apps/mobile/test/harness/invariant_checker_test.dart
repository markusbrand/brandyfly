import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'invariant_checker.dart';

void main() {
  group('LayoutInvariantChecker', () {
    late LayoutInvariantChecker checker;

    setUp(() {
      checker = LayoutInvariantChecker();
    });

    tearDown(() {
      checker.stopCollecting();
    });

    test('collects RenderFlex overflow without crashing test', () {
      checker.setContext(
        scenarioId: 'thermal_climb',
        canvasName: 'phone_portrait',
        milestone: 'core_peak',
      );
      checker.startCollecting();

      // Simulate a RenderFlex overflow error reported by Flutter
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: FlutterError('A RenderFlex overflowed by 42.0 pixels on the bottom.'),
          library: 'rendering library',
          context: ErrorDescription('during layout'),
        ),
      );

      final violations = checker.stopCollecting();
      expect(violations.length, 1);
      final v = violations.first;
      expect(v.kind, 'render_flex_overflow');
      expect(v.scenarioId, 'thermal_climb');
      expect(v.canvasName, 'phone_portrait');
      expect(v.milestone, 'core_peak');
      expect(v.message, contains('42.0 pixels'));
    });

    test('classifies NaN / Infinity errors properly', () {
      checker.setContext(scenarioId: 'boundary_extremes');
      checker.startCollecting();

      FlutterError.reportError(
        FlutterErrorDetails(
          exception: FlutterError('BoxConstraints has NaN max width.'),
          library: 'rendering library',
        ),
      );

      final violations = checker.stopCollecting();
      expect(violations.length, 1);
      expect(violations.first.kind, 'nan_infinity');
      expect(violations.first.scenarioId, 'boundary_extremes');
    });

    testWidgets('captures overflow when rendering constrained overflowing widget', (tester) async {
      checker.setContext(canvasName: 'small_test_canvas');
      checker.startCollecting();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 50,
              height: 20,
              child: Row(
                children: const [
                  SizedBox(width: 40, child: Text('AAAA')),
                  SizedBox(width: 40, child: Text('BBBB')),
                ],
              ),
            ),
          ),
        ),
      );

      final violations = checker.stopCollecting();
      expect(violations, isNotEmpty);
      expect(violations.any((v) => v.kind == 'render_flex_overflow'), isTrue);
      expect(violations.first.canvasName, 'small_test_canvas');

      // Clear any pending exceptions in tester so test runner does not fail
      tester.takeException();
    });

    test('serializes to JSON format correctly', () {
      final v = InvariantViolation(
        kind: 'render_flex_overflow',
        message: 'A RenderFlex overflowed by 15.0 pixels on the right.',
        scenarioId: 'steady_glide',
        canvasName: 'phone_landscape',
        milestone: 'mid_glide',
        stackTrace: 'trace lines',
      );

      final json = v.toJson();
      expect(json['kind'], 'render_flex_overflow');
      expect(json['message'], contains('15.0 pixels'));
      expect(json['scenario_id'], 'steady_glide');
      expect(json['canvas_name'], 'phone_landscape');
      expect(json['milestone'], 'mid_glide');
      expect(json['stack_trace'], 'trace lines');
    });
  });
}
