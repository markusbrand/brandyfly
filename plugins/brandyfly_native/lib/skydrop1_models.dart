/// Transport states for SkyDrop 1 Bluetooth Classic connection.
enum SkyDrop1TransportState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

/// Verification result from a SkyDrop 1 hardware prototype test run.
class SkyDrop1BenchmarkResult {
  const SkyDrop1BenchmarkResult({
    required this.platform,
    required this.deviceModel,
    required this.firmwareVersion,
    required this.testDurationMinutes,
    required this.sampleRateHz,
    required this.totalFramesReceived,
    required this.validSamplesParsed,
    required this.parseFailures,
    required this.duplicatesDetected,
    required this.sequenceGapsDetected,
    required this.staleSamplesCount,
    required this.disconnectEventsCount,
    required this.reconnectSuccessCount,
    required this.coreP50Ms,
    required this.coreP95Ms,
    required this.coreMaxMs,
    required this.latencyGatePassed,
    required this.reconnectWithoutRestartPassed,
    required this.allGatesPassed,
    required this.androidStatus,
    required this.iosStatus,
  });

  factory SkyDrop1BenchmarkResult.fromMap(Map<String, Object?> map) {
    return SkyDrop1BenchmarkResult(
      platform: map['platform'] as String? ?? 'unknown',
      deviceModel: map['deviceModel'] as String? ?? 'unknown',
      firmwareVersion: map['firmwareVersion'] as String? ?? 'unknown',
      testDurationMinutes: (map['testDurationMinutes'] as num?)?.toDouble() ?? 0.0,
      sampleRateHz: (map['sampleRateHz'] as num?)?.toDouble() ?? 0.0,
      totalFramesReceived: (map['totalFramesReceived'] as num?)?.toInt() ?? 0,
      validSamplesParsed: (map['validSamplesParsed'] as num?)?.toInt() ?? 0,
      parseFailures: (map['parseFailures'] as num?)?.toInt() ?? 0,
      duplicatesDetected: (map['duplicatesDetected'] as num?)?.toInt() ?? 0,
      sequenceGapsDetected: (map['sequenceGapsDetected'] as num?)?.toInt() ?? 0,
      staleSamplesCount: (map['staleSamplesCount'] as num?)?.toInt() ?? 0,
      disconnectEventsCount: (map['disconnectEventsCount'] as num?)?.toInt() ?? 0,
      reconnectSuccessCount: (map['reconnectSuccessCount'] as num?)?.toInt() ?? 0,
      coreP50Ms: (map['coreP50Ms'] as num?)?.toDouble() ?? 0.0,
      coreP95Ms: (map['coreP95Ms'] as num?)?.toDouble() ?? 0.0,
      coreMaxMs: (map['coreMaxMs'] as num?)?.toDouble() ?? 0.0,
      latencyGatePassed: map['latencyGatePassed'] as bool? ?? false,
      reconnectWithoutRestartPassed:
          map['reconnectWithoutRestartPassed'] as bool? ?? false,
      allGatesPassed: map['allGatesPassed'] as bool? ?? false,
      androidStatus: map['androidStatus'] as String? ?? 'supported',
      iosStatus: map['iosStatus'] as String? ?? 'unsupported',
    );
  }

  final String platform;
  final String deviceModel;
  final String firmwareVersion;
  final double testDurationMinutes;
  final double sampleRateHz;
  final int totalFramesReceived;
  final int validSamplesParsed;
  final int parseFailures;
  final int duplicatesDetected;
  final int sequenceGapsDetected;
  final int staleSamplesCount;
  final int disconnectEventsCount;
  final int reconnectSuccessCount;
  final double coreP50Ms;
  final double coreP95Ms;
  final double coreMaxMs;
  final bool latencyGatePassed;
  final bool reconnectWithoutRestartPassed;
  final bool allGatesPassed;
  final String androidStatus;
  final String iosStatus;

  Map<String, Object?> toMap() {
    return {
      'platform': platform,
      'deviceModel': deviceModel,
      'firmwareVersion': firmwareVersion,
      'testDurationMinutes': testDurationMinutes,
      'sampleRateHz': sampleRateHz,
      'totalFramesReceived': totalFramesReceived,
      'validSamplesParsed': validSamplesParsed,
      'parseFailures': parseFailures,
      'duplicatesDetected': duplicatesDetected,
      'sequenceGapsDetected': sequenceGapsDetected,
      'staleSamplesCount': staleSamplesCount,
      'disconnectEventsCount': disconnectEventsCount,
      'reconnectSuccessCount': reconnectSuccessCount,
      'coreP50Ms': coreP50Ms,
      'coreP95Ms': coreP95Ms,
      'coreMaxMs': coreMaxMs,
      'latencyGatePassed': latencyGatePassed,
      'reconnectWithoutRestartPassed': reconnectWithoutRestartPassed,
      'allGatesPassed': allGatesPassed,
      'androidStatus': androidStatus,
      'iosStatus': iosStatus,
    };
  }
}
