## Why

Several security and UI behavior improvements were implemented in the codebase (e.g. PRs #214, #230, #239) outside of a dedicated OpenSpec cycle. To preserve full architectural traceability and prevent spec drift, these improvements must be integrated into the OpenSpec specifications:
1. **Loopback Tile Server CORS Protection**: Restricting CORS by omitting wildcard `Access-Control-Allow-Origin: *` headers on the local loopback HTTP tile server (`LocalTileServer`), preventing cross-origin access from arbitrary local browser tabs or webviews.
2. **Map Pipeline SSRF Mitigation**: Enforcing strict URL allowlist validation in the offline map data pipeline (`download_osm.py`) ensuring source downloads only accept trusted HTTPS origins (`https://download.geofabrik.de/`).
3. **Vertical Edge Vario Bar Slender Slot Rendering**: Ensuring the vertical edge vario bar (`LiftSinkBarStyle.verticalEdgeBar`) preserves its continuous graphic representation in slender slots whose shortest side is below 40 dp (SizeTier.tiny) instead of collapsing into a generic numeric pill.

## What Changes

- Update `offline-vector-map-rendering` spec to require omission of wildcard CORS headers on local loopback server responses.
- Update `offline-map-region-pipeline` spec to specify download URL allowlist validation against trusted origins (`https://download.geofabrik.de/`).
- Update `screen-widget-configuration` spec to document that edge-style instrument indicators (such as `verticalEdgeBar`) render their dedicated primary graphic bar in tiny size tiers.
- Add regression tests covering download URL security validation and tiny-tier vertical edge bar rendering.

## Capabilities

### New Capabilities
None.

### Modified Capabilities
- `offline-vector-map-rendering`: Specify that `LocalTileServer` restricts CORS headers on loopback endpoints.
- `offline-map-region-pipeline`: Specify URL prefix allowlisting on pipeline external download tasks.
- `screen-widget-configuration`: Specify that edge-style vario bars render their dedicated graphic representation in slender tiny-tier slots.

## Impact

- **Security**: Hardens local embedded HTTP server and map pipeline tooling against unauthorized cross-origin requests and SSRF.
- **UI/UX**: Preserves full vertical edge bar instrumentation in thin margin slots.
- **Traceability**: Aligns OpenSpec specifications with current repository implementation.
