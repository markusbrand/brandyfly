## 1. Setup and baseline

- [x] 1.1 Confirm branch `feature/granular-widgets-and-map-controls` is checked out and record baseline: `flutter test` passes (217 tests) and `flutter analyze` output saved to compare later
- [x] 1.2 Add `provider` dependency and `integration_test` (sdk) dev dependency to `apps/mobile/pubspec.yaml`; verify `flutter pub get` succeeds and `flutter analyze` shows no new issues
- [x] 1.3 Bundle Barlow Semi Condensed Medium and Bold (OFL) under `assets/fonts/`, register in pubspec, add license entry to `THIRD_PARTY_DATA.md`; verify a widget test renders text with the family without missing-font warnings
- [x] 1.4 Create `lib/data`, `lib/domain`, `lib/ui/core`, `lib/ui/features/{flight_canvas,layout_editor,map,instruments}` skeletons; verify `flutter analyze` passes

## 2. Domain models, catalog and rules

- [x] 2.1 Implement `GridSpec` (16x32), `WidgetPlacement`, `ScreenLayouts` (tall + optional wide), `FlightScreen`, `UIConfig.schemaVersion`, new `WidgetType`s (`mapZoomIn`, `mapZoomOut`, `mapZoomRocker`, `mapRecenter`), `mapControlTarget`, `mapBuiltInControls`, with JSON round-trip and unknown-type skipping; verify with unit tests in `test/domain/models_test.dart`
- [x] 2.2 Implement `WidgetCatalog` (min, default, S/M/L/Full presets, interactive flag) for every `WidgetType`; verify a completeness test fails if any type lacks a spec
- [x] 2.3 Implement `LayoutEditor` use case (move, nudge, resize, drag-resize deltas, presets, clamp, 48 dp interactive minimum from cell size, add-at-first-free-slot, reorder, remove, copy tall to wide); verify `test/domain/layout_editor_test.dart` covers bounds, minimums, preset edge shifting and no-op detection
- [x] 2.4 Implement `AlignmentDetector` (edge/center guides, overlap rects excluding full-canvas background maps); verify unit tests for edge, center and overlap cases
- [x] 2.5 Implement `LayoutMigrator` v1 to v2 to v3 with proportional row mapping and clamping; verify unit tests on all default screens, the 4-column legacy fixture, the 8-column fixtures with `R` = 8 and `R` = 12, and a fuzz test (500 random layouts) that all outputs are within bounds and minimums

## 3. Data layer

- [x] 3.1 Move `UIPersistenceService` to `lib/data/services/` with a re-export shim; add backup slot read/write; verify `test/ui_persistence_service_test.dart` passes against the new path
- [x] 3.2 Implement `LayoutRepository` (load + migrate + backup + save, in-memory change kept on write failure, ChangeNotifier of `UIConfig`); verify `test/data/layout_repository_test.dart` with in-memory storage covers migration, corrupted payload fallback and write failure
- [x] 3.3 Implement `TelemetrySnapshot` and `TelemetryRepository` wrapping synthetic, replay and native sources into a `ValueListenable<TelemetrySnapshot>` including stale flags; verify unit tests show one notification per source tick and replay determinism unchanged (`test/flight_replay_service_test.dart`, `test/igc_replay_telemetry_source_test.dart` still pass)

## 4. View models and dependency injection

- [x] 4.1 Implement `FlightCanvasViewModel` (active screen, variant selection by canvas shape, built-in map controls visibility derivation); verify unit tests for tall, wide, wide-missing fallback and Auto/Always/Never visibility
- [x] 4.2 Implement `EditModeViewModel` (selection, edited variant, commands delegating to `LayoutEditor`, one notify per effective change); verify unit tests for every command including no-op silence
- [x] 4.3 Refactor `ScreenManagerService` into a facade over repository and view models keeping its public API; verify `test/screen_manager_test.dart` and `test/models/ui_config_test.dart` pass (updated only for 16x32 bounds)
- [x] 4.4 Wire `MultiProvider` at app root in `main.dart`, remove app-level 2 s `setState` in favor of `TelemetryRepository`; verify `test/app_test.dart` and `test/telemetry_provider_lifecycle_test.dart` pass with injected fakes

## 5. Responsive flight canvas and layout-error fixes

