import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'invariant_checker.dart';
import 'report_generator.dart';

void main() {
  group('ReplayReportGenerator', () {
    const generator = ReplayReportGenerator();
    final tempReportPath = 'build/test_output/test_replay_report.json';

    tearDown(() {
      final f = File(tempReportPath);
      if (f.existsSync()) {
        f.deleteSync();
      }
    });

    test('builds report with passed=true when failures list is empty', () {
      final report = generator.buildReport(
        scenarios: ['steady_glide', 'thermal_climb'],
        canvasTested: ['phone_portrait', 'phone_landscape'],
        failures: [],
        milestones: [
          const MilestoneArtifact(
            scenario: 'thermal_climb',
            canvas: 'phone_portrait',
            milestone: 'peak',
            screenshot: 'build/harness/screenshots/thermal_climb_phone_portrait_peak.png',
          ),
        ],
        executionDurationMs: 450,
      );

      expect(report.passed, isTrue);
      expect(report.scenariosEvaluated, 2);
      expect(report.canvasTested, ['phone_portrait', 'phone_landscape']);
      expect(report.failures, isEmpty);
      expect(report.milestones.length, 1);
      expect(report.milestones.first.milestone, 'peak');
    });

    test('builds report with passed=false when invariant violations are present', () {
      final report = generator.buildReport(
        scenarios: ['boundary_extremes'],
        canvasTested: ['phone_portrait'],
        failures: [
          const InvariantViolation(
            kind: 'render_flex_overflow',
            message: 'A RenderFlex overflowed by 12.0 pixels.',
            scenarioId: 'boundary_extremes',
            canvasName: 'phone_portrait',
            milestone: 'extreme_speed',
          ),
        ],
        milestones: [],
      );

      expect(report.passed, isFalse);
      expect(report.failures.length, 1);
      expect(report.failures.first.kind, 'render_flex_overflow');
    });

    test('writes to disk and reads back matching structured JSON schema', () {
      final original = generator.buildReport(
        scenarios: ['heavy_sink', 'airspace_alert'],
        canvasTested: ['tablet_landscape'],
        failures: [
          const InvariantViolation(
            kind: 'nan_infinity',
            message: 'Infinite bounds encountered.',
            scenarioId: 'heavy_sink',
            canvasName: 'tablet_landscape',
          ),
        ],
        milestones: [
          const MilestoneArtifact(
            scenario: 'airspace_alert',
            canvas: 'tablet_landscape',
            milestone: 'violation',
            screenshot: 'build/harness/screenshots/airspace_alert_tablet_landscape_violation.png',
          ),
        ],
        executionDurationMs: 1200,
      );

      final file = generator.writeReport(original, path: tempReportPath);
      expect(file.existsSync(), isTrue);

      final loaded = generator.readReport(path: tempReportPath);
      expect(loaded, isNotNull);
      expect(loaded!.passed, isFalse);
      expect(loaded.scenariosEvaluated, 2);
      expect(loaded.scenarios, ['heavy_sink', 'airspace_alert']);
      expect(loaded.canvasTested, ['tablet_landscape']);
      expect(loaded.failures.length, 1);
      expect(loaded.failures.first.kind, 'nan_infinity');
      expect(loaded.failures.first.message, 'Infinite bounds encountered.');
      expect(loaded.milestones.length, 1);
      expect(loaded.milestones.first.scenario, 'airspace_alert');
      expect(loaded.milestones.first.screenshot, contains('violation.png'));
      expect(loaded.executionDurationMs, 1200);
    });
  });
}
