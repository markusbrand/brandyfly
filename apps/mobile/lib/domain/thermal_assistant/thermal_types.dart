/// Shared value types of the thermal assistant.
///
/// Port of `crates/flight_core/src/{wind,circling}.rs` types. Keep in sync
/// with the Rust reference; parity is enforced by golden fixtures.
library;

/// Geographic position in decimal degrees.
class GeoPosition {
  const GeoPosition(this.lat, this.lon);

  final double lat;
  final double lon;

  @override
  bool operator ==(Object other) =>
      other is GeoPosition && other.lat == lat && other.lon == lon;

  @override
  int get hashCode => Object.hash(lat, lon);

  @override
  String toString() => 'GeoPosition($lat, $lon)';
}

/// Wind vector estimated from thermal drift.
///
/// [velocityXMs]/[velocityYMs] are the drift velocity east/north in m/s,
/// [directionDeg] is the meteorological direction the wind comes FROM.
class WindVector {
  const WindVector({
    required this.speedKmh,
    required this.directionDeg,
    required this.velocityXMs,
    required this.velocityYMs,
  });

  final double speedKmh;
  final double directionDeg;
  final double velocityXMs;
  final double velocityYMs;

  @override
  bool operator ==(Object other) =>
      other is WindVector &&
      other.speedKmh == speedKmh &&
      other.directionDeg == directionDeg &&
      other.velocityXMs == velocityXMs &&
      other.velocityYMs == velocityYMs;

  @override
  int get hashCode =>
      Object.hash(speedKmh, directionDeg, velocityXMs, velocityYMs);
}

/// Turn direction while circling.
enum TurnDirection { left, right, none }

/// Flight mode as determined by the circling detector.
enum ThermalFlightMode { gliding, circling }

/// Flight mode plus turn direction.
class FlightModeState {
  const FlightModeState.gliding()
    : mode = ThermalFlightMode.gliding,
      turn = TurnDirection.none;
  const FlightModeState.circling(this.turn) : mode = ThermalFlightMode.circling;

  final ThermalFlightMode mode;
  final TurnDirection turn;

  bool get isCircling => mode == ThermalFlightMode.circling;

  @override
  bool operator ==(Object other) =>
      other is FlightModeState && other.mode == mode && other.turn == turn;

  @override
  int get hashCode => Object.hash(mode, turn);

  @override
  String toString() => 'FlightModeState(${mode.name}, ${turn.name})';
}
