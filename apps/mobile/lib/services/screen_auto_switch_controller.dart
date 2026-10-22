import 'package:flutter/foundation.dart';

import '../domain/models/cockpit_telemetry.dart';
import '../domain/models/ui_config.dart';
import '../domain/thermal_assistant/circling_detector.dart';
import '../domain/thermal_assistant/thermal_assistant_engine.dart';
import 'screen_manager_service.dart';

/// Switches flight screens automatically while thermaling, for screens
/// configured with [ScreenAutoSwitchTrigger]s.
///
/// The desired screen is re-evaluated on every telemetry update (level-based),
/// so switches suppressed by the rate limit, a manual override or edit mode
/// are deferred rather than lost.
///
/// - Circling in lift (average climb > 0 m/s, non-stale telemetry) activates
///   the first `onThermalCircling` screen and remembers the previous screen.
///   Entry fires at most once per circling phase.
/// - After such an automatic switch, once the pilot has flown straight for
///   [straightFlightBeforeReturn], the first `onGlideStraight` screen (or else
///   the remembered screen) is activated. Renewed circling cancels the return.
/// - A manual screen change cancels any pending return and suppresses
///   auto-switching for [manualOverride].
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

  /// Straight flight required before leaving the thermaling screen.
  static const Duration straightFlightBeforeReturn = Duration(seconds: 10);

  /// Extra hold after the circling detector reports gliding (it already
  /// requires a stable heading for [CirclingStateDetector.glidingStabilityDurationMs]).
  static final Duration returnHold =
      straightFlightBeforeReturn -
      const Duration(
        milliseconds: CirclingStateDetector.glidingStabilityDurationMs,
      );

  /// Minimum average climb rate (m/s, exclusive) to count as being in lift.
  static const double minClimbForThermal = 0.0;

  final ScreenManagerService Function() _screens;
  final ValueListenable<CockpitTelemetry> _telemetry;
  final DateTime Function() _clock;

  DateTime? _lastAutoSwitchAt;
  DateTime? _lastManualAt;
  DateTime? _glidingSince;
  ScreenManagerService? _observedScreens;
  int _observedManualCount = 0;
  String? _screenBeforeAuto;
  String? _autoSwitchedTo;
  bool _entryArmed = true;
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    final screens = _screens();
    _observedScreens = screens;
    _observedManualCount = screens.manualScreenChangeCount;
    _telemetry.addListener(_onTelemetry);
  }

  void dispose() {
    if (_started) _telemetry.removeListener(_onTelemetry);
    _started = false;
  }

  void _log(String msg) {
    if (kDebugMode) debugPrint('[ScreenAutoSwitch] $msg');
  }

  /// Detects manual screen changes (also across screen manager replacement).
  void _trackManualChanges(ScreenManagerService screens, bool circling) {
    if (!identical(screens, _observedScreens)) {
      _observedScreens = screens;
      _observedManualCount = screens.manualScreenChangeCount;
      _clearAutoState();
      return;
    }
    if (screens.manualScreenChangeCount != _observedManualCount) {
      _observedManualCount = screens.manualScreenChangeCount;
      _lastManualAt = _clock();
      _clearAutoState();
      // The pilot chose a screen during this thermal: respect it until the
      // next circling phase.
      if (circling) _entryArmed = false;
      _log('manual change -> override');
    }
  }

  void _clearAutoState() {
    _screenBeforeAuto = null;
    _autoSwitchedTo = null;
  }

  void _onTelemetry() {
    final telemetry = _telemetry.value;
    final circling = telemetry.thermal.mode.mode == ThermalFlightMode.circling;
    final now = _clock();
    final screens = _screens();
    _trackManualChanges(screens, circling);

    if (circling) {
      _glidingSince = null;
    } else {
      _glidingSince ??= now;
      _entryArmed = true;
    }

    // The auto-switched screen is no longer shown (removed / replaced).
    if (_autoSwitchedTo != null &&
        _autoSwitchedTo != screens.config.activeScreenId) {
      _clearAutoState();
    }

    if (screens.isEditMode) return;
    final manual = _lastManualAt;
    if (manual != null && now.difference(manual) < manualOverride) return;
    final lastAuto = _lastAutoSwitchAt;
    if (lastAuto != null && now.difference(lastAuto) < minSwitchInterval) {
      return;
    }

    if (_autoSwitchedTo == null) {
      if (circling && _entryArmed) _tryEnter(screens, telemetry, now);
    } else if (!circling) {
      final since = _glidingSince;
      if (since != null && now.difference(since) >= returnHold) {
        _returnFromThermal(screens, now);
      }
    }
  }

  String? _firstWith(UIConfig config, ScreenAutoSwitchTrigger trigger) {
    for (final s in config.screens) {
      if (s.autoSwitchTrigger == trigger) return s.id;
    }
    return null;
  }

  void _tryEnter(
    ScreenManagerService screens,
    CockpitTelemetry telemetry,
    DateTime now,
  ) {
    if (telemetry.isStale) return;
    if (telemetry.effectiveAverageClimb <= minClimbForThermal) return;
    final config = screens.config;
    final target = _firstWith(
      config,
      ScreenAutoSwitchTrigger.onThermalCircling,
    );
    _entryArmed = false;
    if (target == null || target == config.activeScreenId) return;
    final before = config.activeScreenId;
    _switchTo(screens, target, now);
    _screenBeforeAuto = before;
    _autoSwitchedTo = target;
  }

  void _returnFromThermal(ScreenManagerService screens, DateTime now) {
    final config = screens.config;
    final active = config.activeScreenId;
    final before = _screenBeforeAuto;
    final target =
        _firstWith(config, ScreenAutoSwitchTrigger.onGlideStraight) ??
        (before != null && config.screens.any((s) => s.id == before)
            ? before
            : null);
    _clearAutoState();
    if (target == null || target == active) return;
    _switchTo(screens, target, now);
  }

  void _switchTo(ScreenManagerService screens, String id, DateTime now) {
    _log('switching to $id');
    screens.setActiveScreen(id, automatic: true);
    _observedManualCount = screens.manualScreenChangeCount;
    _lastAutoSwitchAt = now;
  }
}
