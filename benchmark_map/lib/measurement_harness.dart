import 'dart:async';
import 'dart:io';

import 'package:flutter/scheduler.dart';

import 'result_schema.dart';

/// Measurement harness for the offline map engine benchmark.
///
/// Instruments:
/// - First-map latency (widget build → first rendered frame)
/// - Frame-time distribution (p50, p95, p99, frames > 16.7 ms, stalls > 100 ms)
/// - Peak process memory (RSS)
/// - Pipeline heartbeat (sensor-path delay detection)
class MeasurementHarness {
  MeasurementHarness({
    this.heartbeatIntervalMs = 500,
  });

  final int heartbeatIntervalMs;

  final Stopwatch _startupStopwatch = Stopwatch();
  bool _firstFrameRecorded = false;
  int _firstMapMs = 0;

  final List<double> _frameTimes = [];
  double _peakMemoryMb = 0;
  int _maxSensorDelayMs = 0;
  int _heartbeatPings = 0;
  Timer? _heartbeatTimer;
  DateTime? _lastHeartbeat;

  bool _running = false;

  /// Call this as early as possible in the map widget's [State.initState].
  void onMapBuildStart() {
    _startupStopwatch
      ..reset()
      ..start();
  }

  /// Call this from the first `SchedulerBinding.addPostFrameCallback` after
  /// the map widget's first layout.
  void onFirstFrame() {
    if (_firstFrameRecorded) return;
    _startupStopwatch.stop();
    _firstMapMs = _startupStopwatch.elapsedMilliseconds;
    _firstFrameRecorded = true;
  }

  /// Starts collecting frame timings and heartbeat.
  ///
  /// Must be called after [onMapBuildStart] and before the benchmark scenario begins.
  void startCollection() {
    if (_running) return;
    _running = true;

    SchedulerBinding.instance.addTimingsCallback(_onFrameTimings);

    _lastHeartbeat = DateTime.now();
    _heartbeatTimer = Timer.periodic(
      Duration(milliseconds: heartbeatIntervalMs),
      _onHeartbeatTick,
    );
  }

  /// Stops collection and returns the final metrics.
  ///
  /// Safe to call multiple times — subsequent calls are no-ops.
  MeasurementSnapshot stop() {
    if (!_running) return _buildSnapshot();
    _running = false;

    SchedulerBinding.instance.removeTimingsCallback(_onFrameTimings);
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    _peakMemoryMb = _currentMemoryMb();

    return _buildSnapshot();
  }

  void _onFrameTimings(List<FrameTiming> timings) {
    if (!_running) return;
    for (final t in timings) {
      final ms = t.totalSpan.inMicroseconds / 1000.0;
      _frameTimes.add(ms);
    }
    // Sample memory on each batch (cheap — avoids per-frame syscall).
    final memMb = _currentMemoryMb();
    if (memMb > _peakMemoryMb) {
      _peakMemoryMb = memMb;
    }
  }

  void _onHeartbeatTick(Timer _) {
    _heartbeatPings++;
    final now = DateTime.now();
    if (_lastHeartbeat != null) {
      final delayMs =
          now.difference(_lastHeartbeat!).inMilliseconds - heartbeatIntervalMs;
      if (delayMs > _maxSensorDelayMs) {
        _maxSensorDelayMs = delayMs.abs();
      }
    }
    _lastHeartbeat = now;
  }

  double _currentMemoryMb() {
    try {
      return ProcessInfo.currentRss / (1024 * 1024);
    } catch (_) {
      return 0;
    }
  }

  MeasurementSnapshot _buildSnapshot() {
    final sorted = List<double>.from(_frameTimes)..sort();
    final n = sorted.length;

    double percentile(double p) {
      if (n == 0) return 0;
      final idx = ((p / 100.0) * (n - 1)).round().clamp(0, n - 1);
      return sorted[idx];
    }

    final over16 = sorted.where((ms) => ms > 16.7).length;
    final stalls = sorted.where((ms) => ms > 100).length;

    return MeasurementSnapshot(
      firstMapMs: _firstMapMs,
      frameMetrics: FrameMetrics(
        totalFrames: n,
        p50Ms: percentile(50),
        p95Ms: percentile(95),
        p99Ms: percentile(99),
        over16Count: over16,
        stallsOver100Count: stalls,
      ),
      peakMemoryMb: _peakMemoryMb,
      maxSensorDelayMs: _maxSensorDelayMs,
      heartbeatPings: _heartbeatPings,
    );
  }
}

/// Immutable snapshot of all collected metrics.
class MeasurementSnapshot {
  const MeasurementSnapshot({
    required this.firstMapMs,
    required this.frameMetrics,
    required this.peakMemoryMb,
    required this.maxSensorDelayMs,
    required this.heartbeatPings,
  });

  final int firstMapMs;
  final FrameMetrics frameMetrics;
  final double peakMemoryMb;
  final int maxSensorDelayMs;
  final int heartbeatPings;

  StartupMetrics get startup => StartupMetrics(firstMapMs: firstMapMs);

  MemoryMetrics get memory => MemoryMetrics(peakMb: peakMemoryMb);

  HeartbeatMetrics get heartbeat => HeartbeatMetrics(
    maxSensorDelayMs: maxSensorDelayMs,
    pings: heartbeatPings,
  );
}
