## Why

In Edit Mode, background widgets such as full-screen Map or Thermal Map are placed at the lowest visual layer (layer 0) so instruments can render on top during flight. However, this causes severe usability issues when editing layouts: foreground instrument widgets overlap and block access to the background map's header, drag handle, and configuration tune button. Furthermore, selecting a widget currently lacks explicit selection state tracking and does not provide an unobstructed way to configure or nudge background widgets. Pilots need a convenient, reliable way to select any widget (including background maps) and access its configuration settings through a dedicated floating/docked inspector panel without obscuring other widgets on the screen.

## What Changes

- **Selected Widget State in ScreenManagerService**: Add `selectedWidgetId` tracking to `ScreenManagerService`, setting or clearing the selected widget upon tap, toolbar selection, or exiting edit mode.
- **Widget Layer Selector in Edit Mode Toolbar**: Add an on-screen widget switcher in the Edit Mode bottom toolbar enabling pilots to select any placed widget directly (even if physically obscured by overlapping instruments).
- **Direct Tap Selection & Active Highlighting**: Tapping any widget in Edit Mode selects it and highlights its bounding box with an active accent border and glow, without altering the underlying rendering z-order of flight widgets.
- **Floating/Docked Widget Inspector Panel**: When a widget is selected in Edit Mode, present a docked/floating inspector card above the edit toolbar displaying widget details (type, coordinates, dimensions), quick-action buttons (Configure tune dialog, Nudge position, Resize steppers, Delete), and a Deselect button.
- **Unobstructed Map Configuration**: Enable opening the widget configuration sheet directly from the inspector panel, resolving blocked click access for background map and thermal widgets.
- **Preserved Operative Layering**: Ensure operative flight mode remains strictly layered (Map/Thermal background, instruments in foreground) with zero performance or gesture overhead during flight.

## Capabilities

### New Capabilities
<!-- None -->

### Modified Capabilities
- `screen-widget-configuration`: Adds widget selection state, Edit Mode widget layer selector, active widget highlighting, and the floating/docked inspector panel for unobstructed configuration of background and overlapping widgets.

## Non-Goals

- Permanent user-configurable z-index layer ordering during active flight (map widgets remain background by design in operative flight mode).
- Modifying MapLibre tile downloading, caching, or rendering pipelines.
- Replacing the comprehensive widget tune dialog (the inspector panel provides quick actions and launches the existing detailed tune dialog).

## Impact

- **Affected Code**: `apps/mobile/lib/services/screen_manager_service.dart`, `apps/mobile/lib/widgets/layout/layout_strategy_container.dart`, and associated widget unit/integration tests in `apps/mobile/test/`.
- **APIs**: Extended `ScreenManagerService` with `selectedWidgetId`, `selectWidget(String? id)`, and automatic reset on edit mode toggle.
- **Safety, Privacy, & Offline**: Fully offline and local UI state; does not alter telemetry or sensor execution loops on the flight core; zero network or privacy footprint.
- **Licensing**: MIT compliant (BrandyFly open-source codebase).
