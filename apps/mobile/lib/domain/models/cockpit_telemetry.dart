import '../../models/flight_model.dart';
import '../../models/lat_lng.dart';

/// Immutable, typed telemetry snapshot rendered by the flight canvas.
///
/// Replaces the untyped `Map<String, dynamic>` previously passed to the layout
/// so that each instrument can subscribe to just the fields it displays.
class CockpitTelemetry {
  const CockpitTelemetry({
    this.altitude = 1450.0,
    this.speed = 42.5,
    this.glide = 8.4,
    this.hag = 320.0,
    this.climb = 1.8,
    this.windDir = 220.0,
    this.windSpeed = 14.0,
    this.latitude,
    this.longitude,
    this.heading,
    this.trackPoints,
    this.flightPoints,
    this.history = defaultHistory,
    this.isStale = false,
  });

  static const List<double> defaultHistory = [
    1400.0,
    1410.0,
    1430.0,
    1425.0,
    1450.0,
  ];

  static const Object _sentinel = Object();

  final double altitude;
  final double speed;
  final double glide;
  final double? hag;
  final double climb;
  final double windDir;
  final double windSpeed;
  final double? latitude;
  final double? longitude;

  /// Track heading; falls back to wind direction when unknown (legacy behavior).
  final double? heading;
  final List<LatLng>? trackPoints;
  final List<FlightPoint>? flightPoints;
  final List<double> history;
  final bool isStale;

  LatLng? get pilotPosition =>
      (latitude != null && longitude != null) ? LatLng(latitude!, longitude!) : null;

  double get effectiveHeading => heading ?? windDir;

  /// Builds a snapshot from the legacy telemetry map format.
  factory CockpitTelemetry.fromMap(Map<String, dynamic> map) {
    double d(String key, double fallback) =>
        (map[key] as num?)?.toDouble() ?? fallback;

    final rawHistory = map['history'];
    final List<double> history;
    if (rawHistory is List<double>) {
      history = rawHistory;
    } else if (rawHistory is List) {
      history = [for (final e in rawHistory) (e as num).toDouble()];
    } else {
      history = defaultHistory;
    }

    final rawHag = map['hag'];
    final double? hag = (rawHag is num) ? rawHag.toDouble() : null;

    final rawTrack = map['trackPoints'];
    final rawFlight = map['flightPoints'] ?? map['activeFlightPoints'];

    return CockpitTelemetry(
      altitude: d('altitude', 1450.0),
      speed: d('speed', 42.5),
      glide: d('glide', 8.4),
      hag: map.containsKey('hag') ? hag : 320.0,
      climb: d('climb', 1.8),
      windDir: d('windDir', 220.0),
      windSpeed: d('windSpeed', 14.0),
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      heading: (map['heading'] as num?)?.toDouble(),
      trackPoints: rawTrack is List<LatLng> ? rawTrack : null,
      flightPoints: rawFlight is List<FlightPoint> ? rawFlight : null,
      history: history,
      isStale: map['isStale'] == true,
    );
  }

  CockpitTelemetry copyWith({
    double? altitude,
    double? speed,
    double? glide,
    Object? hag = _sentinel,
    double? climb,
    double? windDir,
    double? windSpeed,
    double? latitude,
    double? longitude,
    double? heading,
    List<LatLng>? trackPoints,
    List<FlightPoint>? flightPoints,
    List<double>? history,
    bool? isStale,
  }) {
    return CockpitTelemetry(
      altitude: altitude ?? this.altitude,
      speed: speed ?? this.speed,
      glide: glide ?? this.glide,
      hag: identical(hag, _sentinel) ? this.hag : (hag as double?),
      climb: climb ?? this.climb,
      windDir: windDir ?? this.windDir,
      windSpeed: windSpeed ?? this.windSpeed,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      heading: heading ?? this.heading,
      trackPoints: trackPoints ?? this.trackPoints,
      flightPoints: flightPoints ?? this.flightPoints,
      history: history ?? this.history,
      isStale: isStale ?? this.isStale,
    );
  }
}
