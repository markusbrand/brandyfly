import 'package:flutter_test/flutter_test.dart';
import 'package:brandyfly/services/audio/web_audio_synthesizer.dart';
import 'package:brandyfly_native/audio_vario_models.dart';

void main() {
  group('WebAudioVarioEngine Tests', () {
    late WebAudioVarioEngine engine;

    setUp(() {
      engine = WebAudioVarioEngine();
    });

    tearDown(() {
      engine.dispose();
    });

    test('Starts in unstarted state and starts successfully', () async {
      expect(engine.isRunning, false);
      final started = await engine.start();
      expect(started, true);
      expect(engine.isRunning, true);
    });

    test('Autoplay unlock activates audio generation', () async {
      engine.unlock();
      expect(engine.isUnlocked, true);

      await engine.start();
      const climbCmd = AudioToneCommand(
        state: AudioVarioToneState.climb,
        frequencyHz: 650.0,
        cadenceMs: 250,
        dutyCycle: 0.5,
        volume: 0.8,
        isMuted: false,
      );
      await engine.updateTone(climbCmd);

      expect(engine.scheduledEvents, isNotEmpty);
      final latest = engine.scheduledEvents.last;
      expect(latest.frequencyHz, 650.0);
      expect(latest.isOscillatorActive, true);
    });

    test('Sink drone mode schedules continuous tone without pulsing timer', () async {
      engine.unlock();
      await engine.start();

      const sinkCmd = AudioToneCommand(
        state: AudioVarioToneState.sink,
        frequencyHz: 260.0,
        cadenceMs: 1000,
        dutyCycle: 1.0,
        volume: 0.8,
        isMuted: false,
      );
      await engine.updateTone(sinkCmd);

      final latest = engine.scheduledEvents.last;
      expect(latest.frequencyHz, 260.0);
      expect(latest.gain, closeTo(0.64, 0.01)); // 0.8 * 0.8 = 0.64
      expect(latest.isOscillatorActive, true);
    });

    test('Muting and unmuting schedules zero gain and restores tone', () async {
      engine.unlock();
      await engine.start();

      const sinkCmd = AudioToneCommand(
        state: AudioVarioToneState.sink,
        frequencyHz: 280.0,
        cadenceMs: 1000,
        dutyCycle: 1.0,
        volume: 0.8,
        isMuted: false,
      );
      await engine.updateTone(sinkCmd);

      // Mute
      await engine.setMuted(true);
      expect(engine.scheduledEvents.last.gain, 0.0);
      expect(engine.scheduledEvents.last.isOscillatorActive, false);

      // Unmute
      await engine.setMuted(false);
      expect(engine.scheduledEvents.last.gain, greaterThan(0.0));
      expect(engine.scheduledEvents.last.isOscillatorActive, true);
    });

    test('Pause and resume lifecycle manages audio state', () async {
      engine.unlock();
      await engine.start();

      const climbCmd = AudioToneCommand(
        state: AudioVarioToneState.climb,
        frequencyHz: 800.0,
        cadenceMs: 200,
        dutyCycle: 0.5,
        volume: 0.8,
        isMuted: false,
      );
      await engine.updateTone(climbCmd);

      // Pause
      await engine.pause();
      expect(engine.isPaused, true);
      expect(engine.scheduledEvents.last.gain, 0.0);

      // Resume
      await engine.resume();
      expect(engine.isPaused, false);
      expect(engine.scheduledEvents.last.frequencyHz, 800.0);
    });

    test('Stopping silences engine and resets current command', () async {
      engine.unlock();
      await engine.start();

      const sinkCmd = AudioToneCommand(
        state: AudioVarioToneState.sink,
        frequencyHz: 220.0,
        cadenceMs: 1000,
        dutyCycle: 1.0,
        volume: 0.8,
        isMuted: false,
      );
      await engine.updateTone(sinkCmd);
      await engine.stop();

      expect(engine.isRunning, false);
      expect(engine.currentCommand, AudioToneCommand.silent);
      expect(engine.scheduledEvents.last.gain, 0.0);
    });
  });
}
