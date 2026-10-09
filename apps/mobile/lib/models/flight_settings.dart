class FlightSettings {
  const FlightSettings({
    this.takeoffSpeedThresholdKmh = 12.0,
    this.takeoffVarioThresholdMs = 0.8,
    this.takeoffSustainedDurationSeconds = 4,
    this.takeoffHagThresholdM = 15.0,
    this.preTakeoffBufferDurationSeconds = 15,
    this.landingSpeedThresholdKmh = 8.0,
    this.landingVarioThresholdMs = 0.4,
    this.landingSettlingDurationSeconds = 20,
    this.autoUploadToXContest = false,
    this.xcontestUsername = '',
    this.xcontestPassword = '',
    this.varioAudioEnabled = true,
    this.varioVolume = 0.8,
    this.varioClimbThresholdMs = 0.2,
    this.varioSinkThresholdMs = -1.5,
    this.varioSnifferEnabled = false,
  });

  final double takeoffSpeedThresholdKmh;
  final double takeoffVarioThresholdMs;
  final int takeoffSustainedDurationSeconds;
  final double takeoffHagThresholdM;
  final int preTakeoffBufferDurationSeconds;
  final double landingSpeedThresholdKmh;
  final double landingVarioThresholdMs;
  final int landingSettlingDurationSeconds;
  final bool autoUploadToXContest;
  final String xcontestUsername;
  final String xcontestPassword;
  final bool varioAudioEnabled;
  final double varioVolume;
  final double varioClimbThresholdMs;
  final double varioSinkThresholdMs;
  final bool varioSnifferEnabled;

  FlightSettings copyWith({
    double? takeoffSpeedThresholdKmh,
    double? takeoffVarioThresholdMs,
    int? takeoffSustainedDurationSeconds,
    double? takeoffHagThresholdM,
    int? preTakeoffBufferDurationSeconds,
    double? landingSpeedThresholdKmh,
    double? landingVarioThresholdMs,
    int? landingSettlingDurationSeconds,
    bool? autoUploadToXContest,
    String? xcontestUsername,
    String? xcontestPassword,
    bool? varioAudioEnabled,
    double? varioVolume,
    double? varioClimbThresholdMs,
    double? varioSinkThresholdMs,
    bool? varioSnifferEnabled,
  }) {
    return FlightSettings(
      takeoffSpeedThresholdKmh:
          takeoffSpeedThresholdKmh ?? this.takeoffSpeedThresholdKmh,
      takeoffVarioThresholdMs:
          takeoffVarioThresholdMs ?? this.takeoffVarioThresholdMs,
      takeoffSustainedDurationSeconds:
          takeoffSustainedDurationSeconds ??
          this.takeoffSustainedDurationSeconds,
      takeoffHagThresholdM:
          takeoffHagThresholdM ?? this.takeoffHagThresholdM,
      preTakeoffBufferDurationSeconds:
          preTakeoffBufferDurationSeconds ??
          this.preTakeoffBufferDurationSeconds,
      landingSpeedThresholdKmh:
          landingSpeedThresholdKmh ?? this.landingSpeedThresholdKmh,
      landingVarioThresholdMs:
          landingVarioThresholdMs ?? this.landingVarioThresholdMs,
      landingSettlingDurationSeconds:
          landingSettlingDurationSeconds ??
          this.landingSettlingDurationSeconds,
      autoUploadToXContest: autoUploadToXContest ?? this.autoUploadToXContest,
      xcontestUsername: xcontestUsername ?? this.xcontestUsername,
      xcontestPassword: xcontestPassword ?? this.xcontestPassword,
      varioAudioEnabled: varioAudioEnabled ?? this.varioAudioEnabled,
      varioVolume: varioVolume ?? this.varioVolume,
      varioClimbThresholdMs:
          varioClimbThresholdMs ?? this.varioClimbThresholdMs,
      varioSinkThresholdMs: varioSinkThresholdMs ?? this.varioSinkThresholdMs,
      varioSnifferEnabled: varioSnifferEnabled ?? this.varioSnifferEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
    'takeoffSpeedThresholdKmh': takeoffSpeedThresholdKmh,
    'takeoffVarioThresholdMs': takeoffVarioThresholdMs,
    'takeoffSustainedDurationSeconds': takeoffSustainedDurationSeconds,
    'takeoffHagThresholdM': takeoffHagThresholdM,
    'preTakeoffBufferDurationSeconds': preTakeoffBufferDurationSeconds,
    'landingSpeedThresholdKmh': landingSpeedThresholdKmh,
    'landingVarioThresholdMs': landingVarioThresholdMs,
    'landingSettlingDurationSeconds': landingSettlingDurationSeconds,
    'autoUploadToXContest': autoUploadToXContest,
    'xcontestUsername': xcontestUsername,
    'xcontestPassword': xcontestPassword,
    'varioAudioEnabled': varioAudioEnabled,
    'varioVolume': varioVolume,
    'varioClimbThresholdMs': varioClimbThresholdMs,
    'varioSinkThresholdMs': varioSinkThresholdMs,
    'varioSnifferEnabled': varioSnifferEnabled,
  };

  factory FlightSettings.fromJson(Map<String, dynamic> json) => FlightSettings(
    takeoffSpeedThresholdKmh:
        (json['takeoffSpeedThresholdKmh'] as num?)?.toDouble() ?? 12.0,
    takeoffVarioThresholdMs:
        (json['takeoffVarioThresholdMs'] as num?)?.toDouble() ?? 0.8,
    takeoffSustainedDurationSeconds:
        json['takeoffSustainedDurationSeconds'] as int? ?? 4,
    takeoffHagThresholdM:
        (json['takeoffHagThresholdM'] as num?)?.toDouble() ?? 15.0,
    preTakeoffBufferDurationSeconds:
        json['preTakeoffBufferDurationSeconds'] as int? ?? 15,
    landingSpeedThresholdKmh:
        (json['landingSpeedThresholdKmh'] as num?)?.toDouble() ?? 8.0,
    landingVarioThresholdMs:
        (json['landingVarioThresholdMs'] as num?)?.toDouble() ?? 0.4,
    landingSettlingDurationSeconds:
        json['landingSettlingDurationSeconds'] as int? ?? 20,
    autoUploadToXContest: json['autoUploadToXContest'] as bool? ?? false,
    xcontestUsername: json['xcontestUsername'] as String? ?? '',
    xcontestPassword: json['xcontestPassword'] as String? ?? '',
    varioAudioEnabled: json['varioAudioEnabled'] as bool? ?? true,
    varioVolume: (json['varioVolume'] as num?)?.toDouble() ?? 0.8,
    varioClimbThresholdMs:
        (json['varioClimbThresholdMs'] as num?)?.toDouble() ?? 0.2,
    varioSinkThresholdMs:
        (json['varioSinkThresholdMs'] as num?)?.toDouble() ?? -1.5,
    varioSnifferEnabled: json['varioSnifferEnabled'] as bool? ?? false,
  );
}
