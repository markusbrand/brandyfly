/// Thermal assistant orchestrator. Port of `ThermalAssistant` in
/// `crates/flight_core/src/thermal_assistant.rs` (the reference
/// implementation). Parity is enforced by the golden fixtures in
/// `packages/contracts/fixtures/thermal_assistant/`.
library;

import 'circling_detector.dart';
import 'thermal_core_calculator.dart';
import 'thermal_types.dart';
import 'wind_estimator.dart';

/// Gap between consecutive valid samples treated as an interruption.
const int interruptionGapMs = 5000;

/// One telemetry sample fed into the thermal assistant.
class ThermalSample {
  const ThermalSample({
    required this.timestampMs,
    required this.position,
    required this.headingDeg,
    required this.climbRateMs,
    this.stale = false,
  });

  final int timestampMs;
  final GeoPosition position;
  final double headingDeg;
  final double climbRateMs;

  /// Stale or invalid samples are ignored.
  final bool stale;
}

/// Output of the thermal assistant after a sample.
class ThermalAssistantOutput {
  const ThermalAssistantOutput({
    required this.timestampMs,
    required this.state,
    this.wind,
    this.windUpdatedMs,
    this.core,
  });

  static const ThermalAssistantOutput initial = ThermalAssistantOutput(
    timestampMs: 0,
    state: FlightModeState.gliding(),
  );

  final int timestampMs;
  final FlightModeState state;
  final WindVector? wind;
  final int? windUpdatedMs;

  /// Lift-weighted core estimate, only while circling.
  final ThermalCoreEstimate? core;
}

/// Deterministic thermal assistant state machine.
class ThermalAssistant {
  ThermalAssistant();

  ThermalAssistant._copy(this._detector, this._wind, this._core);

  CirclingStateDetector _detector = CirclingStateDetector();
  WindEstimator _wind = WindEstimator();
  ThermalCoreCalculator _core = ThermalCoreCalculator();
  int? _lastValidMs;
  ThermalAssistantOutput _output = ThermalAssistantOutput.initial;

  ThermalAssistantOutput get output => _output;

  /// Independent deep copy; continuing either copy does not affect the other.
  ThermalAssistant clone() =>
      ThermalAssistant._copy(_detector.clone(), _wind.clone(), _core.clone())
        .._lastValidMs = _lastValidMs
        .._output = _output;

  /// Number of samples held by the core calculator (bounded to 60 s).
  int get coreSampleCount => _core.pointCount;

  ThermalAssistantOutput update(ThermalSample sample) {
    if (sample.stale) return _output;

    final last = _lastValidMs;
    if (last != null && sample.timestampMs - last > interruptionGapMs) {
      _detector = CirclingStateDetector();
      _wind.reset();
      _core.reset();
    }
    _lastValidMs = sample.timestampMs;

    final previous = _detector.state;
    final state = _detector.update(sample.timestampMs, sample.headingDeg);
    final isCircling = state.isCircling;

    if (previous.isCircling && !isCircling) _core.reset();

    final windBefore = _wind.estimate;
    _wind.update(
      sample.timestampMs,
      sample.headingDeg,
      sample.position,
      isCircling,
    );
    final wind = _wind.estimate;
    final windUpdatedMs = wind != windBefore
        ? sample.timestampMs
        : _output.windUpdatedMs;

    _core.addPoint(
      CoreTrackPoint(sample.timestampMs, sample.position, sample.climbRateMs),
    );
    ThermalCoreEstimate? core;
    if (isCircling) {
      final c = _core.calculate(sample.timestampMs, wind);
      if (c.valid) core = c;
    }

    _output = ThermalAssistantOutput(
      timestampMs: sample.timestampMs,
      state: state,
      wind: wind,
      windUpdatedMs: windUpdatedMs,
      core: core,
    );
    return _output;
  }
}
