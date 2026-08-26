enum FlightState {
  groundPreflight,
  flying,
  landed,
  saved,
}

enum FlightCategory {
  myFlights,
  plannedFlights,
}

enum UploadStatus {
  notUploaded,
  queued,
  uploading,
  uploaded,
  failed,
}

class FlightPoint {
  const FlightPoint({
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.altitude,
    this.gnssAltitude,
    this.vario = 0.0,
    this.speed = 0.0,
    this.heading = 0.0,
    this.hag,
  });

  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final double altitude; // meters MSL (Pressure / Baro or primary)
  final double? gnssAltitude; // meters GNSS
  final double vario; // m/s
  final double speed; // km/h
  final double heading; // degrees (0-360)
  final double? hag; // Height Above Ground (meters)

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'latitude': latitude,
    'longitude': longitude,
    'altitude': altitude,
    'gnssAltitude': gnssAltitude,
    'vario': vario,
    'speed': speed,
    'heading': heading,
    'hag': hag,
  };

  factory FlightPoint.fromJson(Map<String, dynamic> json) => FlightPoint(
    timestamp: DateTime.parse(json['timestamp'] as String),
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    altitude: (json['altitude'] as num).toDouble(),
    gnssAltitude: (json['gnssAltitude'] as num?)?.toDouble(),
    vario: (json['vario'] as num?)?.toDouble() ?? 0.0,
    speed: (json['speed'] as num?)?.toDouble() ?? 0.0,
    heading: (json['heading'] as num?)?.toDouble() ?? 0.0,
    hag: (json['hag'] as num?)?.toDouble(),
  );
}

class FlightStatistics {
  const FlightStatistics({
    required this.duration,
    required this.maxAltitude,
    required this.minAltitude,
    required this.maxClimbRate,
    required this.maxSinkRate,
    required this.totalDistanceKm,
    required this.averageSpeedKmh,
    required this.averageGlideRatio,
  });

  final Duration duration;
  final double maxAltitude; // m
  final double minAltitude; // m
  final double maxClimbRate; // m/s
  final double maxSinkRate; // m/s (negative or positive magnitude)
  final double totalDistanceKm; // km
  final double averageSpeedKmh; // km/h
  final double averageGlideRatio;

  Map<String, dynamic> toJson() => {
    'durationSeconds': duration.inSeconds,
    'maxAltitude': maxAltitude,
    'minAltitude': minAltitude,
    'maxClimbRate': maxClimbRate,
    'maxSinkRate': maxSinkRate,
    'totalDistanceKm': totalDistanceKm,
    'averageSpeedKmh': averageSpeedKmh,
    'averageGlideRatio': averageGlideRatio,
  };

  factory FlightStatistics.fromJson(Map<String, dynamic> json) =>
      FlightStatistics(
        duration: Duration(seconds: json['durationSeconds'] as int? ?? 0),
        maxAltitude: (json['maxAltitude'] as num?)?.toDouble() ?? 0.0,
        minAltitude: (json['minAltitude'] as num?)?.toDouble() ?? 0.0,
        maxClimbRate: (json['maxClimbRate'] as num?)?.toDouble() ?? 0.0,
        maxSinkRate: (json['maxSinkRate'] as num?)?.toDouble() ?? 0.0,
        totalDistanceKm: (json['totalDistanceKm'] as num?)?.toDouble() ?? 0.0,
        averageSpeedKmh: (json['averageSpeedKmh'] as num?)?.toDouble() ?? 0.0,
        averageGlideRatio:
            (json['averageGlideRatio'] as num?)?.toDouble() ?? 0.0,
      );

  static FlightStatistics empty() => const FlightStatistics(
    duration: Duration.zero,
    maxAltitude: 0.0,
    minAltitude: 0.0,
    maxClimbRate: 0.0,
    maxSinkRate: 0.0,
    totalDistanceKm: 0.0,
    averageSpeedKmh: 0.0,
    averageGlideRatio: 0.0,
  );
}

class FlightModel {
  const FlightModel({
    required this.id,
    required this.title,
    required this.date,
    this.pilotName = 'Markus Brandstätter',
    this.gliderType = 'Paraglider',
    this.siteName = '',
    this.category = FlightCategory.myFlights,
    this.uploadStatus = UploadStatus.notUploaded,
    this.points = const [],
    this.statistics = const FlightStatistics(
      duration: Duration.zero,
      maxAltitude: 0.0,
      minAltitude: 0.0,
      maxClimbRate: 0.0,
      maxSinkRate: 0.0,
      totalDistanceKm: 0.0,
      averageSpeedKmh: 0.0,
      averageGlideRatio: 0.0,
    ),
    this.rawIgcContent,
    this.isSampleFlight = false,
  });

  final String id;
  final String title;
  final DateTime date;
  final String pilotName;
  final String gliderType;
  final String siteName;
  final FlightCategory category;
  final UploadStatus uploadStatus;
  final List<FlightPoint> points;
  final FlightStatistics statistics;
  final String? rawIgcContent;
  final bool isSampleFlight;

  FlightModel copyWith({
    String? id,
    String? title,
    DateTime? date,
    String? pilotName,
    String? gliderType,
    String? siteName,
    FlightCategory? category,
    UploadStatus? uploadStatus,
    List<FlightPoint>? points,
    FlightStatistics? statistics,
    String? rawIgcContent,
    bool? isSampleFlight,
  }) {
    return FlightModel(
      id: id ?? this.id,
      title: title ?? this.title,
      date: date ?? this.date,
      pilotName: pilotName ?? this.pilotName,
      gliderType: gliderType ?? this.gliderType,
      siteName: siteName ?? this.siteName,
      category: category ?? this.category,
      uploadStatus: uploadStatus ?? this.uploadStatus,
      points: points ?? this.points,
      statistics: statistics ?? this.statistics,
      rawIgcContent: rawIgcContent ?? this.rawIgcContent,
      isSampleFlight: isSampleFlight ?? this.isSampleFlight,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'date': date.toIso8601String(),
    'pilotName': pilotName,
    'gliderType': gliderType,
    'siteName': siteName,
    'category': category.name,
    'uploadStatus': uploadStatus.name,
    'points': points.map((p) => p.toJson()).toList(),
    'statistics': statistics.toJson(),
    'rawIgcContent': rawIgcContent,
    'isSampleFlight': isSampleFlight,
  };

  factory FlightModel.fromJson(Map<String, dynamic> json) => FlightModel(
    id: json['id'] as String,
    title: json['title'] as String,
    date: DateTime.parse(json['date'] as String),
    pilotName: json['pilotName'] as String? ?? 'Markus Brandstätter',
    gliderType: json['gliderType'] as String? ?? 'Paraglider',
    siteName: json['siteName'] as String? ?? '',
    category: FlightCategory.values.firstWhere(
      (c) => c.name == json['category'],
      orElse: () => FlightCategory.myFlights,
    ),
    uploadStatus: UploadStatus.values.firstWhere(
      (u) => u.name == json['uploadStatus'],
      orElse: () => UploadStatus.notUploaded,
    ),
    points:
        (json['points'] as List<dynamic>?)
            ?.map((p) => FlightPoint.fromJson(p as Map<String, dynamic>))
            .toList() ??
        const [],
    statistics: json['statistics'] != null
        ? FlightStatistics.fromJson(json['statistics'] as Map<String, dynamic>)
        : FlightStatistics.empty(),
    rawIgcContent: json['rawIgcContent'] as String?,
    isSampleFlight: json['isSampleFlight'] as bool? ?? false,
  );
}
