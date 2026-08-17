# Proposal: app-mvp-ui-and-architecture

## Why

BrandyFly needs a flexible, user-configurable UI architecture for its paragliding vario app. Pilots have different preferences for instrument displays (flight widgets, vario indicators, map overlays, thermaling assistance) and require high-contrast, adaptable layouts that can be customized via an "Edit Mode" and accessed via a top-down swipe navigation bar.

## What

Implement the MVP UI Architecture and User-Configurable Screens:
- **Top-Down Navigation Bar**: Swipe-down top navigation drawer with configurable opacity, housing Settings and Edit Mode toggles (`[REQ-UI-003]`).
- **User-Configurable Screens & Edit Mode**: Allow users to add, remove, resize, and position flight widgets using configurable visual mockup options (Freeform HUD, Snap-to-Grid, Sidebar Dashboard) (`[REQ-UI-004]`).
- **Flight Widgets Suite**: Modular widgets for Groundspeed, Altitude, Vario Lift/Sink Bar, Wind Direction, Height Above Ground, Glide Ratio, and Altitude Sparkline (`[REQ-WIDGET-001]`, `[REQ-WIDGET-002]`).
- **Configurable UI Mockup Options**: Implement visual styling options (Options 1–4) for widgets, navigation, thermaling assistant, and settings overlays as specified in `ui_mockup_options`.
