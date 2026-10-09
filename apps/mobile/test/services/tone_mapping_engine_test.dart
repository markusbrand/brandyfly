import 'package:flutter_test/flutter_test.dart';
import 'package:brandyfly/services/audio/tone_mapping_engine.dart';
import 'package:brandyfly_native/audio_vario_models.dart';

void main() {
  group('ToneMappingEngine Mathematical Mapping Tests', () {
    late ToneMappingEngine engine;

    setUp(() {
      engine = ToneMappingEngine();
    });

    test('Climb mode: weak lift at +0.2 m/s produces 450 Hz at 2 Hz cadence', () {
      final cmd = engine.evaluateVario(0.2);

      expect(cmd.state, AudioVarioToneState.climb);
      expect(cmd.frequencyHz, closeTo(450.0, 0.5));
      expect(cmd.cadenceMs, 500); // 1000 / 2.0 = 500ms
      expect(cmd.dutyCycle, closeTo(0.50, 0.01));
      expect(cmd.volume, 0.8);
      expect(cmd.isMuted, false);
    });

    test('Climb mode: strong lift at +6.0 m/s produces high frequency and 12 Hz cadence', () {
      final cmd = engine.evaluateVario(6.0);

      expect(cmd.state, AudioVarioToneState.climb);
      // 450 + (6.0 - 0.2) / 7.8 * (1800 - 450) = 450 + 5.8 / 7.8 * 1350 = 1453.8 Hz
      expect(cmd.frequencyHz, closeTo(1453.8, 1.0));
      // 1000 / 12.0 = 83ms
      expect(cmd.cadenceMs, closeTo(83, 1));
      expect(cmd.dutyCycle, closeTo(0.60, 0.01));
    });

    test('Climb mode: maximum lift at +8.0 m/s hits 1800 Hz ceiling', () {
      final cmd = engine.evaluateVario(8.0);

      expect(cmd.state, AudioVarioToneState.climb);
      expect(cmd.frequencyHz, closeTo(1800.0, 0.1));
      expect(cmd.cadenceMs, closeTo(83, 1));
      expect(cmd.dutyCycle, closeTo(0.60, 0.01));
    });

    test('Neutral deadband: 0.0 m/s produces silent state without sniffer', () {
      final cmd = engine.evaluateVario(0.0);

      expect(cmd.state, AudioVarioToneState.silent);
      expect(cmd.frequencyHz, 0.0);
      expect(cmd.dutyCycle, 0.0);
    });

    test('Sink mode: threshold at -1.5 m/s starts continuous 300 Hz drone', () {
      final cmd = engine.evaluateVario(-1.5);

      expect(cmd.state, AudioVarioToneState.sink);
      expect(cmd.frequencyHz, closeTo(300.0, 0.5));
      expect(cmd.cadenceMs, 1000);
      expect(cmd.dutyCycle, 1.0);
      expect(cmd.volume, 0.8);
    });

    test('Sink mode: heavy sink at -5.0 m/s decreases drone frequency towards 180 Hz', () {
      final cmd = engine.evaluateVario(-5.0);

      expect(cmd.state, AudioVarioToneState.sink);
      // 300 - (5.0 - 1.5) * 34.3 = 300 - 120.05 = 179.95 -> clamped to 180 Hz
      expect(cmd.frequencyHz, closeTo(180.0, 1.0));
      expect(cmd.dutyCycle, 1.0);
    });

    test('Sniffer mode: disabled by default emits silence between -0.3 and +0.1 m/s', () {
      expect(engine.config.snifferEnabled, false);
      final cmd = engine.evaluateVario(-0.1);
      expect(cmd.state, AudioVarioToneState.silent);
    });

    test('Sniffer mode: enabled produces buzzing tone with reduced volume', () {
      engine.updateConfig(engine.config.copyWith(snifferEnabled: true));

      final cmd = engine.evaluateVario(0.0);
      expect(cmd.state, AudioVarioToneState.nearThermal);
      expect(cmd.frequencyHz, greaterThanOrEqualTo(400.0));
      expect(cmd.frequencyHz, lessThanOrEqualTo(450.0));
      expect(cmd.cadenceMs, 500);
      expect(cmd.dutyCycle, closeTo(0.18, 0.01));
      // Attenuated volume: 0.8 * 0.35 = 0.28
      expect(cmd.volume, closeTo(0.28, 0.01));
    });

    test('Mute and volume controls: muting silences climb output immediately', () {
      engine.updateConfig(engine.config.copyWith(isMuted: true));
      final cmd = engine.evaluateVario(2.0);

      expect(cmd.state, AudioVarioToneState.silent);
      expect(cmd.isMuted, true);
    });

    test('Custom climb and sink thresholds modify trigger points', () {
      engine.updateConfig(engine.config.copyWith(
        climbThresholdMs: 0.5,
        sinkThresholdMs: -2.0,
      ));

      // +0.3 m/s is now below new +0.5 m/s threshold
      expect(engine.evaluateVario(0.3).state, AudioVarioToneState.silent);
      // +0.5 m/s triggers climb
      expect(engine.evaluateVario(0.5).state, AudioVarioToneState.climb);

      // -1.8 m/s is above -2.0 m/s threshold
      expect(engine.evaluateVario(-1.8).state, AudioVarioToneState.silent);
      // -2.2 m/s triggers sink
      expect(engine.evaluateVario(-2.2).state, AudioVarioToneState.sink);
    });
  });
}
