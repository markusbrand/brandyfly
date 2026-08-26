import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:benchmark_map/result_schema.dart';

void main() {
  group('BenchmarkResult — JSON round-trip', () {
  BenchmarkResult buildSample() {
      return const BenchmarkResult(
        device: DeviceInfo(
          model: 'Test Device',
          os: 'android',
          osVersion: 'Android 14',
          buildMode: 'release',
        ),
        package: PackageInfo(name: 'maplibre', version: '0.3.6'),
        startup: StartupMetrics(firstMapMs: 320),
        frames: FrameMetrics(
          totalFrames: 3600,
          p50Ms: 12.5,
          p95Ms: 15.2,
          p99Ms: 18.0,
          over16Count: 180,
          stallsOver100Count: 0,
        ),
        memory: MemoryMetrics(peakMb: 148.5),
        thermal: ThermalInfo(invalidated: false),
        heartbeat: HeartbeatMetrics(maxSensorDelayMs: 12, pings: 1200),
        fixtureVersion: '1.0.0',
        fixtureChecksum: 'abc123',
        runTimestamp: '2026-08-25T20:00:00.000Z',
      );
    }

    test('toJson produces all required fields', () {
      final json = buildSample().toJson();

      expect(json['device'], isA<Map>());
      expect(json['package'], isA<Map>());
      expect(json['startup'], isA<Map>());
      expect(json['frames'], isA<Map>());
      expect(json['memory'], isA<Map>());
      expect(json['thermal'], isA<Map>());
      expect(json['heartbeat'], isA<Map>());
      expect(json['fixtureVersion'], isA<String>());
      expect(json['fixtureChecksum'], isA<String>());
      expect(json['runTimestamp'], isA<String>());
    });

    test('fromJson round-trip is lossless', () {
      final original = buildSample();
      final decoded = BenchmarkResult.fromJson(original.toJson());

      expect(decoded.device.model, original.device.model);
      expect(decoded.device.os, original.device.os);
      expect(decoded.package.name, original.package.name);
      expect(decoded.package.version, original.package.version);
      expect(decoded.startup.firstMapMs, original.startup.firstMapMs);
      expect(decoded.frames.totalFrames, original.frames.totalFrames);
      expect(decoded.frames.p50Ms, original.frames.p50Ms);
      expect(decoded.frames.p95Ms, original.frames.p95Ms);
      expect(decoded.frames.p99Ms, original.frames.p99Ms);
      expect(decoded.frames.over16Count, original.frames.over16Count);
      expect(decoded.frames.stallsOver100Count, original.frames.stallsOver100Count);
      expect(decoded.memory.peakMb, original.memory.peakMb);
      expect(decoded.thermal.invalidated, original.thermal.invalidated);
      expect(decoded.heartbeat.maxSensorDelayMs, original.heartbeat.maxSensorDelayMs);
      expect(decoded.heartbeat.pings, original.heartbeat.pings);
      expect(decoded.fixtureVersion, original.fixtureVersion);
      expect(decoded.fixtureChecksum, original.fixtureChecksum);
      expect(decoded.runTimestamp, original.runTimestamp);
    });

    test('passesFpsGate returns true when p95 ≤ 16.7', () {
      const metrics = FrameMetrics(
        totalFrames: 1000,
        p50Ms: 10.0,
        p95Ms: 16.0,
        p99Ms: 20.0,
        over16Count: 50,
        stallsOver100Count: 0,
      );
      expect(metrics.passesFpsGate, isTrue);
    });

    test('passesFpsGate returns false when p95 > 16.7', () {
      const metrics = FrameMetrics(
        totalFrames: 1000,
        p50Ms: 15.0,
        p95Ms: 18.5,
        p99Ms: 30.0,
        over16Count: 200,
        stallsOver100Count: 5,
      );
      expect(metrics.passesFpsGate, isFalse);
    });

    test('toJsonString produces valid JSON', () {
      final jsonStr = buildSample().toJsonString();
      expect(() => jsonDecode(jsonStr), returnsNormally);
    });

    test('DeviceInfo with optional notes round-trips', () {
      const info = DeviceInfo(
        model: 'Samsung Galaxy S24',
        os: 'android',
        osVersion: 'Android 14',
        buildMode: 'release',
        notes: 'Thermal stabilised 5min',
      );
      final decoded = DeviceInfo.fromJson(info.toJson());
      expect(decoded.notes, 'Thermal stabilised 5min');
    });

    test('ThermalInfo invalidated=true round-trips', () {
      const thermal = ThermalInfo(
        invalidated: true,
        reason: 'Device throttled during setup',
      );
      final decoded = ThermalInfo.fromJson(thermal.toJson());
      expect(decoded.invalidated, isTrue);
      expect(decoded.reason, 'Device throttled during setup');
    });
  });
}
