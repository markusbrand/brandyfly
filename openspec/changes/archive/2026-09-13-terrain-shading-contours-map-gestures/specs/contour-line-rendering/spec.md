## Purpose

Renders vector contour lines from locally stored PMTiles archives at multiple elevation intervals, providing pilots with fine-grained terrain slope and steepness assessment for flight planning and in-flight situational awareness.

## ADDED Requirements

### Requirement: Multi-interval contour line rendering
The application SHALL render contour lines from a per-region `contours.pmtiles` vector archive at three elevation intervals: 10m minor contours, 50m intermediate contours, and 100m major contours with elevation labels.

#### Scenario: Major contour lines at medium zoom
- **WHEN** the map viewport zoom level is 10 or higher and a `contours.pmtiles` archive is present for the current region
- **THEN** the map renders 100m-interval contour lines in a visible brown/sienna stroke with elevation labels in meters at regular intervals along each line

#### Scenario: Intermediate contour lines at higher zoom
- **WHEN** the map viewport zoom level is 12 or higher and contour data is available
- **THEN** the map renders 50m-interval contour lines in a thinner, semi-transparent stroke between the 100m major contours, without labels

#### Scenario: Fine contour lines for close-range terrain assessment
- **WHEN** the map viewport zoom level is 14 or higher and contour data is available
- **THEN** the map renders 10m-interval contour lines in a thin, low-opacity stroke between the 50m contours, enabling assessment of steep walls, launch slopes, and landing field gradients at close range

### Requirement: Contour visibility toggle
The application SHALL allow the contour line overlay to be toggled on or off independently of other map layers.

#### Scenario: Contours disabled by widget parameter
- **WHEN** the map widget is configured with `showContours: false`
- **THEN** no contour lines are rendered regardless of contour data availability

#### Scenario: Contours enabled but no data available
- **WHEN** the map widget is configured with `showContours: true` but no `contours.pmtiles` archive is present for the current region
- **THEN** the map renders without contour lines and no errors are raised

### Requirement: Contour data as separate offline archive
The application SHALL load contour vector tiles from a `contours.pmtiles` archive stored separately from the map and terrain PMTiles archives in the per-region directory.

#### Scenario: Contour archive detection and source configuration
- **WHEN** the map style is built for a region that contains a `contours.pmtiles` file in its region directory
- **THEN** the style builder configures an additional vector tile source for contour data, served through the existing loopback HTTP tile server

#### Scenario: Region without contour archive
- **WHEN** the map style is built for a region that does not contain a `contours.pmtiles` file
- **THEN** the contour vector source and associated style layers are omitted from the generated style, and no errors are raised

### Requirement: Contour line pipeline generation
The offline map data pipeline SHALL generate `contours.pmtiles` per region from the same Copernicus GLO-30 DEM source used for terrain hillshade.

#### Scenario: Contour generation from regional DEM
- **WHEN** the pipeline processes a region with a cropped DEM GeoTIFF
- **THEN** it generates contour lines at 10m intervals, converts them to vector tiles with zoom-level-appropriate simplification, and packages them as `contours.pmtiles` alongside the region's `map.pmtiles` and `terrain.pmtiles`

#### Scenario: Contour data size budget
- **WHEN** contour vector tiles are generated for a typical Alpine region (~2° × 2° bbox)
- **THEN** the resulting `contours.pmtiles` file is no larger than 50 MB, balancing line detail against download size
