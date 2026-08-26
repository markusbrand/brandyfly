import 'dart:convert';

/// Shared result schema for the offline map engine benchmark.
/// Covers device, package, startup, frame, memory, thermal, and heartbeat metrics.
class BenchmarkResult {
  const BenchmarkResult({
    required this.device,
    required this.package,
    required this.startup,
    required this.frames,
    required this.memory,
    required this.thermal,
    required this.heartbeat,
    required this.fixtureVersion,
    required this.fixtureChecksum,
    required this.runTimestamp,
  });

  final DeviceInfo device;
  final PackageInfo package;
  final StartupMetrics startup;
  final FrameMetrics frames;
  final MemoryMetrics memory;
  final ThermalInfo thermal;
  final HeartbeatMetrics heartbeat;

  /// Fixture manifest version string used for this run.
  final String fixtureVersion;

  /// SHA-256 checksum of the PMTiles fixture used for this run.
  final String fixtureChecksum;

  /// ISO-8601 timestamp of when this run started.
  final String runTimestamp;

  Map<String, dynamic> toJson() => {
    'device': device.toJson(),
    'package': package.toJson(),
    'startup': startup.toJson(),
    'frames': frames.toJson(),
    'memory': memory.toJson(),
    'thermal': thermal.toJson(),
    'heartbeat': heartbeat.toJson(),
    'fixtureVersion': fixtureVersion,
    'fixtureChecksum': fixtureChecksum,
    'runTimestamp': runTimestamp,
  };

  factory BenchmarkResult.fromJson(Map<String, dynamic> json) {
    return BenchmarkResult(
      device: DeviceInfo.fromJson(json['device'] as Map<String, dynamic>),
      package: PackageInfo.fromJson(json['package'] as Map<String, dynamic>),
      startup: StartupMetrics.fromJson(json['startup'] as Map<String, dynamic>),
      frames: FrameMetrics.fromJson(json['frames'] as Map<String, dynamic>),
      memory: MemoryMetrics.fromJson(json['memory'] as Map<String, dynamic>),
      thermal: ThermalInfo.fromJson(json['thermal'] as Map<String, dynamic>),
      heartbeat:
          HeartbeatMetrics.fromJson(json['heartbeat'] as Map<String, dynamic>),
      fixtureVersion: json['fixtureVersion'] as String,
      fixtureChecksum: json['fixtureChecksum'] as String,
      runTimestamp: json['runTimestamp'] as String,
    );
  }

  String toJsonString() => const JsonEncoder.withIndent('  ').convert(toJson());
}

/// Physical device and build environment information.
class DeviceInfo {
  const DeviceInfo({
    required this.model,
    required this.os,
    required this.osVersion,
    required this.buildMode,
    this.notes,
  });

  /// Device model string (e.g. "Samsung Galaxy S24", "iPhone 15 Pro").
  final String model;

  /// Platform name: "android" or "ios".
  final String os;

  /// OS version string (e.g. "Android 14", "iOS 17.4").
  final String osVersion;

  /// Flutter build mode: "release" or "profile".
  final String buildMode;

  /// Optional notes (e.g. thermal stabilisation status).
  final String? notes;

  Map<String, dynamic> toJson() => {
    'model': model,
    'os': os,
    'osVersion': osVersion,
    'buildMode': buildMode,
    if (notes != null) 'notes': notes,
  };

  factory DeviceInfo.fromJson(Map<String, dynamic> json) => DeviceInfo(
    model: json['model'] as String,
    os: json['os'] as String,
    osVersion: json['osVersion'] as String,
    buildMode: json['buildMode'] as String,
    notes: json['notes'] as String?,
  );
}

/// Package under test.
class PackageInfo {
  const PackageInfo({required this.name, required this.version});

  /// Package name: "maplibre" or "maplibre_gl".
  final String name;

  /// Pinned version string (e.g. "0.3.6").
  final String version;

  Map<String, dynamic> toJson() => {'name': name, 'version': version};

