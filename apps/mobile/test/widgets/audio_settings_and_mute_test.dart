import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brandyfly/models/ui_config.dart';
import 'package:brandyfly/services/audio/audio_vario_engine.dart';
import 'package:brandyfly/services/audio_vario_service.dart';
import 'package:brandyfly/services/flight_tracking_service.dart';
import 'package:brandyfly/services/screen_manager_service.dart';
import 'package:brandyfly/widgets/navigation/top_nav_bar.dart';
import 'package:brandyfly/widgets/settings/ui_settings_panel.dart';
import 'package:brandyfly_native/audio_vario_models.dart';

class TestMockEngine implements AudioVarioEngine {
  bool isStarted = false;
  bool isMuted = false;
  double volume = 0.8;
  AudioToneCommand lastCommand = AudioToneCommand.silent;

  @override
  Future<bool> start() async {
    isStarted = true;
    return true;
  }

  @override
  Future<bool> stop() async {
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
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  void dispose() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Audio Settings and Quick Mute Widget Tests', () {
    late ScreenManagerService screenManager;
    late FlightTrackingService trackingService;
    late AudioVarioService audioVarioService;
    late TestMockEngine mockEngine;

    setUp(() {
      screenManager = ScreenManagerService();
      trackingService = FlightTrackingService();
      mockEngine = TestMockEngine();
      audioVarioService = AudioVarioService(
        engine: mockEngine,
        initialSettings: trackingService.settings,
      );
      audioVarioService.attachTrackingService(trackingService);
    });

    tearDown(() {
      audioVarioService.dispose();
      trackingService.dispose();
      screenManager.dispose();
    });

    testWidgets('UISettingsPanel renders audio vario section and controls', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: UISettingsPanel(
            screenManager: screenManager,
            trackingService: trackingService,
            audioVarioService: audioVarioService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure Audio Vario section is visible
      expect(
        find.text('ACOUSTIC VARIO & SOUND SYNTHESIZER'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('setting_vario_audio_enabled')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('setting_vario_volume_slider')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('setting_vario_climb_threshold_slider')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('setting_vario_sink_threshold_slider')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('setting_vario_sniffer_enabled')),
        findsOneWidget,
      );

      // Toggle audio switch off
      await tester.tap(find.byKey(const Key('setting_vario_audio_enabled')));
      await tester.pumpAndSettle();

      expect(trackingService.settings.varioAudioEnabled, false);
      expect(audioVarioService.isMuted, true);

      // Toggle sniffer switch on
      await tester.tap(find.byKey(const Key('setting_vario_sniffer_enabled')));
      await tester.pumpAndSettle();

      expect(trackingService.settings.varioSnifferEnabled, true);
      expect(audioVarioService.config.snifferEnabled, true);
    });

    testWidgets('TopNavBarOverlay displays quick-mute button and toggles mute', (
      tester,
    ) async {
      screenManager.toggleNavBar(true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TopNavBarOverlay(
              screenManager: screenManager,
              audioVarioService: audioVarioService,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final muteBtnFinder = find.byKey(const Key('nav_btn_audio_mute'));
      expect(muteBtnFinder, findsOneWidget);
      expect(find.text('Mute Audio'), findsOneWidget);
      expect(audioVarioService.isMuted, false);

      // Tap Mute Audio
      await tester.tap(muteBtnFinder);
      await tester.pumpAndSettle();

      expect(audioVarioService.isMuted, true);
      expect(find.text('Unmute Audio'), findsOneWidget);

      // Tap Unmute Audio
      await tester.tap(muteBtnFinder);
      await tester.pumpAndSettle();

      expect(audioVarioService.isMuted, false);
      expect(find.text('Mute Audio'), findsOneWidget);
    });

    testWidgets('Floating pill nav bar displays quick-mute icon button', (
      tester,
    ) async {
      screenManager.setNavBarStyle(NavBarStyle.floatingPill);
      screenManager.toggleNavBar(true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TopNavBarOverlay(
              screenManager: screenManager,
              audioVarioService: audioVarioService,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final pillMuteFinder = find.byKey(const Key('nav_pill_btn_audio_mute'));
      expect(pillMuteFinder, findsOneWidget);

      // Tap to mute
      await tester.tap(pillMuteFinder);
      await tester.pumpAndSettle();

      expect(audioVarioService.isMuted, true);

      // Tap to unmute
      await tester.tap(pillMuteFinder);
      await tester.pumpAndSettle();

      expect(audioVarioService.isMuted, false);
    });
  });
}
