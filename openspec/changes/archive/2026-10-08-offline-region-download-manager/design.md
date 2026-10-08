## Context

After the MapLibre/PMTiles migration (issue #84), the app renders vector maps from local PMTiles files. This change provides the user-facing mechanism to acquire, manage, and update those files. The data pipeline change (issue #86) provides the server-side infrastructure that generates and hosts the region files.

## Architecture Decisions

### 1. Curated mountain-range flying regions

Regions are defined by mountain-range flying areas, not country borders, because paragliding cross-country flights follow terrain rather than political boundaries. Initial v1 catalog:

| Region ID | Coverage | Est. Size |
|---|---|---|
| `alps-east` | Eastern Austria, Slovenia, SE Bavaria (Dachstein, Karawanken, Julian Alps) | ~160 MB |
| `alps-central` | Tyrol, Vorarlberg, eastern CH, Allgaeu (Stubai, Zillertal, Arlberg, Engadin) | ~140 MB |
| `alps-west` | Western CH, French Alps, Aosta, Savoie (Chamonix, Verbier, Annecy) | ~180 MB |
| `alps-south` | South Tyrol, Trentino, Dolomites, Lombardy lakes (Bassano, Garda, Feltre) | ~130 MB |
| `pyrenees` | FR/ES/AD Pyrenees chain | ~120 MB |
| `balkans-west` | Croatia coast, Montenegro, Albania, North Macedonia | ~130 MB |
| `turkey-aegean` | SW Turkey coast (Oeluedeniz, Kas, Babadag) | ~100 MB |
| `carpathians` | Romania, Slovakia, southern Poland | ~140 MB |

Neighboring regions overlap by ~20 km at boundaries for seamless XC coverage.

### 2. Catalog schema

Server-hosted `catalog.json` (fetched from CDN):

```json
{
  "catalogVersion": 1,
  "generatedAt": "2026-08-01T00:00:00Z",
  "regions": [
    {
      "id": "alps-east",
      "name": "Alps - Eastern",
      "description": "Eastern Austria, Slovenia, SE Bavaria",
      "bounds": { "north": 48.3, "south": 46.2, "west": 12.5, "east": 16.6 },
      "version": "2026-08",
      "generatedAt": "2026-08-01T00:00:00Z",
      "files": {
        "map": { "url": "https://cdn.example/regions/alps-east/map.pmtiles", "sizeBytes": 104857600, "sha256": "abc..." },
        "terrain": { "url": "https://cdn.example/regions/alps-east/terrain.pmtiles", "sizeBytes": 62914560, "sha256": "def..." }
      }
    }
  ]
}
```

### 3. Local storage structure

```
{appSupportDir}/
  regions/
    catalog_cache.json         # Last fetched catalog (for offline browsing)
    alps-east/
      map.pmtiles              # Active vector tiles
      terrain.pmtiles          # Active terrain DEM tiles
      meta.json                # Local metadata: version, download date, checksums
    alps-central/
      ...
```

### 4. Download mechanism

- HTTP range requests for resume support (CDN must support `Accept-Ranges`)
- Download to `{region-id}.downloading/` temp directory
- Verify SHA-256 checksums on completion
- Atomic swap: rename temp dir to active dir, delete old dir
- Progress tracked via `StreamSubscription` on HTTP response bytes

### 5. RegionManagerService

A service class managing all region lifecycle operations:
- `fetchCatalog()` — fetch and cache catalog.json
- `getDownloadedRegions()` — list locally available regions with metadata
- `downloadRegion(regionId)` — start background download with progress stream
- `updateRegion(regionId)` — download newer version, swap on completion
- `deleteRegion(regionId)` — remove files, reclaim storage
- `getStorageUsage()` — total and per-region disk usage
- `isLocationCovered(lat, lon)` — check if GPS point is within any downloaded region bounds
- `getSuggestedRegions(lat, lon)` — find catalog regions covering a GPS point (for pre-flight prompt)

### 6. Pre-flight prompt behavior

- Checks `isLocationCovered()` on app foreground / GPS update
- If uncovered, shows a Material bottom sheet with suggested regions and sizes
- Dismissable via swipe-down or "Not now" button
- Session-scoped: does not reappear until app restart or significant GPS location change (>50 km)
- Does NOT auto-download; always requires explicit pilot action

### 7. Region Manager UI

A new screen accessible from Settings:
- List of all regions (downloaded + available) grouped by geographic area
- Per region: name, description, status badge (Downloaded / Update Available / Not Downloaded), size, version date
- Action buttons: Download / Update / Delete with confirmation
- Total storage bar at top
- Pull-to-refresh for catalog update
