## MODIFIED Requirements

### Requirement: Alpine Relief map style
The application SHALL render maps using a custom "Alpine Relief" MapLibre style optimized for paragliding situational awareness conforming to the OpenMapTiles v3 schema. The style MUST use a highly compatible glyphs URL (`https://tiles.openfreemap.org/fonts/{fontstack}/{range}.pbf`) that natively supports MapLibre GL Native on Android without triggering protobuf parsing exceptions. Fallback font families (`Noto Sans Bold`, `Noto Sans Regular`) MUST be explicitly specified for text layers to prevent missing glyph rendering errors on software GPUs (e.g. SwiftShader).

#### Scenario: Style layer hierarchy
- **WHEN** the map is rendered with the Alpine Relief style
- **THEN** the visual prominence hierarchy is: (1) hillshade relief dominant, (2) hypsometric elevation color ramp (green valleys to brown rock to white peaks), (3) water bodies in blue, (4) major roads and aerialways as thin muted lines, (5) sparse labels (peak names with elevations at zoom >= 11, town/village names zoom-dependent), and no building outlines or generic POI icons

#### Scenario: Style bundled in app
- **WHEN** the app is installed or updated
- **THEN** the Alpine Relief style JSON is included in the app bundle and can be iterated without requiring region data re-downloads

#### Scenario: OpenMapTiles v3 schema compatibility
- **WHEN** vector tiles generated with OpenMapTiles v3 (Planetiler) or served by OpenFreeMap are loaded into the map engine
- **THEN** features in `landcover`, `landuse`, `water`, `waterway`, `transportation`, `mountain_peak`, and `place` layers match style layer filters and render visibly without cluttering the screen with unfiltered dots

#### Scenario: Offline Map Text Rendering and GPU Compatibility
- **WHEN** the map text (city labels, peaks) is rendered by the Android MapLibre engine on hardware or software GPUs (including `swiftshader_indirect`)
- **THEN** the text SHALL be loaded from the compatible OpenFreeMap glyphs endpoint and correctly paint without falling back to pink/red missing glyph error boxes or dropping vector layers due to protobuf exceptions.
