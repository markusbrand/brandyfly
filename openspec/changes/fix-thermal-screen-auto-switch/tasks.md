## 1. Controller rework

- [x] 1.1 Refactor `ScreenAutoSwitchController` to level-based evaluation on every telemetry update (deferred, not dropped, when rate-limited / manual override / edit mode); verify with existing controller tests updated to expect deferred switches.
- [x] 1.2 Add lift gating for entry (`!isStale && effectiveAverageClimb > 0`); verify with tests "circling in sink does not switch" and "switches once climb turns positive".
- [x] 1.3 Add straight-flight hold so return occurs ≥ 10 s after straight flight began (detector 8 s + 2 s hold), cancelled by renewed circling; verify with tests for hold timing and cancellation.
- [x] 1.4 Ensure return target is the last pre-switch screen (glide-straight screen precedence kept) and short search turns return after the rate limit; verify with tests.

## 2. Validation

- [x] 2.1 Run `flutter analyze` and `flutter test test/services/screen_auto_switch_controller_test.dart test/integration/live_thermal_assistant_e2e_test.dart` in `apps/mobile`; all pass.
- [x] 2.2 Run `npx openspec validate --all --strict`; passes.
- [x] 2.3 Smoke test on Garuda emulator in mock flight mode: thermaling screen appears while circling in lift and the previous screen returns ~10 s after straight flight (screenshot evidence).

## Workflow follow-up

- Archive change, fill spec Purpose if needed, commit, push `fix/thermal-screen-auto-switch`, open PR with `markusbrand` account.
