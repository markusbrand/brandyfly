## Why

Several tactical security hardening fixes and UI resilience improvements were implemented in the codebase without corresponding OpenSpec change tracking:
1. SSRF prevention in the map pipeline by enforcing trusted domain validation for Geofabrik downloads (#230).
2. Elimination of overly permissive wildcard CORS headers on the embedded loopback tile server (#214).
3. Preservation of the vertical vario edge bar graphic in tiny instrument slots without collapsing to text (#239).

Bringing these enhancements into the formal OpenSpec specification ensures specification completeness, auditability, and adherence to project governance standards.

## What Changes

- **Map Pipeline Download URL Hardening**: Specify that `download_osm.py` restricts download URLs strictly to `https://download.geofabrik.de/` to prevent SSRF vulnerabilities.
- **Embedded Tile Server CORS Restriction**: Specify that `LocalTileServer` does not emit wildcard `Access-Control-Allow-Origin` headers on loopback responses, preventing unauthorized cross-origin browser/WebView inspection.
- **Vario Bar Tiny Slot Graphic Preservation**: Clarify that the vertical edge bar style of `VarioLiftSinkBar` renders its graphical indicator even when placed in tiny size tier slots.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `offline-map-region-pipeline`: Enforce strict domain whitelisting for OSM PBF downloads to prevent SSRF.
- `offline-vector-map-rendering`: Omit permissive wildcard CORS headers from local tile server responses.
- `screen-widget-configuration`: Retain vertical edge bar styling in tiny tier widget allocations.

## Impact

- **Security**: Hardened defenses against SSRF in automated pipelines and cross-origin leakage on device loopback endpoints.
- **UI/UX**: Consistent visual presentation of the vertical vario bar across small and compact cockpit layout slots.
- **Specs**: Up-to-date specification documentation in `openspec/specs/`.
