# Tasks: app-mvp-ui-and-architecture

## 1. Navigation & Screen Management

- [x] 1.1 Implement top swipe-down Navigation Bar widget (`[REQ-UI-003]`) with slide animations and dismiss-on-tap-outside behavior.
- [x] 1.2 Add Navigation Bar mockup options (Option 1: Translucent Drawer, Option 2: Floating Pill, Option 3: Corner Menu).
- [x] 1.3 Create Screen Manager service supporting multiple flight screens and active screen switching.

## 2. Configurable Widget Grid & Edit Mode

- [x] 2.1 Implement Edit Mode state toggle and overlay UI for editing widget layouts (`[REQ-UI-004]`).
- [x] 2.2 Implement layout strategy engines (Option 1: Freeform HUD, Option 2: Snap-to-Grid, Option 3: Sidebar Dashboard).
- [x] 2.3 Add Widget Picker sheet to add, remove, and resize widgets in Edit Mode.

## 3. Modular Flight Widgets Suite

- [x] 3.1 Implement modular Numeric Text Widgets (Altitude, Speed, Glide, HAG) supporting visual style options 1–4.
- [x] 3.2 Implement Wind Direction Widget supporting Relative Arrow, Compass Rose, and Windsock options.
- [x] 3.3 Implement Vario Lift/Sink Bar supporting Vertical Edge Bar, Analog Dial, and Screen Edge Glow options.
- [x] 3.4 Implement Altitude Sparkline Chart with Sparkline, Area Graph, and Detailed Grid options.

## 4. UI Settings & Persistence

- [x] 4.1 Create UI Settings panel to let users choose visual mockup styles for each component category.
- [x] 4.2 Persist active screen layouts and widget mockup options to `shared_preferences`.
- [x] 4.3 Add unit and widget tests for screen management, Edit Mode operations, and persistence.
