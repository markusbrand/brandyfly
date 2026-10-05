## Context

See `proposal.md` for the motivation to remove obscuring landcover polygons to emphasize hillshade terrain rendering. The current vector map style is defined in `apps/mobile/assets/map_styles/alpine_relief.json` and parsed natively by MapLibre GL Native on Android and iOS.

## Goals / Non-Goals

**Goals:**
- Completely remove landcover layer definitions from the `alpine_relief.json` map style.
- Maintain existing compatibility with OpenMapTiles v3 vector schema and offline MapLibre PMTiles.

**Non-Goals:**
- Removing or altering the actual OpenMapTiles vector tile generation process (Planetiler) or the PMTiles files. We only change how the data is rendered (client-side styling).

## Decisions

### 1. Removing landcover layers vs making them transparent
- **Decision**: Completely delete the layer objects for `landcover-*` and `landuse-*` from the `layers` array in `alpine_relief.json`.
- **Rationale**: Deleting the layers prevents MapLibre from attempting to parse, filter, or render these polygons at all. This is more performant than keeping them with zero opacity or background-matching colors. 
- **Alternatives Considered**: Keeping the layers but making them transparent. Rejected because it wastes CPU/GPU cycles processing geometry that won't be seen.

## Risks / Trade-offs

- **Risk**: Without landcover, the map background may look barren in flat areas where hillshade is negligible.
  - **Mitigation**: Paragliding primarily occurs in varied terrain where hillshade provides sufficient context. Major roads, water bodies, and populated places will still be visible.
- **Risk**: Deleting layers could inadvertently remove essential map features if we delete too aggressively.
  - **Mitigation**: We will precisely target only the layers with IDs starting with `landcover-` and `landuse-` and leave layers like `water`, `boundary`, `road-`, `mountain-peak`, and `place-` intact.
