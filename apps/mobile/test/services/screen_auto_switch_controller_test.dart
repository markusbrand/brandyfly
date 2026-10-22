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

CockpitTelemetry _mode(
  bool circling,
  int rev, {
  double averageClimb = 1.5,
  bool stale = false,
}) => CockpitTelemetry(
  hasSource: true,
  averageClimb: averageClimb,
  isStale: stale,
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

  void circle({double climb = 1.5, bool stale = false}) =>
      telemetry.value = _mode(true, ++rev, averageClimb: climb, stale: stale);
  void glide() => telemetry.value = _mode(false, ++rev);
  void advance(int seconds) => now = now.add(Duration(seconds: seconds));

  /// Glides for [seconds] with 1 Hz telemetry updates (first update at t=0).
  void glideFor(int seconds) {
    glide();
    for (var i = 0; i < seconds; i++) {
      advance(1);
      glide();
    }
  }

  /// Circles for [seconds] with 1 Hz telemetry updates.
  void circleFor(int seconds, {double climb = 1.5}) {
    circle(climb: climb);
    for (var i = 0; i < seconds; i++) {
      advance(1);
      circle(climb: climb);
    }
  }

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

  test('returns to the previous screen after ~10 s of straight flight', () {
    circle();
    advance(30);
    // The detector reports gliding after 8 s of stable heading; the
    // controller holds a further 2 s.
    glideFor(1);
    expect(screens.activeScreen.id, 'thermaling', reason: 'hold not elapsed');
    advance(1);
    glide();
    expect(screens.activeScreen.id, 'normal_flight');
  });

  test('returns to the last active screen, not a fixed one', () {
    screens.setActiveScreen('map_screen'); // manual
    glide(); // registers the override
    advance(61);
    circle();
    expect(screens.activeScreen.id, 'thermaling');
    advance(30);
    glideFor(2);
    expect(screens.activeScreen.id, 'map_screen');
  });

  test('renewed circling cancels the pending return', () {
    circle();
    advance(30);
    glideFor(1);
    circleFor(5);
    expect(screens.activeScreen.id, 'thermaling');
    glideFor(1);
    expect(screens.activeScreen.id, 'thermaling', reason: 'hold restarted');
    advance(1);
    glide();
    expect(screens.activeScreen.id, 'normal_flight');
  });

  test('circling in sink does not switch until lift is found', () {
    circleFor(10, climb: -0.8);
    expect(screens.activeScreen.id, 'normal_flight');
    circle(climb: 0.0);
    expect(screens.activeScreen.id, 'normal_flight');
    circle(climb: 0.4);
    expect(screens.activeScreen.id, 'thermaling');
  });

  test('stale telemetry does not trigger the thermal screen', () {
    circle(stale: true);
    expect(screens.activeScreen.id, 'normal_flight');
    circle();
    expect(screens.activeScreen.id, 'thermaling');
  });

  test('switches only once per circling phase', () {
    circle();
    advance(70);
    screens.setActiveScreen('normal_flight'); // manual, still circling
    circleFor(70);
    expect(
      screens.activeScreen.id,
      'normal_flight',
      reason: 'pilot choice respected for this thermal',
    );
    glideFor(15);
    circle();
    expect(screens.activeScreen.id, 'thermaling', reason: 'next thermal');
  });

  test('prefers the glide-straight screen on exit when configured', () {
    screens.setScreenAutoSwitchTrigger(
      'map_screen',
      ScreenAutoSwitchTrigger.onGlideStraight,
    );
    circle();
    advance(30);
    glideFor(2);
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
    circle();
    expect(screens.activeScreen.id, 'thermaling', reason: 'deferred entry');
  });

  test('rate-limited return is deferred, not dropped (short search turn)', () {
    circle();
    expect(screens.activeScreen.id, 'thermaling');
    advance(5);
    glideFor(3);
    expect(screens.activeScreen.id, 'thermaling', reason: 'rate limited');
    advance(2); // 10 s since the automatic switch
    glide();
    expect(screens.activeScreen.id, 'normal_flight');
  });

  test('no switching while layout edit mode is active', () {
    screens.toggleEditMode(true);
    circle();
    expect(screens.activeScreen.id, 'normal_flight');
    screens.toggleEditMode(false);
    circle();
    expect(screens.activeScreen.id, 'thermaling', reason: 'deferred');
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
    glideFor(15);
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
