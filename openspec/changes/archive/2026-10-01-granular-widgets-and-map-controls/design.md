## Context

See proposal.md for motivation. Current state relevant to the approach:

- `ScreenManagerService` (a `ChangeNotifier`) owns screen state, edit-mode state, layout clamping and persistence calls. The 8-column limit is written out as a literal number in about 15 places across the service, the edit frame, the inspector and the config dialog.
- `LayoutStrategyContainer` contains three near-identical layout builders and wraps the canvas in `SingleChildScrollView`. Cell height is `height / max(maxBottomGrid, 8)`.
- `main.dart` builds an untyped `Map<String, dynamic>` telemetry object per build, and a 2 s `Timer.periodic` calls `setState` at app level. Every tick rebuilds the canvas, all instruments and the edit chrome.
- The `MapWidget` state holds zoom, center-lock and the 6 s recenter timer privately. Its built-in buttons are 28 dp.
- Toolbars, the inspector and the edit-frame header use `FittedBox` to hide overflow.
- Four in-flight OpenSpec changes touch `services/`, so a full folder move would cause conflicts.
- Baseline: 217 passing tests, many tied to 8-column bounds and keys such as `btn_map_zoom_in`.

Guidance applied: Flutter architecture (layered MVVM, repositories, DI), Flutter responsive layout (decide from `LayoutBuilder` constraints, never from orientation or device type, don't lock orientation), Flutter layout-issue resolution (fix overflow with `Flexible`, `Expanded` and `Wrap`, not by scaling), and frontend-design for visual direction. React-specific rules (bundling, SSR, Suspense) do not apply to Flutter. Their re-render principles map onto field-scoped listenables and are covered there.

## Goals / Non-Goals

**Goals:**
- One set of pure layout rules used by every editing path.
- The canvas never scrolls, and layout is decided only from canvas constraints.
- Telemetry updates cost no more than today, with fewer rebuilds, proven by a rebuild-count test.
- Map controls are decoupled from the map widget through a per-map camera view model.
- Automated coverage for layout errors and an end-to-end walkthrough.

**Non-Goals (design-level):**
- No state-management framework beyond `ChangeNotifier`/`ValueNotifier` plus `provider` (no Bloc, Riverpod or get_it).
- No moving of modules not touched by this change.
- No redesign of the settings, flights or logbook screens. They only get theme tokens where shared widgets are reused.

## Decisions

### D1. Layered slices for the touched features

```
lib/
  data/
    services/      ui_persistence_service.dart (moved), maplibre_map_service.dart (moved, re-exported from old path)
    repositories/  layout_repository.dart, telemetry_repository.dart
  domain/
    models/        grid_spec.dart, widget_type.dart, ui_config.dart (placements, screens, config),
                   widget_catalog.dart, size_tier.dart, cockpit_telemetry.dart
    use_cases/     layout_editor.dart, layout_migrator.dart, alignment_detector.dart,
                   map_control_resolver.dart
  ui/
    core/          theme/cockpit_tokens.dart, bezel_button.dart, size_tier.dart
    features/
      flight_canvas/  view_models/flight_canvas_view_model.dart  views/layout_canvas.dart, widget_slot.dart, strategy_backdrop.dart, grid_guide_painter.dart
      layout_editor/  view_models/edit_mode_view_model.dart     views/inspector_panel.dart, edit_frame.dart, edit_toolbar.dart, widget_picker_sheet.dart, widget_config_sheet.dart
      map/            view_models/map_camera_view_model.dart (incl. MapCameraRegistry, MapCameraScope)  views/map_widget.dart, map_control_widgets.dart  platform/map_renderer_availability*.dart
      instruments/    views/* (moved instrument widgets, made tier-aware)
```

- **Moved files leave re-exports.** The old paths (`models/ui_config.dart`, `services/screen_manager_service.dart`, `widgets/flight/map_widget.dart`) re-export the new ones for one release, so other changes and tests keep compiling. Tests are updated to the new paths during this change.
- **`ScreenManagerService` becomes a facade** over `LayoutRepository`, `EditModeViewModel` and `FlightCanvasViewModel`, keeping its public API so the nav bar, settings and auto-switch code keep working. Callers move over gradually.
- **Alternative rejected: restructure the whole app now.** It conflicts with four in-flight changes and gives this feature no extra value.
- **Alternative rejected: keep the current layout.** Rules would stay duplicated across UI files and the map controls would have no clean home.

### D2. Domain models, hand-written and immutable

- **No `freezed`.** Code generation would add `build_runner` and regenerate every model, which is a lot of churn. The existing models already have `copyWith` and JSON support.
- **New fields:** `FlightScreenModel.widgets` stays the tall layout and gains an optional `wideWidgets` list (with `widgetsFor(variant)` falling back to tall), plus `UIConfig.schemaVersion = 3` (4-column = 1, 8-column = 2). The existing class names (`WidgetPlacementModel`, `FlightScreenModel`, `UIConfig`) are kept to avoid churn for other changes.
- **Widget config in JSON:** `WidgetPlacement` gains `mapControlTarget` (`auto` or a widget id) and `mapBuiltInControls` (`auto` | `always` | `never`).
- **Four new `WidgetType` values:** `mapZoomIn`, `mapZoomOut`, `mapZoomRocker`, `mapRecenter`.
- **Unknown widget types** in stored JSON are skipped with a log entry, not a crash. This keeps the stored config readable by older versions.

### D3. Grid geometry: fixed 16x32, stretched, with a wide variant (G3)

- **Cell size:** `cellW = canvasW / 16`, `cellH = canvasH / 32`. The canvas is a fixed-size `Stack` with no scroll view, and `LayoutBuilder` provides the constraints.
- **Choosing the variant:** a canvas with `maxWidth > maxHeight` uses the wide variant if one exists; otherwise the tall variant is stretched. This deliberately uses canvas aspect ratio rather than a 600 dp width breakpoint. A phone in landscape (844x390) and a tablet in portrait (800x1280) are both over 600 dp wide but need opposite layouts, and canvas aspect ratio is still "available space", in line with the responsive-layout guidance. No orientation APIs are used.
- **Alternatives considered:**

  | Option | Why rejected |
  |---|---|
  | G1, stretched only | Landscape cells become about 12 dp tall, leaving instruments unusable |
  | G2, square cells | Requires scrolling in flight, which is unsafe |
  | Width breakpoint | Misclassifies the cases above |
  | More than 2 variants | Adds editing burden for little gain; can be added later because the model is a variant map |

- **Platform trade-offs:** none. The approach is pure layout and renders the same on Android and iOS.

### D4. Migration (in `LayoutMigrator`, run by `LayoutRepository.load`)

- **v1 (4-col) to v2:** multiply x, y, w and h by 2 (existing behavior).
- **v2 (8-col) to v3:**
  - `R = max(8, max(y + h))`.
  - `x' = 2x`, `w' = 2w`.
  - `y' = round(y * 32 / R)`, `bottom' = round((y + h) * 32 / R)`, `h' = max(1, bottom' - y')`.
  - Clamp to catalog minimums and grid bounds.
  - All existing widgets go into the `tall` variant.
- **Backup:** the original payload is written to `ui_config_backup_v<n>` before the first save at v3.
- **Failure:** any exception during parsing or migration means defaults are loaded, the backup is kept, and an error is logged. The flight view stays usable.
- **Rollback:** an older app build sees `schemaVersion: 3` with an unknown shape and falls back to defaults (existing try/catch behavior). The backup key lets a future build restore the old layout. This is documented in the release notes.

### D5. Widget catalog and size tiers

- **The catalog is a `const Map<WidgetType, WidgetSpec>`** holding `minSize`, `defaultSize`, `presets {S, M, L, Full}` and `interactive: bool`.
- **Example sizes:**
  - Numeric: min 1x1, default 4x3.
  - Vario bar: min 1x4.
  - Map: min 4x4, default 16x32.
  - Map controls: min 2x2, `interactive: true`.
- **The 48 dp check is dynamic.** `LayoutEditor` receives the current cell size in dp, works out how many cells reach 48 dp, and uses the larger of that and `minSize` when clamping interactive widgets.
- **`SizeTier`** is picked from the shortest rendered side: tiny under 40 dp, compact under 80 dp, otherwise regular. A `LayoutBuilder` at the slot level computes it and hands it to instruments as a plain value, so instruments don't each need their own `LayoutBuilder`.
- **`FittedBox` stays only around value digits**, where scaling is intended.

### D6. Telemetry: typed snapshot plus field-scoped listenables

- **`TelemetryRepository`** wraps the existing sources (synthetic, replay, native) and exposes a `ValueListenable<TelemetrySnapshot>`. It replaces the `Map<String, dynamic>`.
- **Field selection:** instruments subscribe through a small generic `ValueSelector<CockpitTelemetry, T>(select: ...)` that rebuilds only when the selected value changes. Values are selected as rounded integers at display precision (e.g. `(speed * 10).round()`), so a tick neither allocates strings nor rebuilds unchanged widgets. The UI snapshot is named `CockpitTelemetry` because `TelemetrySnapshot` already exists as the sensor-level type.
- **History sampling:** the live altitude history is sampled at most once per second, so a 10-50 Hz source does not allocate a new history list on every tick.
- **Removed app-level rebuild:** the app-level 2 s `setState` for mock replay goes; the repository pushes snapshots instead.
- **Alternatives rejected:**
  - `Selector` from `provider` per widget: works, but needs a provider per snapshot, and a hand-written selector on a `ValueListenable` is simpler and allocation-free.
  - Streams with `StreamBuilder`: adds async-gap jank and allocation.
- **Performance and battery:** fewer widget rebuilds per tick. One snapshot object is allocated per tick, replacing the current per-build map and list. The sensor and audio paths are untouched.

### D7. Map camera view model and controls

- **`MapCameraViewModel`** (one per map widget instance):
  - Owns `zoom`, `centerLocked`, `minZoom`/`maxZoom` and the 6 s recenter timer.
  - Exposes `zoomBy(delta)` and `recenter()` commands.
  - `MapWidget` drives the camera from it and reports gestures to it.
  - The built-in buttons use the same commands, so behavior is identical by construction.
- **`MapCameraScope`** is an `InheritedNotifier` at canvas level, holding a lookup from map widget id to camera view model per variant.
  - A map registers on mount and unregisters on dispose.
  - Controls resolve their target as an explicit id, or Auto, meaning the lowest map in the stack.
  - Controls listen to the resolved view model only.
  - If no target is found, the control shows a dimmed state and does nothing.
- **Built-in controls on Auto** are hidden when the scope reports at least one control resolving to this map, computed in `FlightCanvasViewModel` from the placements without any widget lookups.
- **Alternatives rejected:**
  - A global singleton controller: breaks with multiple maps and with tests.
  - Callbacks passed through the layout: tight coupling and rebuild churn.
  - Controls as overlays rendered inside the map: still not freely placeable.
- **Persistence:** in-flight zoom from controls is not saved, matching the current behavior where only the config dialog sets the initial zoom.

### D8. Editing UX

- **Edit chrome is drawn above the widgets** in an overlay layer of the canvas. It includes the selection outline, corner handle and a size tag (`ALT 3x2 - compact`). Small widgets therefore never contain controls.
- **The edit-frame header is replaced** by the selection overlay plus the inspector.
- **The inspector** reflows with `Wrap` and goes icon-only below 360 dp (icons keep tooltips and 48 dp targets). Below 600 dp of panel width it shows one control group at a time behind Size / Resize / Move / Layer tabs, which keeps the dock about 150 dp tall instead of three rows of buttons.
- **Dock placement** (added after the screenshot review showed the dock covering 40-70 % of the canvas, including the selected widget): on wide canvases of at least 600 dp the inspector and toolbar form a side panel (at most 560 dp) on the side away from the selected widget. On tall canvases the toolbar stays at the bottom and the inspector sits above it, or moves to the top edge when the selected widget's center is in the lower half.
  - Sections: Size presets (S/M/L/Full), nudge and steppers, layers, Configure, Remove.
  - A "Fix size" action appears for interactive widgets below 48 dp.
- **Toolbar:** Add, Layers, a Tall/Wide segmented control, and Done.
  - Selecting Wide when no wide variant exists prompts "Copy from Tall".
  - Editing the variant that doesn't match the current canvas shape shows a letterboxed 16:9 or 9:16 preview.
- **Alignment and overlap:** `AlignmentDetector` (domain) returns guide lines and overlap rectangles in grid units, and `GridGuidePainter` paints grid guides, alignment guides and overlap fills in one `CustomPainter`.
  - It repaints when size, geometry or guides change.
  - Alignment guides and overlap fills update on drag, not on telemetry.

### D9. Visual direction (frontend-design)

- **Subject:** a glanceable cockpit for paraglider pilots in sunlight and wearing gloves.
- **Tokens (`CockpitTokens`):**

  | Token | Hex | Role |
  |---|---|---|
  | night panel | `#0B0F14` | Background |
  | bezel | `#1C232B` | Control surfaces |
  | glass cyan | `#3FE0F0` | Active and selected |
  | lift green | `#3DDC84` | Climb |
  | sink red | `#FF4D5E` | Sink |
  | caution amber | `#FFB020` | Stale data, warnings, overlap |

- **Type:**
  - Barlow Semi Condensed (SIL OFL 1.1, bundled) for labels and values, with tabular figures (`FontFeature.tabularFigures()`) so digits don't jitter.
  - The system font stays for settings, the flights screen and dialogs.
- **Signature element: map controls styled as bezel keys.** A 2 dp outer bezel and an inset icon, pressed state shown by an inner shadow (no animation in flight), and a glass-cyan ring when recenter is center-locked. Everything else stays quiet.
- **Motion:** none in flight. Edit-mode transitions are 150 ms or shorter and turned off when `MediaQuery.disableAnimations` is set.

### D10. Testing strategy

- **Domain unit tests:** migrator (v1, v2 and corrupted input), layout editor (bounds, minimums, 48 dp rule, presets), alignment detector, catalog completeness (every `WidgetType` has a spec).
- **View model unit tests:** edit mode (one notify per effective change, none for no-ops), map camera (timer with `fakeAsync`, limits, recenter).
- **Overflow sweep:** a table-driven widget test over type × style × tier sizes × canvas {390x844, 844x390, 1280x800} × {flight, edit-selected}, failing on any `FlutterError` by asserting `tester.takeException()` is null.
- **Rebuild-count test:** an instrumented build counter on the canvas, the instruments and the inspector, driven by synthetic snapshots.
- **Map control widget tests:** use a fake `MapLibreMapService` and cover targeting, missing target, built-in visibility and parity with the built-in buttons.
- **`integration_test/app_walkthrough_test.dart`:** run on Linux desktop (`flutter test integration_test -d linux`) at three window sizes. It walks the nav overlay, screen switch, edit mode, adding every widget type, resize, preset, configure, wide variant, done, a replay start, and map controls. It fails on any reported Flutter error.
- **Web check:** the existing Playwright check is extended for the web build.

## Risks / Trade-offs

- [Migration distorts unusual saved layouts through rounding] → Proportional mapping, a minimum height of 1, a backup key, and golden-style unit tests on all default screens plus random fuzz layouts that check bounds stay valid.
- [Large diff conflicts with in-flight changes] → Only touched slices move, re-export shims stay at old paths, and work is merged in small commits per task group.
- [16x32 cells on small phones (about 24 x 26 dp) make drag editing fiddly] → Presets, steppers, outside handles and the inspector remain the precise path; drag thresholds are 40% of a cell.
- [Field-scoped selectors add boilerplate] → One generic `TelemetrySelector`; instruments receive plain values.
- [Two layout variants confuse users] → The wide variant is optional, and the tall layout is used when it's missing. The toolbar shows which variant is being edited.
- [Bundled font increases app size by about 150 KB per weight] → Bundle 2 weights only (Medium, Bold).
- [Built-in map buttons hidden on Auto while external controls target a map that's covered] → Controls are foreground by default and the overlap highlight warns in edit mode.
- [Rebuild-count tests are brittle] → Assert upper bounds, not exact counts.

## Migration Plan

1. Land domain models, the migrator and the repository behind the existing `ScreenManagerService` facade. The app runs unchanged in behavior except for the 16x32 rendering.
2. Land the canvas, the size tiers and the layout-error fixes.
3. Land the telemetry repository and selectors.
4. Land the map camera view model and the map controls.
5. Land the editing UX and variants.
6. Update the existing tests that depend on 8-column bounds, then run the full test suite, the overflow sweep and the integration walkthrough.
7. Rollback: revert the commits. Users' v2 data is restorable from the backup key, and an older app loads defaults.

## Open Questions

- Exact S/M/L preset sizes per widget type: tune visually during implementation. This does not affect the specs, since only the existence of presets is specified.
- Whether `ScreenManagerService` can be removed entirely in a follow-up once all callers use the view models.