- [x] 5.1 Implement `LayoutCanvas` (fixed-size Stack, no scroll, `LayoutBuilder` geometry, zero/unbounded constraint fallback) with `StrategyBackdrop` for the three strategies replacing the three duplicate builders; verify widget tests for each strategy, no `Scrollable` in the flight canvas, and zero/unbounded constraints
- [x] 5.2 Implement `GridGuidePainter` (grid, alignment guides, overlap fill in one painter, `shouldRepaint` on geometry/guides only); verify a painter test and that guides are absent outside edit mode
- [x] 5.3 Implement `SizeTier` and `WidgetSlot` (computes tier, wraps content in `RepaintBoundary`); make numeric, vario bar, wind, sparkline and thermal map tier-aware, keeping `FittedBox` only on value digits; verify `test/instrument_widgets_test.dart` plus new tier tests (tiny shows value only)
- [x] 5.4 Replace whole-bar `FittedBox` usage in edit toolbar, inspector, edit frame and `main.dart` overlay with `Flexible`/`Expanded`/`Wrap` and icon-only collapse; verify tests at 320 dp width show no exception and all controls >= 48x48 dp
- [x] 5.5 Add overflow sweep `test/layout/overflow_sweep_test.dart` (type x style x min/presets/full x 390x844, 844x390, 1280x800 x flight/edit-selected); verify zero layout exceptions

## 6. Field-scoped telemetry rendering

- [x] 6.1 Implement `TelemetrySelector<T>` and connect every instrument and the map legend through it; verify unit test that selector rebuilds only on selected-value change
- [x] 6.2 Add `test/perf/rebuild_budget_test.dart` asserting the spec budgets (altitude-only change, 100 ticks / 10 widgets, 50 ticks during editing with inspector); verify it passes and extend `test/telemetry_latency_and_perf_test.dart` to confirm no latency regression vs baseline

## 7. Map camera view model and map control widgets

- [x] 7.1 Implement `MapCameraViewModel` (zoom, limits, center-lock, 6 s timer, `zoomBy`, `recenter`, dispose-safe) and refactor `MapWidget` and its built-in buttons to use it; verify `test/map_widget_integration_test.dart` passes and `fakeAsync` tests cover timer, limits and dispose
- [x] 7.2 Implement `MapCameraScope` registry (register/unregister per map id and variant, Auto resolution to bottom-most map); verify unit tests for single map, multiple maps, removed target
- [x] 7.3 Implement `BezelButton` core widget and map control widgets (zoom in, zoom out, rocker with shape-based orientation and zoom readout, recenter with lit state, dimmed no-map state); verify widget tests with fake `MapLibreMapService` for parity with built-in buttons, state feedback, limits and missing target
- [x] 7.4 Add built-in controls setting (Auto/Always/Never) and target picker (Auto, map list, "Missing map") to the widget config sheet; verify widget tests for visibility toggling when adding/removing a control and for the missing-target option
- [x] 7.5 Register map control types in widget picker (foreground placement, catalog default size, 48 dp clamp); verify picker test adds each control type

## 8. Editing UX

- [x] 8.1 Replace edit-frame header with selection overlay (outline, outside corner handle, size/tier tag) and drag-resize via `LayoutEditor`; verify widget tests on 1x1 and full-size widgets with no overflow and correct snapping
- [x] 8.2 Rebuild inspector panel (presets, nudge/steppers, layers, configure, remove, "Fix size", tier display, max width 560 dp on > 840 dp canvases); verify existing inspector tests (updated keys) and new preset/fix-size tests
- [x] 8.3 Add Tall/Wide segmented control, "Copy from Tall", delete wide, letterboxed preview of non-matching variant; verify widget tests for create/edit/delete variant and independence of variants
- [x] 8.4 Wire alignment guides and overlap highlights during drag; verify widget test that guides appear on alignment and vanish on release
- [x] 8.5 Apply `CockpitTokens` and Barlow tabular figures to flight canvas, instruments, edit chrome and map controls; respect `disableAnimations`; verify widget test that edit transitions are skipped with animations disabled and visual review screenshots at three canvas sizes

## 9. Test suite migration and full-app verification

- [x] 9.1 Update existing tests that assume 8-column bounds or the removed edit-frame header (`test/widgets_test.dart`, `test/layout_resilience_and_a11y_test.dart`, `test/widgets/top_nav_bar_test.dart`, etc.); verify the full `flutter test` suite passes
- [x] 9.2 Add `integration_test/app_walkthrough_test.dart` (nav overlay, screen switch, edit mode, add every widget type, resize, preset, configure, wide variant, done, replay start, map controls) parameterized for 390x844, 844x390, 1280x800; verify `flutter test integration_test -d linux` passes with no reported Flutter errors
- [x] 9.3 Extend `test_e2e/playwright_verification.mjs` for the web build (canvas renders, edit mode, map control press); verify the Playwright run passes
- [x] 9.4 Manually smoke-test on an Android emulator or device in portrait and landscape (flight, edit, replay, offline); record findings in the change verification notes
- [x] 9.5 Run `flutter analyze` (no new issues vs baseline), full `flutter test`, and `npx openspec validate --all --strict`; verify all pass before archive
