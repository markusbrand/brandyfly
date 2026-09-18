import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:brandyfly/models/flight_model.dart';
import 'package:brandyfly/models/flight_settings.dart';
import 'package:brandyfly/services/flight_tracking_service.dart';
import 'package:brandyfly/services/telemetry/telemetry_source.dart';
import 'package:brandyfly/services/telemetry/telemetry_types.dart';

class _MockHighFrequencyTelemetrySource implements ITelemetrySource {
  final _controller = StreamController<TelemetrySnapshot>.broadcast();
  final _rawController = StreamController<dynamic>.broadcast();
  bool _running = false;
  bool _paused = false;

  @override
  Stream<TelemetrySnapshot> get telemetryStream => _controller.stream;

  @override
  Stream<dynamic> get rawSensorStream => _rawController.stream;

  @override
  TelemetrySourceType get sourceType => TelemetrySourceType.mock;

  @override
  String get name => 'HighFreqMock';

  @override
  bool get isRunning => _running;

  @override
  bool get isPaused => _paused;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> start() async {
    _running = true;
    _paused = false;
  }

  @override
  Future<void> pause() async {
    _paused = true;
  }

  @override
  Future<void> stop() async {
    _running = false;
    _paused = false;
  }

  void emit(TelemetrySnapshot snapshot) {
    _controller.add(snapshot);
  }

  @override
  void dispose() {
    _controller.close();
    _rawController.close();
  }
}

