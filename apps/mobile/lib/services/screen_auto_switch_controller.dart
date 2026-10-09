import 'package:flutter/foundation.dart';

import '../domain/models/cockpit_telemetry.dart';
import '../domain/models/ui_config.dart';
import '../domain/thermal_assistant/thermal_assistant_engine.dart';
import 'screen_manager_service.dart';

/// Switches flight screens automatically on thermal assistant flight-mode
/// transitions, for screens configured with [ScreenAutoSwitchTrigger]s.
///
/// - Entering circling activates the first `onThermalCircling` screen and
///   remembers the previously active screen.
/// - Leaving circling after such an automatic switch activates the first
///   `onGlideStraight` screen, otherwise the remembered screen.
/// - A manual screen change suppresses auto-switching for [manualOverride].
/// - At most one automatic switch per [minSwitchInterval]; never while the
///   layout editor is active.
class ScreenAutoSwitchController {
  ScreenAutoSwitchController({
    required this._screens,
    required this._telemetry,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  static const Duration minSwitchInterval = Duration(seconds: 10);
  static const Duration manualOverride = Duration(seconds: 60);

  final ScreenManagerService Function() _screens;
  final ValueListenable<CockpitTelemetry> _telemetry;
  final DateTime Function() _clock;

  ThermalFlightMode? _lastMode;
  DateTime? _lastAutoSwitchAt;
  DateTime? _lastManualAt;
  ScreenManagerService? _observedScreens;
  int _observedManualCount = 0;
  String? _screenBeforeAuto;
  String? _autoSwitchedTo;
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    _lastMode = _telemetry.value.thermal.mode.mode;
    final screens = _screens();
    _observedScreens = screens;
    _observedManualCount = screens.manualScreenChangeCount;
    _telemetry.addListener(_onTelemetry);
  }

  void dispose() {
    if (_started) _telemetry.removeListener(_onTelemetry);
    _started = false;
  }

  /// Detects manual screen changes (also across screen manager replacement).
  void _trackManualChanges(ScreenManagerService screens) {
    if (!identical(screens, _observedScreens)) {
      _observedScreens = screens;
      _observedManualCount = screens.manualScreenChangeCount;
      return;
    }
    if (screens.manualScreenChangeCount != _observedManualCount) {
      _observedManualCount = screens.manualScreenChangeCount;
      _lastManualAt = _clock();
      _screenBeforeAuto = null;
      _autoSwitchedTo = null;
    }
  }

  void _onTelemetry() {
    final screens = _screens();
    _trackManualChanges(screens);

    final mode = _telemetry.value.thermal.mode.mode;
    final previous = _lastMode;
    _lastMode = mode;
    if (previous == null || previous == mode) return;
    _onTransition(screens, mode);
  }

  void _log(String msg) {
    if (kDebugMode) debugPrint('[ScreenAutoSwitch] $msg');
  }

  void _onTransition(ScreenManagerService screens, ThermalFlightMode mode) {
    _log(
      'transition -> ${mode.name}, active=${screens.config.activeScreenId}, '
      'autoSwitchedTo=$_autoSwitchedTo, before=$_screenBeforeAuto',
    );
    if (screens.isEditMode) return _log('suppressed: edit mode');
    final now = _clock();
    final manual = _lastManualAt;
    if (manual != null && now.difference(manual) < manualOverride) {
      return _log('suppressed: manual override');
    }
    final lastAuto = _lastAutoSwitchAt;
    if (lastAuto != null && now.difference(lastAuto) < minSwitchInterval) {
      return _log('suppressed: rate limit');
    }

    final config = screens.config;
    final active = config.activeScreenId;

    String? firstWith(ScreenAutoSwitchTrigger trigger) {
      for (final s in config.screens) {
        if (s.autoSwitchTrigger == trigger) return s.id;
      }
      return null;
    }

    if (mode == ThermalFlightMode.circling) {
      final target = firstWith(ScreenAutoSwitchTrigger.onThermalCircling);
      if (target == null || target == active) return;
      _screenBeforeAuto = active;
      _switchTo(screens, target, now);
      return;
    }

    // Leaving the thermal: only after an automatic switch that is still shown.
    if (_autoSwitchedTo == null || _autoSwitchedTo != active) return;
    final before = _screenBeforeAuto;
    final target =
        firstWith(ScreenAutoSwitchTrigger.onGlideStraight) ??
        (before != null && config.screens.any((s) => s.id == before)
            ? before
            : null);
    _screenBeforeAuto = null;
    if (target == null || target == active) {
      _autoSwitchedTo = null;
      return;
    }
    _switchTo(screens, target, now);
    _autoSwitchedTo = null;
  }

  void _switchTo(ScreenManagerService screens, String id, DateTime now) {
    _log('switching to $id');
    screens.setActiveScreen(id, automatic: true);
    _observedManualCount = screens.manualScreenChangeCount;
    _lastAutoSwitchAt = now;
    _autoSwitchedTo = id;
  }
}
