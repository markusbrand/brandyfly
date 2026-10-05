## 1. Modify Map Style

- [x] 1.1 Remove `landcover-glacier`, `landcover-rock`, `landcover-wood`, `landuse-wood`, `landcover-grass`, `landuse-grass`, and `landuse-urban` layers from `apps/mobile/assets/map_styles/alpine_relief.json` and verify the JSON syntax remains valid using `jq . apps/mobile/assets/map_styles/alpine_relief.json`.
- [x] 1.2 Update the `brandyfly:description` metadata in `apps/mobile/assets/map_styles/alpine_relief.json` to state that the style emphasizes hillshade and has removed landcover polygons, and verify the JSON syntax is valid.
