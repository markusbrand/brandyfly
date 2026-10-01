# Verification notes: granular-widgets-and-map-controls

## Automated results (branch `feature/granular-widgets-and-map-controls`)

| Check | Result |
|---|---|
| `flutter analyze` | No issues (baseline also clean) |
| `flutter test` | 380 passed, 1 skipped (opt-in screenshot capture); baseline was 217 |
| Overflow sweep (`test/layout/overflow_sweep_test.dart`) | 13 widget types x all styles x min / default / presets / full x 390x844, 844x390, 1280x800 x flight / edit: no layout exceptions |
| Rebuild budget (`test/perf/rebuild_budget_test.dart`) | Canvas 0 rebuilds per telemetry tick; altitude-only tick rebuilds only altitude consumers; inspector 0 rebuilds during 50 ticks; mean tick < 16 ms with 10 widgets |
| `integration_test/app_walkthrough_test.dart` on Linux desktop | 3/3 window sizes passed (headless MapLibre surface; MapLibre has no Linux implementation) |
| Same walkthrough on Android emulator (`brandyfly_test_device`, real MapLibre native renderer) | 3/3 window sizes passed |
| Same walkthrough on Android in airplane mode (offline) | Phone portrait passed; tile server falls back to bundled overview PMTiles |
| Playwright web smoke (`test_e2e/playwright_verification.mjs`) | Passed on 390x844 and 1280x800, no page errors |
| `npx openspec validate --all --strict` | Valid |

## Manual / visual review

- Screenshots (`test/visual/screenshot_review_test.dart`, `SCREENSHOTS=1`) of the default screens in flight and edit mode at three sizes; an Android emulator screenshot of the live map. Both reviewed.
- Change from review: the edit dock covered 40-70 % of the canvas, including the selected widget. Fixed with a tabbed inspector, a side dock on wide canvases and a top-docked inspector for lower-half selections (spec deltas and design updated).

## Defects found by the new tests and fixed

1. Vario bar `analogDial` and `screenEdgeGlow` overflowed at 1x4 in landscape (label wrapped to 2 lines). Found by the overflow sweep.
2. Widget config sheet rows overflowed on narrow dialogs. Found by the map control widget tests.
3. `MapLibreMapService` notified listeners after dispose when style building finished late (fast screen switches). Found by the screenshot test.
4. The simulation card covered the side-docked inspector in landscape edit mode; it now hides during edit mode. Found by the integration test on Linux.
5. The simulation card was unmounted whenever the nav overlay opened, losing its minimized state and position and re-covering placed controls. Now kept mounted and hidden. Found by the integration test on Android.
6. The web build crashed at startup because `LocalTileServer` created a `dart:io` `HttpClient` eagerly. This bug predates the change (confirmed by building the base commit). Fixed with lazy creation and a web guard in `buildStyleJson`; the map widget skips the native map when maplibre-gl JS is not loaded.

## Known limitations / not covered

- No real phone or tablet hardware was used; only the emulator and desktop. Per project guidance, no hardware support claim is made.
- The web build has no maplibre-gl JS in `web/index.html`, so web shows overlays on a plain background. Adding it would introduce a CDN dependency that needs a separate offline/licensing review.
- The thermal map's pulse animation runs continuously (unchanged by this change). It is isolated in a RepaintBoundary but keeps scheduling frames.
- The mock-mode "Show Map" FAB overlaps the built-in zoom buttons on the normal flight screen (unchanged by this change; debug builds only).
