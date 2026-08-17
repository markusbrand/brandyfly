# Design: app-mvp-ui-and-architecture

## Context

Pilots need a modern, local-first Flutter UI that adapts to sunlight readability, touch-screen interactions, and desktop/tablet screen sizes.

## Component Design Options (from `ui_mockup_options`)

1. **Numeric/Text Widgets**: Option 1 (Minimalist Text), Option 2 (High-Contrast Box), Option 3 (Circular Gauge), Option 4 (Retro Digital). Default: Option 1.
2. **Wind Direction Widget**: Option 1 (Relative Arrow), Option 2 (Mini Compass Rose), Option 3 (Windsock Indicator). Default: Option 1.
3. **Visual Lift/Sink Bar**: Option 1 (Vertical Edge Bar), Option 2 (Analog Dial), Option 3 (Screen Edge Glow). Default: Option 1.
4. **Flight Height Chart**: Option 1 (Minimal Sparkline), Option 2 (Filled Area Graph), Option 3 (Detailed Grid). Default: Option 1.
5. **Base Map Widget**: Option 1 (Full-Screen Backdrop), Option 2 (Resizable Floating Panel), Option 3 (Split Layout). Default: Option 1.
6. **Normal Flight Screen Layout Strategy**: Option 1 (Freeform HUD), Option 2 (Snap-to-Grid), Option 3 (Sidebar Dashboard). Default: Option 3.
7. **Thermaling Screen**: Option 1 (Zoomed Radar), Option 2 (Focus Mode), Option 3 (Assistant Display). Default: Option 3.
8. **Navigation Bar**: Option 1 (Full-Width Translucent Drawer), Option 2 (Floating Action Pill), Option 3 (Corner Menu Button). Default: Option 1.
9. **Settings Screen**: Option 1 (Modal Overlay Dialog), Option 2 (Full-Screen Categorized List), Option 3 (Card-Based Dashboard). Default: Option 2.

## Persistence & State Management

- Use Flutter state management to handle screen layout state, active widgets, and widget configurations.
- Serialize UI preferences and selected mockup style enums using `shared_preferences`.
