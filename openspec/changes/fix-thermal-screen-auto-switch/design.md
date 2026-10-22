## Context

`ScreenAutoSwitchController` listens to `CockpitTelemetry` (≈10 Hz live, replay rate in replay) and only acts when `thermal.mode.mode` changes. Suppressions (10 s rate limit, 60 s manual override, edit mode) `return` from the transition handler, so the transition is lost. The circling detector reports gliding after the heading is stable within ±15° for 8 s; entry needs 270° within 25 s. See proposal.md – Why.

## Goals / Non-Goals

**Goals:** deterministic, testable state machine; never strand the pilot on the thermaling screen; entry requires lift; return after ~10 s straight.

**Non-Goals:** changing the circling detector constants (shared with thermal sessions/stats and the Rust core parity), new settings, periodic timers.

## Decisions

1. **Level-based evaluation on every telemetry update.** `_onTelemetry` computes the desired action from current state (`circling`, climb, `glidingSince`, `_autoSwitchedTo`) and applies it if not suppressed. Telemetry updates continuously in flight, so deferred switches fire on the next update after suppression ends (≤ 100 ms live). *Alternative:* a `Timer` re-check — rejected: adds wall-clock dependency, harder to test, and nothing changes without telemetry anyway.
2. **Entry condition:** `mode == circling && !isStale && effectiveAverageClimb > 0`. Uses the existing 20 s climb averager (`averageClimb ?? climb`), smoothing out vario gusts. Entry is only attempted while no auto-switch is active, so it fires once per thermal. *Alternative:* instantaneous climb — rejected: too noisy.
3. **Exit condition (~10 s straight):** record `glidingSince` (clock time) when mode changes to gliding; the detector has then already seen 8 s of stable heading. Exit when `now - glidingSince >= 10 s - 8 s` (constant derived from `CirclingStateDetector.glidingStabilityDurationMs`). Renewed circling clears `glidingSince`. *Alternative:* raise the detector to 10 s — rejected: changes thermal session/stats behaviour and Rust parity fixtures.
4. **Exit target:** first `onGlideStraight` screen, else remembered pre-switch screen if it still exists and is not the active thermaling screen. Unchanged precedence; default config has no glide-straight screen, so default behaviour is "return to last screen".
5. **Manual change** clears remembered/auto state (no auto-return) and starts the 60 s override. A manual change while circling disarms entry until the next gliding phase, so the pilot's choice is respected for the rest of that thermal; a manual change while gliding only defers entry until the override expires.

## Risks / Trade-offs

- [Weak/broken thermal: average climb ≤ 0 while circling] → no switch until lift is found; acceptable (pilot not yet thermaling). 
- [Clock is wall time while replay timestamps differ] → same as today; replay at accelerated speed shortens apparent hold. Acceptable; tests inject a clock.
- [Telemetry stops while on thermal screen] → engine reset publishes gliding; exit resumes once telemetry flows again.
