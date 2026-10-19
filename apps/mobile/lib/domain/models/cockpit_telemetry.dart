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
    this.averageClimb,
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
    this.thermalSession,
    this.hasSource = false,
    this.takeoffTime,
    this.flightDuration,
    this.takeoffLocation,
    this.takeoffAltitude,
    this.rtlDistanceMeters,
    this.rtlBearingDegrees,
    this.rtlRequiredGlide,
    this.rtlAltitudeMarginMeters,
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

  /// Integrated rolling average climb rate (m/s) over the configured window.
  final double? averageClimb;

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

  /// Current or last completed thermal circling session statistics.
  final ThermalSessionStats? thermalSession;

  /// True when values come from a live or replay telemetry source; false for
  /// idle/demo telemetry (instruments may then render labelled previews).
  final bool hasSource;

  /// Confirmed takeoff timestamp; null when in pre-flight standby.
  final DateTime? takeoffTime;

  /// Elapsed duration since takeoff; null when in pre-flight standby.
  final Duration? flightDuration;

  /// Confirmed takeoff coordinates; null when in pre-flight standby.
  final LatLng? takeoffLocation;

  /// Takeoff altitude (meters MSL); null when in pre-flight standby.
  final double? takeoffAltitude;

  /// Geodesic horizontal distance to launch (meters); null when launch is unknown.
  final double? rtlDistanceMeters;

  /// True bearing to launch (degrees); null when launch is unknown.
  final double? rtlBearingDegrees;

  /// Required glide ratio (L/D) to reach takeoff; null when below launch or within 15m.
  final double? rtlRequiredGlide;

  /// Altitude margin above takeoff (meters, current_alt - takeoff_alt); null when launch is unknown.
  final double? rtlAltitudeMarginMeters;

  bool get hasWind => windDir != null && windSpeed != null;

  double get effectiveAverageClimb => averageClimb ?? climb;

  ThermalSessionStats? get effectiveThermalSession =>
      thermalSession ?? thermal.session;

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

    final rawTakeoffTime = map['takeoffTime'];
    final DateTime? takeoffTime = rawTakeoffTime is DateTime
        ? rawTakeoffTime
        : (rawTakeoffTime is String ? DateTime.tryParse(rawTakeoffTime) : null);

    final rawFlightDuration = map['flightDuration'];
    final Duration? flightDuration = rawFlightDuration is Duration
        ? rawFlightDuration
        : (rawFlightDuration is int
            ? Duration(seconds: rawFlightDuration)
            : (rawFlightDuration is num
                ? Duration(milliseconds: (rawFlightDuration * 1000).round())
                : null));

    final rawTakeoffLocation = map['takeoffLocation'];
    final LatLng? takeoffLocation;
    if (rawTakeoffLocation is LatLng) {
      takeoffLocation = rawTakeoffLocation;
    } else if (rawTakeoffLocation is Map) {
      final lat = (rawTakeoffLocation['latitude'] ?? rawTakeoffLocation['lat']) as num?;
      final lng = (rawTakeoffLocation['longitude'] ?? rawTakeoffLocation['lng']) as num?;
      takeoffLocation = (lat != null && lng != null) ? LatLng(lat.toDouble(), lng.toDouble()) : null;
    } else {
      takeoffLocation = null;
    }

    return CockpitTelemetry(
      altitude: d('altitude', 1450.0),
      speed: d('speed', 42.5),
      glide: d('glide', 8.4),
      hag: map.containsKey('hag') ? hag : 320.0,
      climb: d('climb', 1.8),
      averageClimb: (map['averageClimb'] as num?)?.toDouble(),
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
      takeoffTime: takeoffTime,
      flightDuration: flightDuration,
      takeoffLocation: takeoffLocation,
      takeoffAltitude: (map['takeoffAltitude'] as num?)?.toDouble(),
      rtlDistanceMeters: (map['rtlDistanceMeters'] as num?)?.toDouble(),
      rtlBearingDegrees: (map['rtlBearingDegrees'] as num?)?.toDouble(),
      rtlRequiredGlide: (map['rtlRequiredGlide'] as num?)?.toDouble(),
      rtlAltitudeMarginMeters: (map['rtlAltitudeMarginMeters'] as num?)?.toDouble(),
    );
  }

  CockpitTelemetry copyWith({
    double? altitude,
    double? speed,
    double? glide,
    Object? hag = _sentinel,
    double? climb,
    Object? averageClimb = _sentinel,
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
    Object? thermalSession = _sentinel,
    bool? hasSource,
    Object? takeoffTime = _sentinel,
    Object? flightDuration = _sentinel,
    Object? takeoffLocation = _sentinel,
    Object? takeoffAltitude = _sentinel,
    Object? rtlDistanceMeters = _sentinel,
    Object? rtlBearingDegrees = _sentinel,
    Object? rtlRequiredGlide = _sentinel,
    Object? rtlAltitudeMarginMeters = _sentinel,
  }) {
    return CockpitTelemetry(
      altitude: altitude ?? this.altitude,
      speed: speed ?? this.speed,
      glide: glide ?? this.glide,
      hag: identical(hag, _sentinel) ? this.hag : (hag as double?),
      climb: climb ?? this.climb,
      averageClimb: identical(averageClimb, _sentinel)
          ? this.averageClimb
          : (averageClimb as double?),
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
      thermalSession: identical(thermalSession, _sentinel)
          ? this.thermalSession
          : (thermalSession as ThermalSessionStats?),
      hasSource: hasSource ?? this.hasSource,
      takeoffTime: identical(takeoffTime, _sentinel)
          ? this.takeoffTime
          : (takeoffTime as DateTime?),
      flightDuration: identical(flightDuration, _sentinel)
          ? this.flightDuration
          : (flightDuration as Duration?),
      takeoffLocation: identical(takeoffLocation, _sentinel)
          ? this.takeoffLocation
          : (takeoffLocation as LatLng?),
      takeoffAltitude: identical(takeoffAltitude, _sentinel)
          ? this.takeoffAltitude
          : (takeoffAltitude as double?),
      rtlDistanceMeters: identical(rtlDistanceMeters, _sentinel)
          ? this.rtlDistanceMeters
          : (rtlDistanceMeters as double?),
      rtlBearingDegrees: identical(rtlBearingDegrees, _sentinel)
          ? this.rtlBearingDegrees
          : (rtlBearingDegrees as double?),
      rtlRequiredGlide: identical(rtlRequiredGlide, _sentinel)
          ? this.rtlRequiredGlide
          : (rtlRequiredGlide as double?),
      rtlAltitudeMarginMeters: identical(rtlAltitudeMarginMeters, _sentinel)
          ? this.rtlAltitudeMarginMeters
          : (rtlAltitudeMarginMeters as double?),
    );
  }
}
