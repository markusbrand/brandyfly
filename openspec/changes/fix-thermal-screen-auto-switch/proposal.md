## Why

The automatic switch back from the thermaling screen to the normal flight screen is unreliable: pilots can get stuck on the thermaling screen after leaving a thermal. The auto-switch controller only reacts to the instant of a flight-mode transition, so any transition that is suppressed (10 s rate limit, manual override window, edit mode) is lost forever. A short search turn (circling detected, then straight again after ~8 s) always hits the 10 s rate limit and never switches back. Entry also ignores lift, so circling in sink switches to the thermaling screen even though the pilot is not in a thermal.

## What Changes

- Auto-switching becomes state-based instead of edge-based: the controller continuously evaluates the desired screen and applies a switch as soon as rate limit, manual override and edit mode no longer suppress it. Suppressed switches are deferred, not dropped.
- Entering the thermaling screen requires both circling and lift (average climb > 0 m/s) on non-stale telemetry. Circling in sink no longer switches.
- Returning from the thermaling screen happens once the pilot has flown straight for about 10 s (heading stable for ≥ 10 s), to the last active flight screen before the automatic switch (never the thermaling screen itself). An explicitly configured glide-straight screen keeps precedence, as today.
- Renewed circling during the straight-flight hold cancels the pending return.

## Non-goals

- No change to the circling detector (270° / 25 s entry, ±15° / 8 s gliding) or to thermal assistant sessions, stats, or Rust flight core.
- No new user settings (thresholds remain constants).
- No change to manual screen selection, persistence of the start screen, or the 60 s manual override duration.

## Capabilities

### New Capabilities

### Modified Capabilities
- `screen-widget-configuration`: auto-switching entry requires lift, return happens after ~10 s straight flight, and suppressed switches are deferred instead of dropped.

## Impact

- Code: `apps/mobile/lib/services/screen_auto_switch_controller.dart`, tests in `apps/mobile/test/services/screen_auto_switch_controller_test.dart`.
- Safety: reduces pilot distraction (no stuck thermal screen, no false switches in sink). Purely UI-level; vario audio and sensor paths are untouched.
- Offline/privacy/licensing: none.
