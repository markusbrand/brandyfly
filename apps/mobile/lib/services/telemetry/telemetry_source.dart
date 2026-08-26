import 'dart:async';
import 'telemetry_types.dart';

/// Abstract contract for all telemetry sources (BLE, onboard sensors, synthetic, IGC replay).
abstract class ITelemetrySource {
  /// The type classification of this telemetry provider.
  TelemetrySourceType get sourceType;

  /// Human-readable provider name.
  String get name;

  /// Emits paced snapshots of normalized flight telemetry.
  Stream<TelemetrySnapshot> get telemetryStream;

  /// Emits raw sensor frames or records if available.
  Stream<dynamic> get rawSensorStream;

  /// Whether the telemetry stream is actively producing data.
  bool get isRunning;

  /// Whether the telemetry stream is currently paused.
  bool get isPaused;

  /// Initializes underlying resources or connections.
  Future<void> initialize();

  /// Starts or resumes telemetry streaming.
  Future<void> start();

  /// Pauses telemetry streaming.
  Future<void> pause();

  /// Stops telemetry streaming and resets progress.
  Future<void> stop();

  /// Releases all stream controllers and subscriptions.
  void dispose();
}
