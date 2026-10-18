import 'dart:convert';
import 'dart:io';

import 'invariant_checker.dart';

/// Represents a milestone artifact recorded during scenario execution.
class MilestoneArtifact {
  const MilestoneArtifact({
    required this.scenario,
    required this.canvas,
    required this.milestone,
    this.screenshot,
  });

  final String scenario;
  final String canvas;
  final String milestone;
  final String? screenshot;

  Map<String, dynamic> toJson() => {
        'scenario': scenario,
        'canvas': canvas,
        'milestone': milestone,
        if (screenshot != null) 'screenshot': screenshot,
      };

  factory MilestoneArtifact.fromJson(Map<String, dynamic> json) {
    return MilestoneArtifact(
      scenario: json['scenario'] as String,
      canvas: json['canvas'] as String,
      milestone: json['milestone'] as String,
      screenshot: json['screenshot'] as String?,
    );
  }
}

/// Structured test report containing replay execution evidence.
class ReplayReport {
  const ReplayReport({
    required this.timestamp,
    required this.passed,
    required this.scenariosEvaluated,
    required this.scenarios,
    required this.canvasTested,
    required this.failures,
    required this.milestones,
    this.executionDurationMs = 0,
  });

  final DateTime timestamp;
  final bool passed;
  final int scenariosEvaluated;
  final List<String> scenarios;
  final List<String> canvasTested;
  final List<InvariantViolation> failures;
  final List<MilestoneArtifact> milestones;
  final int executionDurationMs;

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toUtc().toIso8601String(),
        'passed': passed,
        'scenarios_evaluated': scenariosEvaluated,
        'scenarios': scenarios,
        'canvas_tested': canvasTested,
        'failures': failures.map((f) => f.toJson()).toList(),
        'milestones': milestones.map((m) => m.toJson()).toList(),
        'execution_duration_ms': executionDurationMs,
      };

  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert(toJson());

  factory ReplayReport.fromJson(Map<String, dynamic> json) {
    final rawFailures = json['failures'] as List<dynamic>? ?? [];
    final failures = rawFailures.map((f) {
      final m = f as Map<String, dynamic>;
      return InvariantViolation(
        kind: m['kind'] as String? ?? 'unknown',
        message: m['message'] as String? ?? '',
        scenarioId: m['scenario_id'] as String?,
        canvasName: m['canvas_name'] as String?,
        milestone: m['milestone'] as String?,
        stackTrace: m['stack_trace'] as String?,
      );
    }).toList();

    final rawMilestones = json['milestones'] as List<dynamic>? ?? [];
    final milestones = rawMilestones
        .map((m) => MilestoneArtifact.fromJson(m as Map<String, dynamic>))
        .toList();

    return ReplayReport(
      timestamp: DateTime.parse(json['timestamp'] as String),
      passed: json['passed'] as bool? ?? (failures.isEmpty),
      scenariosEvaluated: json['scenarios_evaluated'] as int? ?? 0,
      scenarios: (json['scenarios'] as List<dynamic>?)?.cast<String>() ?? [],
      canvasTested: (json['canvas_tested'] as List<dynamic>?)?.cast<String>() ?? [],
      failures: failures,
      milestones: milestones,
      executionDurationMs: json['execution_duration_ms'] as int? ?? 0,
    );
  }
}

/// Generates and persists replay execution reports.
class ReplayReportGenerator {
  const ReplayReportGenerator();

  static const String defaultReportPath = 'build/harness/replay_report.json';

  /// Construct a [ReplayReport] from collected execution data.
  ReplayReport buildReport({
    required List<String> scenarios,
    required List<String> canvasTested,
    required List<InvariantViolation> failures,
    required List<MilestoneArtifact> milestones,
    DateTime? timestamp,
    int executionDurationMs = 0,
  }) {
    final reportTimestamp = timestamp ?? DateTime.now().toUtc();
    return ReplayReport(
      timestamp: reportTimestamp,
      passed: failures.isEmpty,
      scenariosEvaluated: scenarios.length,
      scenarios: scenarios,
      canvasTested: canvasTested,
      failures: failures,
      milestones: milestones,
      executionDurationMs: executionDurationMs,
    );
  }

  /// Write [report] to disk at [path] (defaults to `build/harness/replay_report.json`).
  File writeReport(ReplayReport report, {String path = defaultReportPath}) {
    final file = File(path);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(report.toPrettyJson());
    return file;
  }

  /// Read and parse an existing report from [path].
  ReplayReport? readReport({String path = defaultReportPath}) {
    final file = File(path);
    if (!file.existsSync()) return null;
    final content = file.readAsStringSync();
    final json = jsonDecode(content) as Map<String, dynamic>;
    return ReplayReport.fromJson(json);
  }
}
