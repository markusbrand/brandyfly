import 'package:brandyfly/data/repositories/layout_repository.dart';
import 'package:brandyfly/data/services/ui_persistence_service.dart';
import 'package:brandyfly/domain/models/cockpit_telemetry.dart';
import 'package:brandyfly/domain/models/ui_config.dart';
import 'package:brandyfly/domain/thermal_assistant/thermal_assistant_engine.dart';
import 'package:brandyfly/services/screen_auto_switch_controller.dart';
import 'package:brandyfly/services/screen_manager_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

CockpitTelemetry _mode(bool circling, int rev) => CockpitTelemetry(
  hasSource: true,
  thermal: ThermalAssistantState(
    mode: circling
        ? const FlightModeState.circling(TurnDirection.right)
        : const FlightModeState.gliding(),
    revision: rev,
  ),
);

void main() {
  late ScreenManagerService screens;
  late ValueNotifier<CockpitTelemetry> telemetry;
  late ScreenAutoSwitchController controller;
  late DateTime now;
  var rev = 0;

  void circle() => telemetry.value = _mode(true, ++rev);
  void glide() => telemetry.value = _mode(false, ++rev);
  void advance(int seconds) => now = now.add(Duration(seconds: seconds));

  setUp(() {
    screens = ScreenManagerService();
    expect(screens.activeScreen.id, 'normal_flight');
    expect(
      screens.config.screens
          .firstWhere((s) => s.id == 'thermaling')
          .autoSwitchTrigger,
      ScreenAutoSwitchTrigger.onThermalCircling,
    );
    telemetry = ValueNotifier(_mode(false, rev));
    now = DateTime.utc(2026, 7, 1, 12);
    controller = ScreenAutoSwitchController(
      screens: () => screens,
      telemetry: telemetry,
      clock: () => now,
    )..start();
  });

  tearDown(() {
    controller.dispose();
    screens.dispose();
    telemetry.dispose();
  });

  test('switches to the thermal circling screen on entering a thermal', () {
    circle();
    expect(screens.activeScreen.id, 'thermaling');
    expect(screens.manualScreenChangeCount, 0, reason: 'automatic switch');
  });

  test('returns to the previous screen when gliding again', () {
    circle();
    advance(30);
    glide();
    expect(screens.activeScreen.id, 'normal_flight');
  });

  test('prefers the glide-straight screen on exit when configured', () {
    screens.setScreenAutoSwitchTrigger(
      'map_screen',
      ScreenAutoSwitchTrigger.onGlideStraight,
    );
    circle();
    advance(30);
    glide();
    expect(screens.activeScreen.id, 'map_screen');
  });

  test('manual override suppresses auto-switching for 60 s', () {
    screens.setActiveScreen('map_screen'); // manual
    circle(); // first telemetry after manual change registers the override
    expect(screens.activeScreen.id, 'map_screen');
    advance(30);
    glide();
    circle();
    expect(screens.activeScreen.id, 'map_screen');
    advance(31);
    glide();
    circle();
    expect(screens.activeScreen.id, 'thermaling');
  });

  test('no more than one automatic switch per 10 s', () {
    circle();
    expect(screens.activeScreen.id, 'thermaling');
    advance(5);
    glide();
    expect(screens.activeScreen.id, 'thermaling', reason: 'rate limited');
  });

  test('no switching while layout edit mode is active', () {
    screens.toggleEditMode(true);
    circle();
    expect(screens.activeScreen.id, 'normal_flight');
  });

  test('no configured trigger leaves the active screen unchanged', () {
    screens.setScreenAutoSwitchTrigger(
      'thermaling',
      ScreenAutoSwitchTrigger.manualOnly,
    );
    circle();
    advance(30);
    glide();
    expect(screens.activeScreen.id, 'normal_flight');
  });

  test('exit does not switch if pilot already left the thermal screen', () {
    circle();
    advance(70);
    screens.setActiveScreen('map_screen'); // manual
    advance(70);
    glide();
    expect(screens.activeScreen.id, 'map_screen');
  });

  test('automatic switches are not persisted as the start screen', () async {
    SharedPreferences.setMockInitialValues({});
    final persistence = UIPersistenceService(
      await SharedPreferences.getInstance(),
    );
    final repo = LayoutRepository(persistence: persistence);
    final persisted = ScreenManagerService(repository: repo);
    addTearDown(() {
      persisted.dispose();
      repo.dispose();
    });
    persisted.setActiveScreen('thermaling', automatic: true);
    await Future<void>.delayed(Duration.zero);
    expect(persisted.activeScreen.id, 'thermaling');
    expect(persistence.readRaw(), isNull, reason: 'nothing saved');

    persisted.setActiveScreen('map_screen'); // manual
    await Future<void>.delayed(Duration.zero);
    expect(persistence.readRaw(), contains('"activeScreenId":"map_screen"'));
  });
}
