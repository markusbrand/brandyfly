## Context

See `proposal.md` for motivation and background. The current UI in `apps/mobile/lib/main.dart` and `apps/mobile/lib/demo/vario_screen.dart` is developer-oriented. The goal is to apply modern frontend design principles (rich aesthetics, glassmorphism, dynamic color accents, micro-animations, ergonomic layouts) to build a flight-ready cockpit interface.

## Goals / Non-Goals

**Goals:**
- Design a modular cockpit design system in Flutter (`lib/ui/theme/cockpit_theme.dart`).
- Build an animated, dynamic vario gauge with custom painters, thermal gradient rings, arc sweeps, and climb/sink color dynamics.
- Build glassmorphic, high-visibility telemetry widgets (`TelemetryCard`, `SparklineChart`, `CockpitNavBar`).
- Support 3 distinct cockpit views: Thermal/Climb View, Cruise/XC View, and Split Mounted Grid View.
- Enforce 48dp minimum touch targets for glove usability and adaptive landscape/portrait grid responsive layouts.
- Maintain zero performance overhead on hot telemetry streams.

**Non-Goals:**
- Rewriting Rust `flight_core` logic or native Kotlin/Swift platform channel contracts.
- Adding online cloud map backend APIs.

## Decisions

### Decision 1: Modular Design Token System (`CockpitTheme`)
- **Rationale**: Storing raw colors or magic pixel sizes inline leads to UI inconsistencies across mobile views. A centralized token system (`CockpitTheme`) defines semantic colors (`climbGreen`, `sinkRed`, `cockpitBg`, `glassSurface`), elevation gradients, typography scale, and standard padding.
- **Alternatives Considered**: Material 3 default colors (rejected due to poor sunlight contrast and lack of cockpit-specific visual hierarchy).

### Decision 2: CustomPainter Vario Gauge with Micro-Animations
- **Rationale**: `CustomPainter` combined with Flutter animation controllers allows smooth 60fps arc sweep rendering and thermal ring gradient transitions without triggering heavy full-widget re-layouts.
- **Alternatives Considered**: SVG assets or standard linear progress bars (rejected for lack of dynamic circular sweep fidelity and lower aesthetic appeal).

### Decision 3: Glassmorphism Telemetry Cards (`TelemetryCard`)
- **Rationale**: Glassmorphic cards with translucent dark backgrounds, subtle inner borders, and high-contrast typography provide modern visual appeal while remaining legible over dynamic background maps or telemetry sparklines.
- **Alternatives Considered**: Solid opaque gray cards (rejected as plain and visually uninspiring).

### Decision 4: Adaptive Grid Layouts for Portrait & Landscape Flight Mounts
- **Rationale**: Pilots mount devices on harnesses in both portrait and landscape. Using `LayoutBuilder` and `OrientationBuilder` ensures components automatically rearrange into side-by-side or stacked grids with 48dp touch targets.
- **Alternatives Considered**: Fixed vertical scroll list (rejected because scrolling is difficult during flight operations).

## Risks / Trade-offs

- **[Risk] High CPU overhead from frequent re-paints** → *Mitigation*: Optimize `CustomPainter.shouldRepaint()` checks and scope `setState` updates to isolated widget subtrees.
- **[Risk] Sunlight legibility with subtle glass blur effects** → *Mitigation*: Ensure minimum contrast ratio of 4.5:1 for all text labels and provide crisp outline borders around glassmorphic panels.

## Migration Plan

1. Structure new UI modules in `apps/mobile/lib/ui/`.
2. Refactor existing `main.dart` and `demo/vario_screen.dart` to consume the new design system and cockpit components.
3. Verify that mock flight simulation and live flight modes render seamlessly across both portrait and landscape screen sizes.
