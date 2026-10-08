## Context

Tactical fixes were merged directly into `main` without OpenSpec tracking:
1. `download_osm.py` had an SSRF vulnerability where unvalidated external URLs could be requested by CI or local scripts. Domain validation was added restricting requests to `https://download.geofabrik.de/`.
2. `LocalTileServer` previously returned `Access-Control-Allow-Origin: *` headers, which could permit untrusted browser contexts to query loopback assets. Wildcard CORS headers were removed.
3. `VarioLiftSinkBar` collapsed into text-only `_buildTiny()` for all styles when allocated a tiny tier slot (< 40 dp), hiding the vertical edge bar graphic. Logic was added to keep rendering `_buildVerticalEdgeBar` when `style == LiftSinkBarStyle.verticalEdgeBar`.

## Goals / Non-Goals

**Goals:**
- Formally document the exact security and UI architectural requirements in OpenSpec specs.
- Verify tests and contracts matching these requirements.

**Non-Goals:**
- Modifying production runtime logic (the code implementations are already in place and tested).

## Decisions

- **Decision 1**: Restrict `download_osm.py` to `https://download.geofabrik.de/` prefix.
  - *Rationale*: Geofabrik is the official and curated source for OSM PBF extracts in BrandyFly.
  - *Alternative*: Allow arbitrary URLs with user confirmation (rejected: risky for unattended pipeline runs).
- **Decision 2**: Remove wildcard CORS headers from `LocalTileServer`.
  - *Rationale*: The local tile server only serves native MapLibre GL instances over loopback (`127.0.0.1`); it does not need to allow cross-origin browser requests.
- **Decision 3**: Preserve `_buildVerticalEdgeBar` in tiny tier.
  - *Rationale*: Pilots relying on edge-docked vario bars need the visual lift/sink tape even in compact vertical slots.

## Risks / Trade-offs

- [Risk] Custom OSM mirrors cannot be downloaded via `download_osm.py` without code modification → Acceptable trade-off for security; local files can still be provided manually.
