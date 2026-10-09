import '../../models/flight_model.dart';
import '../../models/lat_lng.dart';
import '../thermal_assistant/thermal_assistant_engine.dart';

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
    this.windDir,
    this.windSpeed,
    this.windStale = false,
    this.latitude,
    this.longitude,
    this.heading,
    this.trackPoints,
    this.flightPoints,
    this.history = defaultHistory,
    this.isStale = false,
    this.thermal = ThermalAssistantState.idle,
    this.hasSource = false,
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
  /// Wind direction (degrees, from) - null when no estimate is available.
  /// Never fabricated from heading or defaults.
  final double? windDir;

  /// Wind speed (km/h) - null when no estimate is available.
  final double? windSpeed;

  /// True when the wind estimate is older than the staleness limit.
  final bool windStale;
  final double? latitude;
  final double? longitude;

  /// Track heading (degrees); null when unknown.
  final double? heading;
  final List<LatLng>? trackPoints;
  final List<FlightPoint>? flightPoints;
  final List<double> history;
  final bool isStale;

  /// Live thermal assistant state (circling, wind, core, track window).
  final ThermalAssistantState thermal;

  /// True when values come from a live or replay telemetry source; false for
  /// idle/demo telemetry (instruments may then render labelled previews).
  final bool hasSource;

  bool get hasWind => windDir != null && windSpeed != null;

  LatLng? get pilotPosition =>
      (latitude != null && longitude != null) ? LatLng(latitude!, longitude!) : null;

  double get effectiveHeading => heading ?? 0.0;

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
      windDir: (map['windDir'] as num?)?.toDouble(),
      windSpeed: (map['windSpeed'] as num?)?.toDouble(),
      windStale: map['windStale'] == true,
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
    Object? windDir = _sentinel,
    Object? windSpeed = _sentinel,
    bool? windStale,
    double? latitude,
    double? longitude,
    double? heading,
    List<LatLng>? trackPoints,
    List<FlightPoint>? flightPoints,
    List<double>? history,
    bool? isStale,
    ThermalAssistantState? thermal,
    bool? hasSource,
  }) {
    return CockpitTelemetry(
      altitude: altitude ?? this.altitude,
      speed: speed ?? this.speed,
      glide: glide ?? this.glide,
      hag: identical(hag, _sentinel) ? this.hag : (hag as double?),
      climb: climb ?? this.climb,
      windDir: identical(windDir, _sentinel)
          ? this.windDir
          : (windDir as double?),
      windSpeed: identical(windSpeed, _sentinel)
          ? this.windSpeed
          : (windSpeed as double?),
      windStale: windStale ?? this.windStale,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      heading: heading ?? this.heading,
      trackPoints: trackPoints ?? this.trackPoints,
      flightPoints: flightPoints ?? this.flightPoints,
      history: history ?? this.history,
      isStale: isStale ?? this.isStale,
      thermal: thermal ?? this.thermal,
      hasSource: hasSource ?? this.hasSource,
    );
  }
}