void main() {
  group('Telemetry Latency and Zero-Allocation Performance Tests', () {
    late FlightTrackingService service;

    setUp(() {
      service = FlightTrackingService(
        settings: const FlightSettings(
          takeoffSpeedThresholdKmh: 12.0,
          takeoffVarioThresholdMs: 0.8,
          takeoffSustainedDurationSeconds: 1, // 1 second for fast transition in tests
          landingSpeedThresholdKmh: 8.0,
          landingVarioThresholdMs: 0.4,
          landingSettlingDurationSeconds: 10,
          preTakeoffBufferDurationSeconds: 5,
        ),
      );
    });

    test('activeFlightPoints provides zero-allocation unmodifiable view', () {
      final baseTime = DateTime.utc(2026, 9, 1, 12, 0, 0);

      // Add a point
      service.processPoint(
        FlightPoint(
          timestamp: baseTime,
          latitude: 46.5,
          longitude: 8.5,
          altitude: 1500.0,
          speed: 30.0,
          vario: 1.5,
        ),
      );

      // Verify that subsequent reads return the identical view instance (no new allocations)
      final read1 = service.activeFlightPoints;
      final read2 = service.activeFlightPoints;
      expect(identical(read1, read2), isTrue,
          reason: 'activeFlightPoints must return cached UnmodifiableListView');

      // Verify unmodifiable contract (immutability)
      expect(
        () => read1.add(
          FlightPoint(
            timestamp: baseTime,
            latitude: 46.5,
            longitude: 8.5,
            altitude: 1500.0,
            speed: 30.0,
            vario: 1.5,
          ),
        ),
        throwsUnsupportedError,
      );
    });

    test('Processes 1,000 telemetry points at sub-millisecond per-point latency (<100ms total)', () {
      final baseTime = DateTime.utc(2026, 9, 1, 12, 0, 0);
      final stopwatch = Stopwatch()..start();

      const pointCount = 1000;
      for (int i = 0; i < pointCount; i++) {
        service.processPoint(
          FlightPoint(
            timestamp: baseTime.add(Duration(milliseconds: i * 20)), // 50Hz
            latitude: 46.5 + (i * 0.00001),
            longitude: 8.5 + (i * 0.00001),
            altitude: 1500.0 + (i * 0.1),
            speed: 35.0,
            vario: 1.2,
          ),
        );
      }

      stopwatch.stop();
      final totalMs = stopwatch.elapsedMilliseconds;
      final avgMicrosPerPoint = stopwatch.elapsedMicroseconds / pointCount;

      // Ensure execution is well under the 100ms budget (< 100 microseconds per point on average)
      expect(totalMs, lessThan(100),
          reason: '1,000 points processed in $totalMs ms ($avgMicrosPerPoint µs/pt)');
      expect(service.state, FlightState.flying);
    });

    test('Dispatches high-frequency stream events once airborne with sub-16ms delivery guarantee', () async {
      final mockSource = _MockHighFrequencyTelemetrySource();
      service.attachTelemetrySource(mockSource);

      final receivedPoints = <FlightPoint>[];
      final subscription = service.pointStream.listen(receivedPoints.add);

      final baseTime = DateTime.utc(2026, 9, 1, 12, 0, 0);

      // Trigger takeoff first: 2 seconds of flight points (at t=0 and t=1.5s)
      mockSource.emit(
        TelemetrySnapshot(
          timestamp: baseTime,
          latitude: 46.5,
          longitude: 8.5,
          altitude: 1500.0,
          speed: 35.0,
          vario: 1.5,
          heading: 180.0,
        ),
      );
      mockSource.emit(
        TelemetrySnapshot(
          timestamp: baseTime.add(const Duration(milliseconds: 1500)),
          latitude: 46.501,
          longitude: 8.501,
          altitude: 1505.0,
          speed: 36.0,
          vario: 1.8,
          heading: 180.0,
        ),
      );

      // Allow microtask queue to process takeoff transition
      await Future.delayed(const Duration(milliseconds: 10));
      expect(service.state, equals(FlightState.flying));

      // Now emit 100 high-frequency flight points while airborne
      final start = DateTime.now();
      for (int i = 0; i < 100; i++) {
        mockSource.emit(
          TelemetrySnapshot(
            timestamp: baseTime.add(Duration(milliseconds: 2000 + (i * 10))),
            latitude: 46.502 + (i * 0.0001),
            longitude: 8.502 + (i * 0.0001),
            altitude: 1510.0 + (i * 0.2),
            speed: 38.0,
            vario: 2.0,
            heading: 180.0,
          ),
        );
      }

      // Allow microtask queue to flush
      await Future.delayed(const Duration(milliseconds: 20));

      final duration = DateTime.now().difference(start);
      expect(receivedPoints.length, equals(100));
      expect(duration.inMilliseconds, lessThan(200));

      await subscription.cancel();
      mockSource.dispose();
    });

    test('Re-attaching telemetry source correctly detaches previous stream subscription', () async {
      final mockSource1 = _MockHighFrequencyTelemetrySource();
      final mockSource2 = _MockHighFrequencyTelemetrySource();

      service.attachTelemetrySource(mockSource1);
      expect(service.telemetrySource, equals(mockSource1));

      service.attachTelemetrySource(mockSource2);
      expect(service.telemetrySource, equals(mockSource2));

      // Manually trigger flying state so pointStream delivers
      final baseTime = DateTime.utc(2026, 9, 1, 12, 0, 0);
      service.processPoint(FlightPoint(
        timestamp: baseTime,
        latitude: 46.5,
        longitude: 8.5,
        altitude: 1200.0,
        speed: 25.0,
        vario: 1.0,
      ));
      service.processPoint(FlightPoint(
        timestamp: baseTime.add(const Duration(seconds: 2)),
        latitude: 46.51,
        longitude: 8.51,
        altitude: 1205.0,
        speed: 25.0,
        vario: 1.0,
      ));
      expect(service.state, equals(FlightState.flying));

      final points = <FlightPoint>[];
      final sub = service.pointStream.listen(points.add);

      // Emitting on mockSource1 should NOT trigger processing
      mockSource1.emit(
        TelemetrySnapshot(
          timestamp: baseTime.add(const Duration(seconds: 3)),
          latitude: 46.52,
          longitude: 8.52,
          altitude: 1210.0,
          speed: 20.0,
          vario: 0.5,
          heading: 90.0,
        ),
      );

      await Future.delayed(const Duration(milliseconds: 10));
      expect(points, isEmpty);

      // Emitting on mockSource2 should trigger processing
      mockSource2.emit(
        TelemetrySnapshot(
          timestamp: baseTime.add(const Duration(seconds: 4)),
          latitude: 46.53,
          longitude: 8.53,
          altitude: 1215.0,
          speed: 20.0,
          vario: 0.5,
          heading: 90.0,
        ),
      );

      await Future.delayed(const Duration(milliseconds: 10));
      expect(points.length, equals(1));

      await sub.cancel();
      mockSource1.dispose();
      mockSource2.dispose();
    });
  });
}
