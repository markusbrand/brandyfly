## Why

The current offline map rendering includes opaque landcover polygons from OpenStreetMap (such as forests, grass, and rock) that obscure the underlying terrain hillshade visualization. For paragliding and flight navigation, terrain awareness is often more critical than landcover type. By removing these obscuring polygons, the hillshade can be fully emphasized, allowing pilots to better orient themselves relative to ridges and valleys, while still retaining essential geographic context from water bodies, roads, and labels.

## What Changes

- Remove all `landcover-*` and `landuse-*` polygon layers (e.g., glaciers, rock, wood, grass, urban) from the bundled `alpine_relief.json` map style.
- Update the style metadata description in `alpine_relief.json` to reflect the removal of landcover polygons.
- Update the `offline-vector-map-rendering` specification to align the documented styling rules with this pure-hillshade visual hierarchy.

## Capabilities

### New Capabilities
- None

### Modified Capabilities
- `offline-vector-map-rendering`: Simplify the "Alpine Relief map style" requirements to remove the hypsometric elevation color ramp and emphasize pure hillshade with essential orientation data (water, roads, text).

## Impact

- **UI / Visuals**: Maps will appear simpler, with terrain relief (shadows/highlights) visible over a solid background color rather than tinted by landcover types.
- **Offline / Performance**: Minor performance improvement during vector tile rendering due to fewer polygon layers being parsed and drawn.
- **Safety**: Enhances situational awareness by preventing large green or brown polygons from hiding nuanced topographic features.
- **Licensing/Privacy**: No impact.