  factory PackageInfo.fromJson(Map<String, dynamic> json) => PackageInfo(
    name: json['name'] as String,
    version: json['version'] as String,
  );
}

/// First-map startup latency.
class StartupMetrics {
  const StartupMetrics({required this.firstMapMs});

  /// Milliseconds from widget build start to first rendered frame.
  final int firstMapMs;

  Map<String, dynamic> toJson() => {'firstMapMs': firstMapMs};

  factory StartupMetrics.fromJson(Map<String, dynamic> json) =>
      StartupMetrics(firstMapMs: json['firstMapMs'] as int);
}

/// Frame timing distribution over the benchmark run.
class FrameMetrics {
  const FrameMetrics({
    required this.totalFrames,
    required this.p50Ms,
    required this.p95Ms,
    required this.p99Ms,
    required this.over16Count,
    required this.stallsOver100Count,
  });

  final int totalFrames;

  /// Median frame time in milliseconds.
  final double p50Ms;

  /// 95th percentile frame time in milliseconds.
  /// Gate: must be ≤ 16.7 ms (≥ 60 FPS) to pass.
  final double p95Ms;

  /// 99th percentile frame time in milliseconds.
  final double p99Ms;

  /// Number of frames that took > 16.7 ms.
  final int over16Count;

  /// Number of frame stalls > 100 ms (severe jank).
  final int stallsOver100Count;

  /// Returns true if this result passes the mandatory 60-FPS gate.
  bool get passesFpsGate => p95Ms <= 16.7;

  Map<String, dynamic> toJson() => {
    'totalFrames': totalFrames,
    'p50Ms': p50Ms,
    'p95Ms': p95Ms,
    'p99Ms': p99Ms,
    'over16Count': over16Count,
    'stallsOver100Count': stallsOver100Count,
  };

  factory FrameMetrics.fromJson(Map<String, dynamic> json) => FrameMetrics(
    totalFrames: json['totalFrames'] as int,
    p50Ms: (json['p50Ms'] as num).toDouble(),
    p95Ms: (json['p95Ms'] as num).toDouble(),
    p99Ms: (json['p99Ms'] as num).toDouble(),
    over16Count: json['over16Count'] as int,
    stallsOver100Count: json['stallsOver100Count'] as int,
  );
}

/// Peak process memory usage.
class MemoryMetrics {
  const MemoryMetrics({required this.peakMb});

  /// Peak resident set size in megabytes.
  final double peakMb;

  Map<String, dynamic> toJson() => {'peakMb': peakMb};

  factory MemoryMetrics.fromJson(Map<String, dynamic> json) =>
      MemoryMetrics(peakMb: (json['peakMb'] as num).toDouble());
}

/// Whether the run was thermally valid.
class ThermalInfo {
  const ThermalInfo({required this.invalidated, this.reason});

  /// If true, the device throttled during setup — run must be excluded.
  final bool invalidated;

  /// Optional reason for invalidation.
  final String? reason;

  Map<String, dynamic> toJson() => {
    'invalidated': invalidated,
    if (reason != null) 'reason': reason,
  };

  factory ThermalInfo.fromJson(Map<String, dynamic> json) => ThermalInfo(
    invalidated: json['invalidated'] as bool,
    reason: json['reason'] as String?,
  );
}

/// Pipeline heartbeat metrics — detects sensor-path stalls caused by map load.
class HeartbeatMetrics {
  const HeartbeatMetrics({required this.maxSensorDelayMs, required this.pings});

  /// Maximum delay between expected and actual sensor heartbeat ticks, in ms.
  final int maxSensorDelayMs;

  /// Total number of heartbeat pings sent during the run.
  final int pings;

  Map<String, dynamic> toJson() => {
    'maxSensorDelayMs': maxSensorDelayMs,
    'pings': pings,
  };

  factory HeartbeatMetrics.fromJson(Map<String, dynamic> json) =>
      HeartbeatMetrics(
        maxSensorDelayMs: json['maxSensorDelayMs'] as int,
        pings: json['pings'] as int,
      );
}
