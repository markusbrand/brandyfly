## Context

See proposal.md for motivation. The issues stemmed from Flutter gesture arena collisions in the TopNavBarOverlay and a MapLibre GL Native bug triggered by an incompatible remote font server combined with an Android emulator software GPU driver (`swiftshader_indirect`).

## Goals / Non-Goals

**Goals:**
- Enable touch passthrough in the top navigation overlay so users can tap `ChoiceChips` to change screens.
- Prevent MapLibre from crashing or rendering pink error boxes by switching to a robust, compatible glyphs URL.

**Non-Goals:**
- Completely rewriting the map engine or gesture recognizer system.

## Decisions

- **HitTestBehavior.deferToChild for Navigation Overlay**: We update the top navigation overlay container to defer touches, preventing it from greedily swallowing taps meant for the choice chips.
- **OpenFreeMap Glyphs Endpoint**: We chose `tiles.openfreemap.org/fonts/` instead of `fonts.openmaptiles.org` or `demotiles.maplibre.org` because OpenFreeMap provides MapLibre-compatible PBFs that do not trigger the `unknown pbf field type` exception on our Android Native engine version, and hosts the required `Noto Sans` fallback fonts.
- **Explicit Font Fallbacks**: We specify `text-font: ["Noto Sans Bold"]` to avoid engine default fallbacks that fail to render on software GPUs.

## Risks / Trade-offs

- [Risk] Font endpoints can occasionally go offline or change schemas. → Mitigation: We rely on OpenFreeMap, which is already our trusted fallback for vector tiles, centralizing our dependencies.
