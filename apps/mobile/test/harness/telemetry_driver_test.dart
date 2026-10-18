import 'package:flutter_test/flutter_test.dart';

import 'scenario_catalog.dart';
import 'telemetry_driver.dart';

void main() {
  group('HarnessTelemetryDriver', () {
    late HarnessTelemetryDriver driver;

    setUp(() {
      driver = HarnessTelemetryDriver();
    });

    tearDown(() {
      driver.dispose();
    });

    test('initializes with default telemetry and unattached scenario', () {
      expect(driver.currentScenario, isNull);
      expect(driver.currentElapsed, Duration.zero);
      expect(driver.reachedMilestones, isEmpty);
      expect(driver.isFinished, isFalse);
    });

    test('loads scenario and emits entry milestone', () {
      final scenario = ScenarioCatalog.steadyGlide;
      final recordedMilestones = <String>[];

      driver.addMilestoneListener((milestone, telemetry) {
        recordedMilestones.add(milestone.name);
      });

      driver.loadScenario(scenario);

      expect(driver.currentScenario?.id, 'steady_glide');
      expect(driver.currentElapsed, Duration.zero);
      expect(recordedMilestones, ['entry']);
      expect(driver.reachedMilestones.map((m) => m.name), ['entry']);
      expect(driver.currentTelemetry.speed, closeTo(39.5, 0.1));
    });

    test('stepForward advances elapsed time and fires intermediate milestones', () {
      final scenario = ScenarioCatalog.thermalClimb;
      final firedMilestones = <String>[];

      driver.addMilestoneListener((milestone, telemetry) {
        firedMilestones.add(milestone.name);
      });

      driver.loadScenario(scenario);
      expect(firedMilestones, ['entry']);

      // Advance by 8 seconds (stepSize: 2 seconds)
      for (var i = 0; i < 4; i++) {
        final hasMore = driver.stepForward(stepSize: const Duration(seconds: 2));
        expect(hasMore, isTrue);
      }

      expect(driver.currentElapsed, const Duration(seconds: 8));
      expect(firedMilestones, ['entry', 'core_peak']);
      expect(driver.currentTelemetry.thermal.isCircling, isTrue);

      // Advance to end of scenario
      while (driver.stepForward(stepSize: const Duration(seconds: 2))) {}

      expect(driver.currentElapsed, scenario.duration);
      expect(driver.isFinished, isTrue);
      expect(firedMilestones, ['entry', 'core_peak', 'exit']);
    });

    test('jumpTo jumps to specific duration and fires missed milestones', () {
      final scenario = ScenarioCatalog.heavySink;
      final firedMilestones = <String>[];

      driver.addMilestoneListener((milestone, telemetry) {
        firedMilestones.add(milestone.name);
      });

      driver.loadScenario(scenario);
      expect(firedMilestones, ['sink_entry']);

      driver.jumpTo(const Duration(seconds: 6));
      expect(driver.currentElapsed, const Duration(seconds: 6));
      expect(firedMilestones, ['sink_entry', 'maximum_sink']);

      driver.jumpTo(const Duration(seconds: 10));
      expect(firedMilestones, ['sink_entry', 'maximum_sink', 'recovery']);
    });

    test('reset clears scenario and reached milestones', () {
      driver.loadScenario(ScenarioCatalog.boundaryExtremes);
      expect(driver.reachedMilestones, isNotEmpty);

      driver.reset();
      expect(driver.currentScenario, isNull);
      expect(driver.currentElapsed, Duration.zero);
      expect(driver.reachedMilestones, isEmpty);
    });
  });
}
