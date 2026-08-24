import 'dart:convert';

import 'package:flutter/foundation.dart';

String _stableHash(Iterable<Object?> parts) {
  final bytes = utf8.encode(parts.map((part) => part?.toString() ?? '').join('|'));
  var hash = 0x811c9dc5;
  for (final byte in bytes) {
    hash ^= byte;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

int _stepSeed(int state) {
  var value = state & 0xffffffff;
  value ^= (value << 13) & 0xffffffff;
  value ^= value >> 17;
  value ^= (value << 5) & 0xffffffff;
  return value & 0xffffffff;
}

class _DeterministicRandom {
  _DeterministicRandom(int seed)
      : _state = seed == 0 ? 0x6d2b79f5 : seed & 0xffffffff;

  int _state;

  int nextInt(int maxExclusive) {
    if (maxExclusive <= 0) {
      throw ArgumentError.value(maxExclusive, 'maxExclusive');
    }
    _state = _stepSeed(_state);
    return _state % maxExclusive;
  }

  int nextRange(int minInclusive, int maxExclusive) {
    if (maxExclusive <= minInclusive) {
      throw ArgumentError.value(maxExclusive, 'maxExclusive');
    }
    return minInclusive + nextInt(maxExclusive - minInclusive);
  }
}

@immutable
class MockFlightModeConfig {
  const MockFlightModeConfig({
    required this.enabled,
    required this.fixtureVersion,
    required this.seed,
    required this.logicalClockStep,
    required this.startTime,
    required this.provenance,
    this.sessionLabel = 'simulated',
  });

  final bool enabled;
  final String fixtureVersion;
  final int seed;
  final Duration logicalClockStep;
  final DateTime startTime;
  final String provenance;
  final String sessionLabel;

  factory MockFlightModeConfig.fromEnvironment() {
    return MockFlightModeConfig(
      enabled: bool.fromEnvironment(
        'BRANDYFLY_LOCAL_MOCK_FLIGHT_MODE',
        defaultValue: false,
      ),
      fixtureVersion: String.fromEnvironment(
        'BRANDYFLY_LOCAL_MOCK_FIXTURE_VERSION',
        defaultValue: 'mock-flight-v1',
      ),
      seed: int.fromEnvironment(
        'BRANDYFLY_LOCAL_MOCK_SEED',
        defaultValue: 170607,
      ),
      logicalClockStep: Duration(
        milliseconds: int.fromEnvironment(
          'BRANDYFLY_LOCAL_MOCK_CLOCK_STEP_MS',
          defaultValue: 1000,
        ),
      ),
      startTime: DateTime.parse(
        String.fromEnvironment(
          'BRANDYFLY_LOCAL_MOCK_START_ISO8601',
          defaultValue: '2026-08-07T00:00:00Z',
        ),
      ),
      provenance: String.fromEnvironment(
        'BRANDYFLY_LOCAL_MOCK_PROVENANCE',
        defaultValue: 'synthetic-anonymized',
      ),
      sessionLabel: String.fromEnvironment(
        'BRANDYFLY_LOCAL_MOCK_SESSION_LABEL',
        defaultValue: 'simulated',
      ),
    );
  }

  MockFlightModeConfig copyWith({
    bool? enabled,
    String? fixtureVersion,
    int? seed,
    Duration? logicalClockStep,
    DateTime? startTime,
    String? provenance,
    String? sessionLabel,
  }) {
    return MockFlightModeConfig(
      enabled: enabled ?? this.enabled,
      fixtureVersion: fixtureVersion ?? this.fixtureVersion,
      seed: seed ?? this.seed,
      logicalClockStep: logicalClockStep ?? this.logicalClockStep,
      startTime: startTime ?? this.startTime,
      provenance: provenance ?? this.provenance,
      sessionLabel: sessionLabel ?? this.sessionLabel,
    );
  }

  void validateBuildMode({required bool isReleaseBuild}) {
    if (isReleaseBuild && enabled) {
      throw StateError(
        'local mock flight mode is unavailable in production builds.',
      );
    }
    if (enabled) {
      if (fixtureVersion.trim().isEmpty ||
          provenance.trim().isEmpty ||
          sessionLabel.trim().isEmpty) {
        throw StateError(
          'local mock flight mode requires fixture version, provenance, and session label metadata.',
        );
      }
    }
  }

  Map<String, Object> toMap() {
    return {
      'enabled': enabled,
      'fixtureVersion': fixtureVersion,
      'seed': seed,
      'logicalClockStepMs': logicalClockStep.inMilliseconds,
      'startTime': startTime.toUtc().toIso8601String(),
      'provenance': provenance,
      'sessionLabel': sessionLabel,
    };
  }
}

enum MockFlightScenarioKind { nominal, offline, stale, failure }

@immutable
class MockFlightFrame {
  const MockFlightFrame({
    required this.kind,
    required this.title,
    required this.telemetrySummary,
    required this.mapSummary,
    required this.logSummary,
    required this.alertSummary,
    required this.uploadSummary,
    required this.exportSummary,
    required this.canonicalEventHash,
    required this.occurredAt,
    required this.stale,
    required this.degraded,
  });

  final MockFlightScenarioKind kind;
  final String title;
  final String telemetrySummary;
  final String mapSummary;
  final String logSummary;
  final String alertSummary;
  final String uploadSummary;
  final String exportSummary;
  final String canonicalEventHash;
  final DateTime occurredAt;
  final bool stale;
  final bool degraded;

  String get scenarioName => kind.name;

  String get sessionMarker => 'SIMULATED_SESSION:${kind.name}:$canonicalEventHash';
}

class MockFlightReplay {
  MockFlightReplay(this.config) : frames = _buildFrames(config);

  final MockFlightModeConfig config;
  final List<MockFlightFrame> frames;
  int _index = 0;

  MockFlightFrame get currentFrame => frames[_index];

  MockFlightFrame advance() {
    _index = (_index + 1) % frames.length;
    return currentFrame;
  }

  void reset() {
    _index = 0;
  }

  String get canonicalReplayHash =>
      _stableHash(frames.map((frame) => frame.canonicalEventHash));

  String exportSummary() {
    final frame = currentFrame;
    return [
      'SIMULATED_SESSION=${config.sessionLabel}',
      'fixture=${config.fixtureVersion}',
      'seed=${config.seed}',
      'clock_step_ms=${config.logicalClockStep.inMilliseconds}',
      'provenance=${config.provenance}',
      'phase=${frame.scenarioName}',
      'event_hash=${frame.canonicalEventHash}',
    ].join('\n');
  }

  static List<MockFlightFrame> _buildFrames(MockFlightModeConfig config) {
    final random = _DeterministicRandom(config.seed);
    final altitude = 1200 + random.nextRange(0, 420);
    final speed = 18 + random.nextRange(0, 17);
    final lift = 1 + random.nextRange(0, 5);
    MockFlightFrame frame({
      required MockFlightScenarioKind kind,
      required String title,
      required String telemetrySummary,
      required String mapSummary,
      required String logSummary,
      required String alertSummary,
      required String uploadSummary,
      required String exportSummary,
      required bool stale,
      required bool degraded,
      required int step,
    }) {
      final occurredAt = config.startTime.add(
        Duration(milliseconds: config.logicalClockStep.inMilliseconds * step),
      );
      final canonicalEventHash = _stableHash([
        config.fixtureVersion,
        config.seed,
        config.logicalClockStep.inMilliseconds,
        config.provenance,
        kind.name,
        title,
        telemetrySummary,
        mapSummary,
        logSummary,
        alertSummary,
        uploadSummary,
        exportSummary,
        stale,
        degraded,
        occurredAt.toUtc().toIso8601String(),
      ]);
      return MockFlightFrame(
        kind: kind,
        title: title,
        telemetrySummary: telemetrySummary,
        mapSummary: mapSummary,
        logSummary: logSummary,
        alertSummary: alertSummary,
        uploadSummary: uploadSummary,
        exportSummary: exportSummary,
        canonicalEventHash: canonicalEventHash,
        occurredAt: occurredAt,
        stale: stale,
        degraded: degraded,
      );
    }

    return [
      frame(
        kind: MockFlightScenarioKind.nominal,
        title: 'Nominal glide',
        telemetrySummary: 'Altitude $altitude m, climb $lift.2 m/s, speed $speed km/h',
        mapSummary: 'Offline tiles cached locally; map interaction enabled',
        logSummary: 'Telemetry stream healthy; all dashboard cards updated',
        alertSummary: 'No alerts; flight state steady',
        uploadSummary: 'Upload queue idle; local export ready',
        exportSummary: 'IGC preview available with simulated-session marker',
        stale: false,
        degraded: false,
        step: 0,
      ),
      frame(
        kind: MockFlightScenarioKind.offline,
        title: 'Offline validation',
        telemetrySummary: 'Synthetic telemetry continues without any network input',
        mapSummary: 'Network disabled; cached map tiles and UI snapshots remain available',
        logSummary: 'Remote feeds unavailable by design; local flow continues',
        alertSummary: 'Offline mode acknowledged and handled explicitly',
        uploadSummary: 'Remote upload unavailable; local export preserved',
        exportSummary: 'Export stays available with offline label',
        stale: false,
        degraded: false,
        step: 1,
      ),
      frame(
        kind: MockFlightScenarioKind.stale,
        title: 'Stale telemetry',
        telemetrySummary: 'Telemetry aged beyond the stale threshold until fresh data resumes',
        mapSummary: 'Track marker remains visible but marked stale',
        logSummary: 'Stale event counted and reported to the operator',
        alertSummary: 'Degraded state shown until fresh telemetry arrives',
        uploadSummary: 'Replay stays deterministic while stale data is surfaced',
        exportSummary: 'Export contains stale-state provenance',
        stale: true,
        degraded: true,
        step: 2,
      ),
      frame(
        kind: MockFlightScenarioKind.failure,
        title: 'Injected failure',
        telemetrySummary: 'One upstream dependency times out while unrelated features continue',
        mapSummary: 'Map remains visible; failed dependency is isolated',
        logSummary: 'Structured error recorded for the failed integration point',
        alertSummary: 'Graceful degradation visible to the operator',
        uploadSummary: 'Failed upstream action leaves local state intact',
        exportSummary: 'Export includes failure marker and replay hash',
        stale: false,
        degraded: true,
        step: 3,
      ),
    ];
  }
}
