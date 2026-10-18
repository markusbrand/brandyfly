import 'package:brandyfly/domain/models/cockpit_telemetry.dart';
import 'package:flutter/foundation.dart';

import 'scenario_catalog.dart';

/// Driver that controls time-stepped replay playback of scenarios for tests.
class HarnessTelemetryDriver {
  HarnessTelemetryDriver({ValueNotifier<CockpitTelemetry>? telemetryNotifier})
      : telemetryNotifier =
            telemetryNotifier ?? ValueNotifier<CockpitTelemetry>(const CockpitTelemetry());

  final ValueNotifier<CockpitTelemetry> telemetryNotifier;

  ReplayScenario? _currentScenario;
  Duration _elapsed = Duration.zero;
  final List<ReplayMilestone> _reachedMilestones = [];
  final List<void Function(ReplayMilestone milestone, CockpitTelemetry telemetry)>
      _milestoneListeners = [];

  ReplayScenario? get currentScenario => _currentScenario;
  Duration get currentElapsed => _elapsed;
  List<ReplayMilestone> get reachedMilestones => List.unmodifiable(_reachedMilestones);
  CockpitTelemetry get currentTelemetry => telemetryNotifier.value;
  bool get isFinished =>
      _currentScenario != null && _elapsed >= _currentScenario!.duration;

  /// Register a callback invoked whenever a milestone is encountered.
  void addMilestoneListener(
      void Function(ReplayMilestone milestone, CockpitTelemetry telemetry) listener) {
    _milestoneListeners.add(listener);
  }

  /// Remove a registered milestone callback.
  void removeMilestoneListener(
      void Function(ReplayMilestone milestone, CockpitTelemetry telemetry) listener) {
    _milestoneListeners.remove(listener);
  }

  /// Load a scenario and set telemetry to its initial snapshot at [Duration.zero].
  void loadScenario(ReplayScenario scenario) {
    _currentScenario = scenario;
    _elapsed = Duration.zero;
    _reachedMilestones.clear();

    final initial = scenario.telemetryAt(Duration.zero);
    telemetryNotifier.value = initial;

    // Check if any milestone occurs at Duration.zero
    for (final milestone in scenario.milestones) {
      if (milestone.elapsed == Duration.zero) {
        _reachedMilestones.add(milestone);
        for (final listener in _milestoneListeners) {
          listener(milestone, initial);
        }
      }
    }
  }

  /// Advance playback by [stepSize].
  ///
  /// Returns `true` if playback can advance further, or `false` if the end of
  /// the scenario has been reached.
  bool stepForward({Duration stepSize = const Duration(seconds: 1)}) {
    final scenario = _currentScenario;
    if (scenario == null) {
      throw StateError('Cannot step: no scenario loaded');
    }
    if (_elapsed >= scenario.duration) {
      return false;
    }

    final prevElapsed = _elapsed;
    var nextElapsed = _elapsed + stepSize;
    if (nextElapsed > scenario.duration) {
      nextElapsed = scenario.duration;
    }

    _elapsed = nextElapsed;
    final telemetry = scenario.telemetryAt(_elapsed);
    telemetryNotifier.value = telemetry;

    // Detect milestones between prevElapsed (exclusive) and nextElapsed (inclusive)
    for (final milestone in scenario.milestones) {
      if (milestone.elapsed > prevElapsed && milestone.elapsed <= nextElapsed) {
        if (!_reachedMilestones.contains(milestone)) {
          _reachedMilestones.add(milestone);
          for (final listener in _milestoneListeners) {
            listener(milestone, telemetry);
          }
        }
      }
    }

    return _elapsed < scenario.duration;
  }

  /// Seek directly to a target elapsed time.
  void jumpTo(Duration target) {
    final scenario = _currentScenario;
    if (scenario == null) {
      throw StateError('Cannot jump: no scenario loaded');
    }

    final clamped = target < Duration.zero
        ? Duration.zero
        : target > scenario.duration
            ? scenario.duration
            : target;

    final prevElapsed = _elapsed;
    _elapsed = clamped;
    final telemetry = scenario.telemetryAt(_elapsed);
    telemetryNotifier.value = telemetry;

    if (clamped >= prevElapsed) {
      for (final milestone in scenario.milestones) {
        if (milestone.elapsed > prevElapsed && milestone.elapsed <= clamped) {
          if (!_reachedMilestones.contains(milestone)) {
            _reachedMilestones.add(milestone);
            for (final listener in _milestoneListeners) {
              listener(milestone, telemetry);
            }
          }
        }
      }
    }
  }

  /// Reset current playback state.
  void reset() {
    _currentScenario = null;
    _elapsed = Duration.zero;
    _reachedMilestones.clear();
    telemetryNotifier.value = const CockpitTelemetry();
  }

  /// Release resources.
  void dispose() {
    _milestoneListeners.clear();
    telemetryNotifier.dispose();
  }
}
