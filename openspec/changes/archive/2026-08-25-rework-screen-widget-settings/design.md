## Context

See `proposal.md` for motivation. Currently, `UIConfig` in `apps/mobile/lib/models/ui_config.dart` stores styling properties as top-level fields (e.g. `mapWidgetStyle`, `numericWidgetStyle`, `liftSinkBarStyle`), which binds all widgets and screens to a single global look. `FlightScreenModel` only carries `id`, `name`, `layoutStrategy`, and a list of `WidgetPlacementModel`, while `WidgetPlacementModel` only stores `id`, `type`, `x`, `y`, `w`, and `h`.

## Goals / Non-Goals

**Goals:**
- Enable each `WidgetPlacementModel` to carry an optional typed configuration map / properties for its visual style and options (e.g., map style, orientation, layer toggles, numeric style, units, vario scale, sparkline time window).
- Maintain default visual styles defined within the widget constructors so unconfigured widgets render with sensible defaults without global lookups.
- Enable `FlightScreenModel` to define its layout strategy and optional auto-switch trigger (e.g., `manualOnly`, `onThermalCircling`, `onGlideStraight`).
- Provide an intuitive bottom-sheet dialog in Edit Mode when tapping `Icons.tune` on any widget frame to configure its specific styling, layers, and position.
- Simplify `UISettingsPanel` and `UIConfig` by removing widget styling options and keeping only global application settings.

**Non-Goals:**
- Adding cloud sync for layout templates.
- Changing FFI/Rust flight tracking logic or native sensor pipelines.

## Decisions

### 1. Widget Configuration Storage Structure
- **Decision**: Embed widget-specific options in `WidgetPlacementModel` with typed getters and copy helpers (or a flexible `customization` map) that cleanly serializes to/from JSON.
- **Alternatives Considered**:
  - *Sealed class hierarchy for every widget*: Adds boilerplate serialization code for minor widget options.
  - *Loose unstructured string map*: High risk of runtime key typos and type mismatch.
- **Rationale**: A structured model with fallback defaults preserves type safety in Dart while allowing backward-compatible JSON decoding.

### 2. Built-in Defaults in Widget Classes
- **Decision**: Widgets define their default presentation style in their constructors and placement factory methods.
- **Alternatives Considered**:
  - *Global default theme lookup service*: Requires dependency injection and extra boilerplate in every render method.
- **Rationale**: Keeps widgets self-contained and prevents UI thread latency during rendering.

### 3. Screen Layout & Auto-Switching Ownership
- **Decision**: `LayoutStrategyContainer` reads layout strategy directly from `activeScreen.layoutStrategy` rather than the global `UIConfig`.
- **Alternatives Considered**:
  - *Global layout strategy with screen override*: Confusing to users and creates redundant state.
- **Rationale**: Screen-owned layout strategy gives complete flexibility per screen (e.g. Map HUD on one screen, Grid Instrument cluster on another).

### 4. Edit-Mode Tuning UX
- **Decision**: Replace the simple coordinate dialog in `_WidgetEditFrame` with a dedicated widget configuration modal/sheet that displays the style choice chips, layer toggles, and coordinate steppers.
- **Rationale**: Brings immediate visual feedback right where the pilot is customizing the screen.

## Risks / Trade-offs

- **[Risk] Existing saved JSON configurations in SharedPreferences might lack widget config fields.**
  → **Mitigation**: Implement safe JSON deserialization defaults in `WidgetPlacementModel.fromJson` and `FlightScreenModel.fromJson` that gracefully default to standard settings if properties are missing.
- **[Risk] Latency or jank during in-place widget editing.**
  → **Mitigation**: Widget settings updates are applied locally through `ScreenManagerService.updateWidgetPlacement`, keeping updates on standard Flutter reactive setState without re-instantiating the entire widget tree.

## Migration Plan

1. Update `UIConfig`, `FlightScreenModel`, and `WidgetPlacementModel` data models with backward-compatible JSON serialization.
2. Update `LayoutStrategyContainer` and flight widgets (`MapWidget`, `NumericTextWidget`, `VarioLiftSinkBar`, `WindDirectionWidget`, `AltitudeSparklineChart`) to read configuration directly from `WidgetPlacementModel`.
3. Enhance `_WidgetEditFrame`'s `_showConfigDialog` to render widget-specific controls.
4. Clean up `UISettingsPanel` by removing the redundant global instrument styling controls.
5. Verify with automated unit/widget tests and manual preview testing.
