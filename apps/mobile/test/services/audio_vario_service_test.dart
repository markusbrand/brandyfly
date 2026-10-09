import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brandyfly/models/flight_model.dart';
import 'package:brandyfly/models/flight_settings.dart';
import 'package:brandyfly/services/audio/audio_vario_engine.dart';
import 'package:brandyfly/services/audio_vario_service.dart';
import 'package:brandyfly/services/flight_tracking_service.dart';
import 'package:brandyfly_native/audio_vario_models.dart';

class MockAudioVarioEngine implements AudioVarioEngine {
  bool isStarted = false;
  bool isStopped = false;
  bool isPaused = false;
  bool isResumed = false;
  bool isMuted = false;
  double volume = 0.8;
  AudioToneCommand lastCommand = AudioToneCommand.silent;

  @override
  Future<bool> start() async {
    isStarted = true;
    isStopped = false;
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
    lastCommand = command;
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
  Future<void> pause() async {
    isPaused = true;
  }

  @override
  Future<void> resume() async {
    isResumed = true;
  }

  @override
  void dispose() {}
}

void main() {
  group('AudioVarioService Tests', () {
    late MockAudioVarioEngine mockEngine;
    late AudioVarioService service;

    setUp(() {
      mockEngine = MockAudioVarioEngine();
      service = AudioVarioService(engine: mockEngine);
    });

    tearDown(() {
      service.dispose();
    });

    test('Initial state is not running and unmuted', () {
      expect(service.isRunning, false);
      expect(service.isMuted, false);
      expect(service.currentTone, AudioToneCommand.silent);
    });

    test('start and stop update engine and service state', () async {
      final started = await service.start();
      expect(started, true);
      expect(service.isRunning, true);
      expect(mockEngine.isStarted, true);

      final stopped = await service.stop();
      expect(stopped, true);
      expect(service.isRunning, false);
      expect(mockEngine.isStopped, true);
    });

    test('processVario maps telemetry climb to climb tone', () async {
      await service.start();

      service.processVario(1.5);

      expect(service.currentTone.state, AudioVarioToneState.climb);
      expect(service.currentTone.frequencyHz, greaterThan(450.0));
      expect(mockEngine.lastCommand.state, AudioVarioToneState.climb);
    });

    test('Watchdog auto-silences audio when telemetry stalls', () async {
      await service.start();

      service.processVario(2.0);
      expect(service.currentTone.state, AudioVarioToneState.climb);

      // Wait for watchdog timeout (250ms + margin)
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(service.currentTone.state, AudioVarioToneState.silent);
      expect(mockEngine.lastCommand.state, AudioVarioToneState.silent);
    });

    test('Mute controls toggle mute and silence engine', () async {
      await service.start();
      service.processVario(1.0);

      await service.setMuted(true);
      expect(service.isMuted, true);
      expect(mockEngine.isMuted, true);
      expect(service.currentTone.isMuted, true);

      await service.toggleMute();
      expect(service.isMuted, false);
      expect(mockEngine.isMuted, false);
    });

    test('Volume control updates master volume', () async {
      await service.start();
      await service.setVolume(0.5);

      expect(service.volume, 0.5);
      expect(mockEngine.volume, 0.5);
    });

    test('updateSettings configures audio thresholds and enable flag', () {
      const settings = FlightSettings(
        varioAudioEnabled: false,
        varioVolume: 0.6,
        varioClimbThresholdMs: 0.4,
        varioSinkThresholdMs: -2.0,
        varioSnifferEnabled: true,
      );

      service.updateSettings(settings);

      expect(service.isMuted, true);
      expect(service.volume, 0.6);
      expect(service.config.climbThresholdMs, 0.4);
      expect(service.config.sinkThresholdMs, -2.0);
      expect(service.config.snifferEnabled, true);
    });

    test('Lifecycle listener forwards pause and resume to engine', () {
      service.handleAppLifecycleState(AppLifecycleState.paused);
      expect(mockEngine.isPaused, true);

      service.handleAppLifecycleState(AppLifecycleState.resumed);
      expect(mockEngine.isResumed, true);
    });

    test('attachTrackingService receives points and drives synthesis', () async {
      await service.start();
      final tracking = FlightTrackingService();
      service.attachTrackingService(tracking);

      // Emit a flight point with climb vario
      tracking.processPoint(FlightPoint(
        timestamp: DateTime.now(),
        latitude: 47.0,
        longitude: 11.0,
        altitude: 1500,
        gnssAltitude: 1500,
        vario: 2.5,
        speed: 35.0,
        heading: 180.0,
      ));

      // Wait a tick for async stream broadcast
      await Future<void>.delayed(Duration.zero);

      expect(service.currentTone.state, AudioVarioToneState.climb);
      expect(service.currentTone.frequencyHz, greaterThan(600.0));
    });
  });
}
