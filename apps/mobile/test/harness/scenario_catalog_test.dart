import 'package:flutter_test/flutter_test.dart';

import 'scenario_catalog.dart';

void main() {
  group('ScenarioCatalog', () {
    test('contains 6 core flight scenarios', () {
      final scenarios = ScenarioCatalog.all;
      expect(scenarios.length, 6);
      final ids = scenarios.map((s) => s.id).toList();
      expect(ids, [
        'steady_glide',
        'thermal_climb',
        'heavy_sink',
        'airspace_alert',
        'sensor_dropouts',
        'boundary_extremes',
      ]);
    });

    test('byId resolves scenarios correctly', () {
      expect(ScenarioCatalog.byId('steady_glide').name, 'Steady Glide');
      expect(ScenarioCatalog.byId('thermal_climb').name, 'Thermal Climb');
      expect(ScenarioCatalog.byId('heavy_sink').name, 'Heavy Sink');
      expect(ScenarioCatalog.byId('airspace_alert').name, 'Airspace Alert');
      expect(ScenarioCatalog.byId('sensor_dropouts').name, 'Sensor Dropouts');
      expect(ScenarioCatalog.byId('boundary_extremes').name, 'Boundary Extremes');
      expect(
        () => ScenarioCatalog.byId('unknown'),
        throwsArgumentError,
      );
    });

    test('each scenario has valid duration, steps, and milestone alignment', () {
      for (final scenario in ScenarioCatalog.all) {
        expect(scenario.duration > Duration.zero, isTrue,
            reason: '${scenario.id} duration must be positive');
        expect(scenario.steps.isNotEmpty, isTrue,
            reason: '${scenario.id} steps must not be empty');
        expect(scenario.milestones.length, greaterThanOrEqualTo(2),
            reason: '${scenario.id} must define at least 2 milestones');

        // Check milestones exist within scenario duration
        for (final milestone in scenario.milestones) {
          expect(milestone.elapsed <= scenario.duration, isTrue,
              reason: 'Milestone ${milestone.name} exceeds ${scenario.id} duration');
          expect(milestone.name.isNotEmpty, isTrue);
        }

        // Check telemetryAt boundary conditions
        final t0 = scenario.telemetryAt(Duration.zero);
        expect(t0, isNotNull);
        final tEnd = scenario.telemetryAt(scenario.duration);
        expect(tEnd, isNotNull);
      }
    });

    test('thermal_climb scenario specifies circling mode and lift values', () {
      final thermal = ScenarioCatalog.thermalClimb;
      final peakMilestone = thermal.milestones.firstWhere((m) => m.name == 'core_peak');
      final telemetryAtPeak = thermal.telemetryAt(peakMilestone.elapsed);

      expect(telemetryAtPeak.climb, greaterThan(2.0));
      expect(telemetryAtPeak.thermal.isCircling, isTrue);
      expect(telemetryAtPeak.thermalSession, isNotNull);
      expect(telemetryAtPeak.hasWind, isTrue);
    });

    test('heavy_sink scenario exhibits rapid sink and decreasing HAG', () {
      final sink = ScenarioCatalog.heavySink;
      final t0 = sink.telemetryAt(Duration.zero);
      final tMax = sink.telemetryAt(const Duration(seconds: 5));

      expect(tMax.climb, lessThan(-3.0));
      expect(tMax.hag, isNotNull);
      expect(tMax.hag!, lessThan(t0.hag!));
    });

    test('sensor_dropouts scenario exhibits stale flags and recovery', () {
      final dropouts = ScenarioCatalog.sensorDropouts;
      final tNominal = dropouts.telemetryAt(Duration.zero);
      expect(tNominal.isStale, isFalse);
      expect(tNominal.hasSource, isTrue);

      final tLost = dropouts.telemetryAt(const Duration(seconds: 5));
      expect(tLost.isStale, isTrue);
      expect(tLost.hasSource, isFalse);
      expect(tLost.hag, isNull);

      final tRecovered = dropouts.telemetryAt(const Duration(seconds: 10));
      expect(tRecovered.isStale, isFalse);
      expect(tRecovered.hasSource, isTrue);
    });

    test('boundary_extremes scenario verifies 4-digit altitude, 3-digit speed, negative HAG', () {
      final extremes = ScenarioCatalog.boundaryExtremes;
      final high = extremes.telemetryAt(Duration.zero);
      expect(high.altitude, greaterThan(4000.0));
      expect(high.climb, greaterThan(9.0));

      final fast = extremes.telemetryAt(const Duration(seconds: 4));
      expect(fast.speed, greaterThan(100.0));

      final negHag = extremes.telemetryAt(const Duration(seconds: 8));
      expect(negHag.hag, isNotNull);
      expect(negHag.hag!, lessThan(0.0));
    });
  });
}
