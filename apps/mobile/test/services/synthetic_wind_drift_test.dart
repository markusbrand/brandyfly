import 'dart:math' as math;

import 'package:brandyfly/domain/thermal_assistant/thermal_assistant_engine.dart';
import 'package:brandyfly/services/telemetry/synthetic_telemetry_source.dart';
import 'package:brandyfly/services/telemetry/telemetry_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('synthetic source never emits fabricated wind', () {
    final src = SyntheticTelemetrySource(windFromDeg: 270, windSpeedKmh: 20);
    final s = src.stepSynchronously(0.1);
    expect(s.windDirectionDeg, isNull);
    expect(s.windSpeedKmh, isNull);
    src.dispose();
  });

  test('default wind is calm: glide keeps ground speed equal to airspeed', () {
    final src = SyntheticTelemetrySource();
    final s = src.stepSynchronously(1.0);
    expect(s.speed, closeTo(38.0 + (42 % 5) * 0.8, 0.1));
    src.dispose();
  });

  test('20 km/h from 270 deg drifts the track east at ~5.6 m/s', () {
    final src = SyntheticTelemetrySource(
      initialManeuver: FlightManeuver.thermalClimb360,
      windFromDeg: 270,
      windSpeedKmh: 20,
    );
    // Exactly one full turn (20 s at 18 deg/s) cancels the airspeed component.
    final start = src.stepSynchronously(0.1);
    TelemetrySnapshot end = start;
    for (var i = 0; i < 200; i++) {
      end = src.stepSynchronously(0.1);
    }
    final dtS = end.timestamp.difference(start.timestamp).inMilliseconds / 1000;
    final eastM =
        (end.longitude - start.longitude) *
        111139.0 *
        math.cos(start.latitude * math.pi / 180);
    final northM = (end.latitude - start.latitude) * 111139.0;
    expect(eastM / dtS, closeTo(20 / 3.6, 0.6));
    expect(northM / dtS, closeTo(0, 0.6));
    src.dispose();
  });

  test('thermal assistant recovers configured wind after two turns', () {
    final src = SyntheticTelemetrySource(
      frequencyHz: 10,
      initialManeuver: FlightManeuver.thermalClimb360,
      windFromDeg: 270,
      windSpeedKmh: 20,
    );
    final engine = ThermalAssistantEngine();
    for (var i = 0; i < 10 * 70; i++) {
      final s = src.stepSynchronously(0.1);
      engine.update(
        ThermalSample(
          timestampMs: s.timestamp.millisecondsSinceEpoch,
          position: GeoPosition(s.latitude, s.longitude),
          headingDeg: s.heading,
          climbRateMs: s.vario,
        ),
      );
    }
    final wind = engine.state.wind;
    expect(wind, isNotNull);
    expect(wind!.directionDeg, closeTo(270, 10));
    expect(wind.speedKmh, closeTo(20, 4));
    src.dispose();
  });

  test('setWind updates wind parameters', () {
    final src = SyntheticTelemetrySource()..setWind(fromDeg: 400, speedKmh: -3);
    expect(src.windFromDeg, 40);
    expect(src.windSpeedKmh, 0);
    src.dispose();
  });
}
