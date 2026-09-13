## Context

See `proposal.md` for background motivation. Currently, in `LayoutStrategyContainer`, widgets are rendered in an explicit order via `_getOrderedWidgets`:
1. `WidgetType.map` (layer 0)
2. `WidgetType.thermalMap` (layer 1)
3. Other instrument widgets (layer 2)

In Edit Mode, every widget is wrapped with `_WidgetEditFrame`. Because the map spans full width/height at the bottom layer, any widget placed on top intercepts touches. The map's header (holding the `btn_config_<id>` tune button) is blocked by instruments sharing top coordinates, preventing the pilot from clicking the configuration button. Furthermore, `ScreenManagerService` currently has no selection state, so there is no focused widget concept in Edit Mode.

## Goals / Non-Goals

**Goals:**
- Implement stateful widget selection in `ScreenManagerService` (`selectedWidgetId`, `selectWidget(String? id)`).
- Provide a persistent Widget Layer Selector in the bottom Edit Mode toolbar to select any widget on the screen, even if physically obscured by foreground elements.
- Enable direct tap selection on widget canvases during Edit Mode.
- Render a floating/docked Widget Inspector Panel when a widget is selected, offering immediate access to the detailed configuration dialog, nudge controls, size steppers, delete, and deselect.
- Ensure 100% zero overhead or alteration to operative flight mode rendering and layering.

**Non-Goals:**
- Altering the normal flight mode layer stacking (map remains strictly background in operative mode).
- Modifying MapLibre tile loading or native map touch gestures in operative mode.
- Creating arbitrary z-index persistence in stored screen JSON models.

## Decisions

### Decision 1: Docked/Floating Inspector Panel vs Opaque Stack Elevation
- **Chosen Approach**: A docked/floating Inspector Panel positioned above the Edit Mode bottom toolbar, coupled with an active visual highlight border around the selected widget.
- **Rationale**: Elevating a full-screen background widget (e.g. Map 8x8) to the top of the Flutter `Stack` would completely cover and hide all other instruments on the flight screen, creating a new access problem. The docked inspector panel provides immediate, unobstructed access to settings, nudging, and resizing while keeping all instruments visible in their relative spatial layout.
- **Alternatives Considered**:
  - *Full Canvas Z-Index Elevation*: Elevating the map to the top of the `Stack` upon selection. Rejected because an 8x8 map covers the entire screen, preventing users from seeing or touching any other widgets underneath until deselected.
  - *Automatic Configuration Dialog Popup*: Immediately popping up the full modal tune dialog on every tap. Rejected because it disrupts visual canvas inspection and makes multi-step layout repositioning frustrating.

### Decision 2: Dual Selection Access (Direct Tap + Bottom Bar Layer Selector)
- **Chosen Approach**: Allow selecting widgets both via direct tap on the widget frame and through a dedicated "Select Widget" dropdown/sheet in the Edit Mode bottom toolbar.
- **Rationale**: When a background map is completely or heavily covered by multiple compact instruments, direct tapping might accidentally hit the wrong widget. The toolbar layer selector guarantees that every widget—regardless of occlusion—can be selected with 100% reliability.
- **Alternatives Considered**:
  - *Direct tap only*: Fails when background widgets are completely obscured or hard to tap with flight gloves.

### Decision 3: Ephemeral Edit Mode State in ScreenManagerService
- **Chosen Approach**: Maintain `selectedWidgetId` in `ScreenManagerService` without persisting it to `UIConfig` / storage.
- **Rationale**: Selection is strictly an in-memory editing aid. When Edit Mode is exited or saved, `selectedWidgetId` is cleared, ensuring zero state pollution or serialization changes to existing saved screen layouts.
- **Performance & Battery Trade-offs**: Selection state mutations only trigger lightweight Flutter widget rebuilds during Edit Mode (which is used on the ground or in setup, not during active flight telemetry loops). Zero impact on flight core or battery life.

## Risks / Trade-offs

- **[Risk] Small display screens might have crowded bottom toolbar space with the Inspector visible.**
  → *Mitigation*: The Inspector Panel is designed as a compact, docked card with `FittedBox` or scrollable action chips and a quick "Deselect" / close button.
- **[Risk] Tapping inside map canvas might conflict with native map gesture handling in Edit Mode.**
  → *Mitigation*: In Edit Mode, `_WidgetEditFrame` already overlays widgets with edit frames and gesture detectors; tapping the frame or map area intercepts the edit selection without passing gesture events to the underlying map controller while in Edit Mode.
