import 'package:latlong2/latlong.dart' hide Path;
import '../../models/flight_model.dart';

/// Available telemetry source types.
enum TelemetrySourceType {
  ble,
  internalSensor,
  igcReplay,
  synthetic,
  mock,
}

/// Flight maneuvers supported by synthetic flight generators.
enum FlightManeuver {
  steadyGlide,
  thermalClimb360,
  sinkRecovery,
}

/// A unified immutable snapshot of flight telemetry.
class TelemetrySnapshot {
  const TelemetrySnapshot({
    required this.timestamp,
    required this.altitude,
    this.pressureHpa,
    required this.vario,
    required this.speed,
    required this.heading,
    required this.latitude,
    required this.longitude,
    this.gnssAltitude,
    this.hag,
    this.windDirectionDeg,
    this.windSpeedKmh,
    this.isStale = false,
    this.isValid = true,
  });

  final DateTime timestamp;
  final double altitude; // meters
  final double? pressureHpa;
  final double vario; // m/s
  final double speed; // km/h
  final double heading; // degrees (0-360)
  final double latitude;
  final double longitude;
  final double? gnssAltitude;
  final double? hag; // height above ground (meters)
  final double? windDirectionDeg;
  final double? windSpeedKmh;
  final bool isStale;
  final bool isValid;

  FlightPoint toFlightPoint() {
    return FlightPoint(
      timestamp: timestamp,
      latitude: latitude,
      longitude: longitude,
      altitude: altitude,
      gnssAltitude: gnssAltitude ?? altitude,
      vario: vario,
      speed: speed,
      heading: heading,
      hag: hag,
    );
  }

  factory TelemetrySnapshot.fromFlightPoint(
    FlightPoint point, {
    double? pressureHpa,
    double? windDirectionDeg,
    double? windSpeedKmh,
    bool isStale = false,
  }) {
    return TelemetrySnapshot(
      timestamp: point.timestamp,
      altitude: point.altitude,
      pressureHpa: pressureHpa,
      vario: point.vario,
      speed: point.speed,
      heading: point.heading,
      latitude: point.latitude,
      longitude: point.longitude,
      gnssAltitude: point.gnssAltitude,
      hag: point.hag,
      windDirectionDeg: windDirectionDeg ?? ((point.heading + 180.0) % 360.0),
      windSpeedKmh: windSpeedKmh ?? 12.0,
      isStale: isStale,
      isValid: true,
    );
  }

  Map<String, dynamic> toTelemetryMap({
    List<LatLng>? trackPoints,
    List<double>? history,
  }) {
    return {
      'altitude': altitude,
      'speed': speed,
      'glide': 8.0,
      'hag': hag ?? (altitude - 800.0).clamp(0.0, 9999.0),
      'climb': vario,
      'windDir': windDirectionDeg ?? ((heading + 180.0) % 360.0),
      'windSpeed': windSpeedKmh ?? 12.0,
      'latitude': latitude,
      'longitude': longitude,
      'heading': heading,
      'trackPoints': trackPoints ?? [LatLng(latitude, longitude)],
      'history': history ?? [altitude],
      'isStale': isStale,
    };
  }
}
