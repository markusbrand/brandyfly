## Why

Users encountered critical UI issues during flight simulation mode:
1. The top navigation bar overlay prevented interaction with the `ChoiceChip` components underneath it, making it impossible to switch between the normal flight screen, the map screen, and the thermaling screen.
2. The offline map labels (cities, towns, peaks) rendered as unreadable pink and red boxes instead of text because the `alpine_relief.json` map style relied on a MapLibre remote font server (`demotiles.maplibre.org/font/`) that either blocked the Android emulator or failed to serve glyphs in a format compatible with Android's `swiftshader_indirect` OpenGL renderer.

## What Changes

- Fix the navigation overlay gesture arena collision by adjusting `HitTestBehavior` or `IgnorePointer` settings so taps correctly pass through the drag handle container down to the `ChoiceChips`.
- Replace the incompatible `glyphs` URL in `alpine_relief.json` with a highly reliable open-source endpoint (`https://tiles.openfreemap.org/fonts/{fontstack}/{range}.pbf`) that correctly supports MapLibre GL Native on Android.
- Explicitly define `text-font` fallbacks for `place-omt-labels` (`Noto Sans Bold`) and `mountain-peak-label` (`Noto Sans Regular`) to match the new OpenFreeMap glyphs.
- Increase the legibility of map text by increasing the `text-size` property for cities (to 18) and peaks (to 15).

## Capabilities

### New Capabilities
None.

### Modified Capabilities
- `offline-vector-map-rendering`: Map style glyph compatibility requirements.
- `screen-widget-configuration`: Navigation gesture handling and touch passthrough.

## Impact

- **UI Navigation**: Pilots can reliably switch between flight views.
- **Map Rendering**: City and peak labels render crisply offline without crashing the SwiftShader software GPU driver or MapLibre GL engine.
- **Offline Reliability**: Font dependency is strictly configured to a highly compatible endpoint, avoiding fallback errors.
