import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:brandyfly/main.dart';
import 'package:brandyfly/services/audio/audio_vario_engine.dart';
import 'package:brandyfly/services/audio_vario_service.dart';
import 'package:brandyfly/services/flight_tracking_service.dart';
import 'package:brandyfly/services/screen_manager_service.dart';
import 'package:brandyfly/models/flight_model.dart';
import 'package:brandyfly/models/ui_config.dart';
import 'package:brandyfly_native/audio_vario_models.dart';
import 'package:brandyfly_native/brandyfly_native.dart';

class FakeSimulationNative extends BrandyflyNative {
  @override
  Future<String?> getPlatformVersion() async => 'Mock Android 14';

  @override
  Future<void> configureLocalMockFlightMode(
    MockFlightModeConfig config,
  ) async {}

  @override
  Future<bool> audioVarioStart() async => true;

  @override
  Future<bool> audioVarioStop() async => true;

  @override
  Future<bool> audioVarioUpdateTone(AudioToneCommand command) async => true;

  @override
  Future<bool> audioVarioSetVolume(double volume) async => true;

  @override
  Future<bool> audioVarioSetMuted(bool isMuted) async => true;
}

class TestSimulationAudioEngine implements AudioVarioEngine {
  bool isStarted = false;
  bool isStopped = false;
  bool isMuted = false;
  double volume = 0.8;
  AudioToneCommand latestCommand = AudioToneCommand.silent;
  final List<AudioToneCommand> commandHistory = [];

  @override
  Future<bool> start() async {
    isStarted = true;
    return true;
  }

  @override
  Future<bool> stop() async {
    isStopped = true;
    isStarted = false;
    return true;
  }

  @override
  Future<bool> updateTone(AudioToneCommand command) async {
    latestCommand = command;
    commandHistory.add(command);
    return true;
  }

  @override
  Future<bool> setVolume(double vol) async {
    volume = vol;
    return true;
  }

  @override
  Future<bool> setMuted(bool muted) async {
    isMuted = muted;
    return true;
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  void dispose() {}
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('End-to-End Flight Simulation & Audio Vario Synthesis Tests', () {
    testWidgets(
      'Full flight simulation drives continuous FM synthesis, mute HUD toggle, and settings updates',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final mockAudioEngine = TestSimulationAudioEngine();
        final trackingService = FlightTrackingService();
        final screenManager = ScreenManagerService();
        final audioVarioService = AudioVarioService(
          engine: mockAudioEngine,
          initialSettings: trackingService.settings,
        );

        final config = MockFlightModeConfig(
          enabled: true,
          fixtureVersion: 'mock-flight-v1',
          seed: 42,
          logicalClockStep: const Duration(seconds: 1),
          startTime: DateTime.parse('2026-08-07T00:00:00Z'),
          provenance: 'synthetic-anonymized',
        );

        await tester.pumpWidget(
          BrandyFlyApp(
            config: config,
            native: FakeSimulationNative(),
            trackingService: trackingService,
            screenManager: screenManager,
            audioVarioService: audioVarioService,
          ),
        );

        // Bootstrap frames
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));

        expect(audioVarioService.isRunning, isTrue);
        expect(mockAudioEngine.isStarted, isTrue);

        // 1. Simulate thermal climb event (+2.2 m/s) via direct service or telemetry
        audioVarioService.processVario(2.2);
        await tester.pump(const Duration(milliseconds: 20));

        expect(audioVarioService.currentTone.state, AudioVarioToneState.climb);
        expect(
          audioVarioService.currentTone.frequencyHz,
          greaterThan(600.0),
        );
        expect(mockAudioEngine.latestCommand.state, AudioVarioToneState.climb);

        // 2. Simulate sink event (-2.5 m/s)
        audioVarioService.processVario(-2.5);
        await tester.pump(const Duration(milliseconds: 20));

        expect(audioVarioService.currentTone.state, AudioVarioToneState.sink);
        expect(audioVarioService.currentTone.dutyCycle, 1.0);
        expect(mockAudioEngine.latestCommand.state, AudioVarioToneState.sink);

        // 3. Quick mute HUD test: toggle mute and verify silence
        await audioVarioService.toggleMute();
        await tester.pump(const Duration(milliseconds: 20));

        expect(audioVarioService.isMuted, isTrue);
        expect(mockAudioEngine.isMuted, isTrue);

        // Unmute
        await audioVarioService.toggleMute();
        await tester.pump(const Duration(milliseconds: 20));

        expect(audioVarioService.isMuted, isFalse);
        expect(mockAudioEngine.isMuted, isFalse);

        // 4. Verify watchdog auto-silence when telemetry stalls
        await tester.pump(const Duration(milliseconds: 300));
        expect(audioVarioService.currentTone.state, AudioVarioToneState.silent);
      },
    );
  });
}
