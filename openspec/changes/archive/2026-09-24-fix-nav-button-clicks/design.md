## Context

See `proposal.md` for motivation. In `TopNavBarOverlay` (`apps/mobile/lib/widgets/navigation/top_nav_bar.dart`), the navigation drawer presents screen selection chips and three action buttons (`Flights`, `Edit Mode`, `Settings`).

## Goals / Non-Goals

**Goals:**
- Fix `ChoiceChip` interaction in `_buildScreenSelector` so that clicking any screen chip (including re-clicking the active chip) reliably responds and dismisses the navigation drawer.
- Ensure all action buttons (`Flights`, `Edit Mode`, `Settings`) and control icons (`Close`, `Add Screen`) register single discrete mouse clicks and touch taps cleanly.
- Prevent taps inside the drawer content area from leaking through to the backdrop dismiss barrier or underlying map canvas.

**Non-Goals:**
- Changing the visual theme or layout dimensions of the navigation drawer.
- Modifying flight computer state or screen persistence services.

## Decisions

### Decision 1: Unconditional Screen Selection on Chip Tap
- **Choice**: In `_buildScreenSelector`, handle `onSelected: (_) { widget.screenManager.setActiveScreen(screen.id); widget.screenManager.toggleNavBar(false); }` unconditionally.
- **Rationale**: Flutter's `ChoiceChip.onSelected` passes `false` when a user taps a chip that is already selected. Checking `if (selected)` caused the active chip to do nothing when clicked, creating the impression that clicking was broken.
- **Alternatives Considered**: Using custom `InkWell` containers. Rejected because standard `ChoiceChip` with unconditional handling correctly fulfills the requirement with zero styling regression.

### Decision 2: Drawer Body Tap Absorption
- **Choice**: Wrap `_buildNavBarContent` in `GestureDetector(behavior: HitTestBehavior.opaque, onTap: () {})`.
- **Rationale**: Prevents any click within the drawer's bounds (e.g. between buttons or in margins) from penetrating to the `Positioned.fill` dismiss barrier or the underlying `MapWidget`.

### Decision 3: Scroll and Drag Disambiguation
- **Choice**: Configure `SingleChildScrollView` within the drawer with `physics: const ClampingScrollPhysics()` and ensure horizontal chip rows do not block discrete vertical pointer releases.

## Risks / Trade-offs

- **[Risk]** Fast repeated taps on screen chips:
  - *Mitigation*: `setActiveScreen` in `ScreenManagerService` already guards against duplicate active screen transitions (`if (_config.activeScreenId == screenId) return;`) while cleanly closing the drawer.
