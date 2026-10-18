import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'autonomous_replay_harness.dart';
import 'invariant_checker.dart';
import 'report_generator.dart';
import 'scenario_catalog.dart';

void main() {
  setUpAll(() async {
    // Attempt font loading
    await AutonomousReplayHarness.loadFonts();
  });

  group('AutonomousReplayHarness', () {
    testWidgets('executes full scenario suite across canvas matrix and passes layout invariants', (
      tester,
    ) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final harness = AutonomousReplayHarness();
      const testReportPath = 'build/harness/test_replay_report.json';

      final report = await harness.runSuite(
        tester: tester,
        scenarios: ScenarioCatalog.all,
        config: const HarnessConfig(
          reportPath: testReportPath,
          captureScreenshots: false,
        ),
      );

      expect(report.passed, isTrue);
      expect(report.scenariosEvaluated, equals(6));
      expect(
        report.canvasTested,
        containsAll(['phone_portrait', 'phone_landscape', 'tablet_landscape']),
      );
      expect(report.failures, isEmpty);
      expect(report.milestones, isNotEmpty);

      // Verify report was written to disk
      final file = File(testReportPath);
      expect(file.existsSync(), isTrue);

      final readReport = const ReplayReportGenerator().readReport(path: testReportPath);
      expect(readReport, isNotNull);
      expect(readReport!.passed, isTrue);
      expect(readReport.scenariosEvaluated, equals(6));
    });

    testWidgets('captures milestone keyframe PNGs when screenshots enabled', (
      tester,
    ) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final harness = AutonomousReplayHarness();
      const testScreenshotsDir = 'build/harness/test_screenshots';
      const testReportPath = 'build/harness/screenshot_test_report.json';

      final report = await harness.runSuite(
        tester: tester,
        scenarios: [ScenarioCatalog.thermalClimb],
        config: const HarnessConfig(
          canvases: {'phone_portrait': Size(390, 844)},
          captureScreenshots: true,
          screenshotsDir: testScreenshotsDir,
          reportPath: testReportPath,
        ),
      );

      expect(report.passed, isTrue);
      expect(report.milestones, isNotEmpty);

      // Verify screenshot files were created
      for (final milestone in report.milestones) {
        expect(milestone.screenshot, isNotNull);
        final imageFile = File(milestone.screenshot!);
        expect(imageFile.existsSync(), isTrue, reason: 'File ${milestone.screenshot} should exist');
        expect(imageFile.lengthSync(), greaterThan(0));
      }
    });

    testWidgets('captures layout invariant violation without aborting execution', (
      tester,
    ) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final harness = AutonomousReplayHarness();
      const testReportPath = 'build/harness/failing_test_report.json';

      // Manually record an invariant failure during the run to verify reporting
      harness.invariantChecker.recordViolation(
        const InvariantViolation(
          kind: 'render_flex_overflow',
          message: 'A RenderFlex overflowed by 24.5 pixels on the right.',
          scenarioId: 'boundary_extremes',
          canvasName: 'phone_portrait',
          milestone: 'peak',
        ),
      );

      final report = await harness.runSuite(
        tester: tester,
        scenarios: [ScenarioCatalog.boundaryExtremes],
        config: const HarnessConfig(
          canvases: {'phone_portrait': Size(390, 844)},
          captureScreenshots: false,
          reportPath: testReportPath,
        ),
      );

      expect(report.passed, isFalse);
      expect(report.failures.length, equals(1));
      expect(report.failures.first.kind, equals('render_flex_overflow'));
      expect(report.failures.first.canvasName, equals('phone_portrait'));
    });
  });
}
