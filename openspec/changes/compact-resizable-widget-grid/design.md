## Context

The existing layout system in `apps/mobile/lib/widgets/layout/layout_strategy_container.dart` is locked to a 4-column grid with a 90px minimum cell height floor. This forces widgets to occupy at least 25% screen width and 90px height, making compact instrumentation impossible. See `proposal.md` for motivation.

## Goals / Non-Goals

**Goals:**
- Transition the layout coordinate system from 4 columns to an 8-column high-density grid.
- Reduce the cell height floor to ~36-40px and increase default row divisions to 8-12 rows to support slim horizontal/vertical instrument strips.
- Maintain full backward compatibility for existing 4-column saved configurations through automatic coordinate scaling (`x, y, w, h * 2`).
- Adapt `_WidgetEditFrame` controls so that small widgets (e.g., 2x1, 1x1 on the 8-column grid) remain cleanly draggable, resizable, and configurable without UI clutter.
- Update `UIConfig.defaultConfig()` screen presets with optimized 8-column layouts.

**Non-Goals:**
- Arbitrary floating point pixel coordinates (grid snapping is safety-critical for paragliding readability and muscle memory).
- Redesigning widget internal graphics beyond responsive scaling.

## Decisions

### Decision 1: 8-Column Grid Standard vs 12-Column Grid
- **Choice**: 8-Column Grid with dynamic row subdivision (`kGridColumns = 8`).
- **Rationale**: 8 columns provide clean doubling from the existing 4-column system (1 column old = 2 columns new), making migration mathematically exact without rounding distortions. 1/8th width (~45-50px on mobile portrait, ~150-200px on landscape tablets) provides ideal granularity for compact numeric indicators, vertical vario bars, and wind arrows.
- **Alternatives Considered**:
  - *12-Column Grid*: Provides finer division (divisible by 2, 3, 4, 6), but requires coordinate scaling factor of 3x and increases drag-snap sensitivity during turbulent flight.
  - *Pure freeform pixel positioning*: Complex manual alignment, high cognitive load for pilots adjusting layouts.

### Decision 2: Cell Height Calculation & Minimum Height Floor
- **Choice**: Calculate `dynamicCellHeight = constraints.maxHeight / math.max(maxBottomGrid, 8)` and lower the minimum height floor from `90.0px` to `38.0px`.
- **Rationale**: Telemetry numbers with label/unit require ~32-36px for optimal legibility. Lowering the minimum height to 38px allows single-row compact metric boxes, while still preventing cramped widgets on small screens.
- **Alternatives Considered**:
  - *Zero floor / unconstrained height*: Risks unreadable widgets on very tall multi-row configurations.

### Decision 3: Compact-Aware Edit Chrome in `_WidgetEditFrame`
- **Choice**: Scale down edit chrome on compact cells (height < 65px or width <= 2):
  - Reduce header padding and icon sizes (12px icons, 8px font).
  - Use `FittedBox` on bottom stepper toolbar and collapse nudges if width is narrow, or show essential controls on selection.
  - Compact corner drag handle (18px × 18px).
- **Rationale**: Prevents 48px edit chrome from consuming 80%+ of small widget frame area.

### Decision 4: Transparent Migration of Legacy Configs
- **Choice**: In `FlightScreenModel.fromJson` or `ScreenManagerService`, detect legacy configurations where grid dimensions are unmigrated (or track config schema version `gridResolution: 8`), and automatically multiply `x, y, w, h` by 2 if `gridResolution < 8`.
- **Rationale**: Pilots upgrading will not lose their custom layouts or experience broken aspect ratios.

## Risks / Trade-offs

- **[Risk]** Touch targets for drag/resize handles on very small widgets (1x1 on 8-column grid) could be hard to tap with flight gloves.
  → *Mitigation*: Edit mode provides both corner drag handles AND the full configuration dialog where exact integer width/height and position can be dialed in via large buttons.
- **[Risk]** Telemetry font scaling clipping inside 1x1 micro-widgets.
  → *Mitigation*: Ensure `FittedBox` in `NumericTextWidget`, `VarioLiftSinkBar`, and `WindDirectionWidget` shrinks text cleanly with `BoxFit.contain` down to minimal bounds.

## Migration Plan

1. Update `UIConfig.defaultConfig()` screen definitions with 8-column coordinates (e.g. Map = 8x8, Sidebar widgets = 2x2 / 2x1).
2. Add migration helper in `UIConfig` to upscale legacy 4-column screen layouts.
3. Update `ScreenManagerService` bounds clamping (`w.clamp(1, 8)`, `h.clamp(1, 16)`).
4. Update `LayoutStrategyContainer` column rendering, guide lines, and edit frame controls.
5. Verify with automated widget tests and manual desktop test runs.
