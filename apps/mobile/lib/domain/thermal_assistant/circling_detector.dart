/// Circling state detection. Port of `CirclingStateDetector` in
/// `crates/flight_core/src/circling.rs`.
library;

import 'heading_tracker.dart';
import 'thermal_types.dart';

class CirclingStateDetector {
  CirclingStateDetector();

  static const int circlingWindowMs = 25000;
  static const double circlingThresholdDeg = 270.0;
  static const int glidingStabilityDurationMs = 8000;
  static const double glidingToleranceDeg = 15.0;

  CirclingStateDetector._copy(this._tracker, this._state);

  HeadingTracker _tracker = HeadingTracker(circlingWindowMs);
  FlightModeState _state = const FlightModeState.gliding();

  /// Independent deep copy.
  CirclingStateDetector clone() =>
      CirclingStateDetector._copy(_tracker.clone(), _state);

  FlightModeState get state => _state;

  /// Processes a heading sample and returns the (possibly unchanged) state.
  FlightModeState update(int timestampMs, double headingDeg) {
    _tracker.pushSample(timestampMs, headingDeg);

    if (!_state.isCircling) {
      final change = _tracker.cumulativeHeadingChange();
      if (change.abs() >= circlingThresholdDeg) {
        _state = FlightModeState.circling(
          change > 0.0 ? TurnDirection.right : TurnDirection.left,
        );
      }
    } else if (_tracker.isHeadingStable(
      timestampMs,
      glidingStabilityDurationMs,
      glidingToleranceDeg,
    )) {
      _state = const FlightModeState.gliding();
      _tracker.clear();
      _tracker.pushSample(timestampMs, headingDeg);
    }
    return _state;
  }
}
