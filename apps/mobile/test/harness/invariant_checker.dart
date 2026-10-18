import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Represents a detected layout or rendering invariant violation.
class InvariantViolation {
  const InvariantViolation({
    required this.kind,
    required this.message,
    this.scenarioId,
    this.canvasName,
    this.milestone,
    this.stackTrace,
  });

  /// Category of the violation:
  /// - `render_flex_overflow`: RenderFlex overflow by N pixels
  /// - `nan_infinity`: NaN or Infinity encountered in dimensions/constraints
  /// - `negative_dimension`: Box size with negative width or height
  /// - `layout_exception`: General rendering or layout crash
  final String kind;

  /// Human-readable violation description.
  final String message;

  /// ID of the scenario during which this occurred.
  final String? scenarioId;

  /// Name of the canvas being evaluated (e.g. 'phone_portrait').
  final String? canvasName;

  /// Milestone keyframe active when the violation occurred.
  final String? milestone;

  /// Optional stack trace string.
  final String? stackTrace;

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'message': message,
        if (scenarioId != null) 'scenario_id': scenarioId,
        if (canvasName != null) 'canvas_name': canvasName,
        if (milestone != null) 'milestone': milestone,
        if (stackTrace != null) 'stack_trace': stackTrace,
      };

  @override
  String toString() {
    final ctx = [
      if (scenarioId != null) 'scenario: $scenarioId',
      if (canvasName != null) 'canvas: $canvasName',
      if (milestone != null) 'milestone: $milestone',
    ].join(', ');
    return 'InvariantViolation[$kind]${ctx.isNotEmpty ? ' ($ctx)' : ''}: $message';
  }
}

/// Evaluates and intercepts layout invariants, collecting overflows and anomalies.
class LayoutInvariantChecker {
  LayoutInvariantChecker();

  final List<InvariantViolation> _violations = [];
  FlutterExceptionHandler? _previousOnError;
  bool _isCollecting = false;

  String? _currentScenarioId;
  String? _currentCanvasName;
  String? _currentMilestone;

  List<InvariantViolation> get violations => List.unmodifiable(_violations);
  bool get hasViolations => _violations.isNotEmpty;
  bool get isCollecting => _isCollecting;

  /// Set contextual tags for subsequently captured violations.
  void setContext({
    String? scenarioId,
    String? canvasName,
    String? milestone,
  }) {
    _currentScenarioId = scenarioId;
    _currentCanvasName = canvasName;
    _currentMilestone = milestone;
  }

  /// Begin intercepting [FlutterError.onError] calls.
  void startCollecting() {
    if (_isCollecting) return;
    _isCollecting = true;
    _previousOnError = FlutterError.onError;

    FlutterError.onError = (FlutterErrorDetails details) {
      _handleFlutterError(details);
    };
  }

  /// Stop intercepting and restore the previous error handler.
  List<InvariantViolation> stopCollecting() {
    if (!_isCollecting) return violations;
    _isCollecting = false;
    if (_previousOnError != null) {
      FlutterError.onError = _previousOnError;
      _previousOnError = null;
    }
    return violations;
  }

  void _handleFlutterError(FlutterErrorDetails details) {
    final message = details.exceptionAsString();
    final stack = details.stack?.toString();

    final String kind;
    if (message.contains('overflowed by') || message.contains('RenderFlex')) {
      kind = 'render_flex_overflow';
    } else if (message.contains('NaN') ||
        message.contains('Infinity') ||
        message.contains('isFinite')) {
      kind = 'nan_infinity';
    } else {
      kind = 'layout_exception';
    }

    _violations.add(
      InvariantViolation(
        kind: kind,
        message: message,
        scenarioId: _currentScenarioId,
        canvasName: _currentCanvasName,
        milestone: _currentMilestone,
        stackTrace: stack,
      ),
    );
  }

  /// Manually record an invariant violation.
  void recordViolation(InvariantViolation violation) {
    _violations.add(violation);
  }

  /// Recursively inspects a [RenderObject] subtree for invalid dimensions.
  void inspectRenderTree(RenderObject root) {
    void visit(RenderObject object) {
      if (object is RenderBox && object.hasSize) {
        final size = object.size;
        if (size.width.isNaN || size.height.isNaN) {
          recordViolation(
            InvariantViolation(
              kind: 'nan_infinity',
              message: 'RenderBox has NaN dimensions: $size',
              scenarioId: _currentScenarioId,
              canvasName: _currentCanvasName,
              milestone: _currentMilestone,
            ),
          );
        } else if (size.width.isInfinite || size.height.isInfinite) {
          recordViolation(
            InvariantViolation(
              kind: 'nan_infinity',
              message: 'RenderBox has infinite dimensions: $size',
              scenarioId: _currentScenarioId,
              canvasName: _currentCanvasName,
              milestone: _currentMilestone,
            ),
          );
        } else if (size.width < 0 || size.height < 0) {
          recordViolation(
            InvariantViolation(
              kind: 'negative_dimension',
              message: 'RenderBox has negative dimensions: $size',
              scenarioId: _currentScenarioId,
              canvasName: _currentCanvasName,
              milestone: _currentMilestone,
            ),
          );
        }
      }
      object.visitChildren(visit);
    }

    visit(root);
  }

  /// Clear all collected violations.
  void clear() {
    _violations.clear();
  }
}
