# Third-Party Data Source Governance and Licensing Audit

> [!IMPORTANT]
> **Engineering Audit Boundary Notice**
> This document and the accompanying governance contracts constitute an engineering compliance audit and technical licensing verification for the BrandyFly open-source project. It does **not** constitute formal legal advice. Where ambiguous contractual or jurisdictional interpretations arise, data usage remains gated in a `blocked` state until written permission or qualified legal review is obtained.

---

## 1. Overview and Governance Lifecycle

BrandyFly produces offline vector maps, elevation contours, hillshades, aeronautical airspace overlays, geocoding search indices, thermal updraft layers, and optional real-time pilot telemetry.

While BrandyFly application source code is licensed under the **MIT License**, third-party spatial, aeronautical, and telemetry datasets are governed by distinct external licenses (e.g., ODbL 1.0, CC BY 4.0, CC BY-NC-SA 4.0, or proprietary terms).

To ensure that offline bundles and public releases comply with license terms, privacy regulations, and flight safety requirements:
1. **Explicit Pre-Approval**: Every third-party dataset must be audited and classified as `Approved`, `Rejected`, or `Blocked` based on authoritative terms before ingestion.
2. **Provenance & Attribution in Every Manifest**: Every generated offline package carries immutable provenance, license identifier, attribution text/URL, checksum, and review expiry date in its manifest.
3. **Flight-Critical In-Flight Safety**: In the event of source revocation or review expiry, build systems immediately halt new downloads and package creation. However, **installed offline packages are never deleted during flight** to preserve critical flight navigation and collision awareness.

---

## 2. Audited Candidate Inventory by Category

### 2.1 Base Map Extracts
| Candidate / Provider | Dataset Identifier | License / Terms | Decision | Review Expiry | Attribution & Redistribution Notes |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **OpenStreetMap / Geofabrik** | `osm-regional-vector-extracts` | [ODbL 1.0](https://www.openstreetmap.org/copyright) | **Approved** | 2027-08-07 | Attribution: `© OpenStreetMap contributors`. Offline PMTiles vector derivation via Planetiler is permitted under ODbL Produced Work clauses. |
| **Commercial Tile Scraping (e.g., Google/Mapbox)** | `commercial-raster-tiles` | Proprietary Terms of Service | **Rejected** | 2027-08-07 | Commercial web tile terms explicitly prohibit bulk scraping, permanent offline storage, and non-licensed vector conversion. |

### 2.2 Elevation, Contours, and Hillshade
| Candidate / Provider | Dataset Identifier | License / Terms | Decision | Review Expiry | Attribution & Redistribution Notes |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Copernicus DEM GLO-30 (ESA)** | `copernicus-dem-glo-30` | [CC BY 4.0 / Copernicus Policy](https://spacedata.copernicus.eu/) | **Approved** | 2027-08-07 | Attribution: `© European Space Agency (ESA) Copernicus DEM (2021)`. Global 30m raster DEM permits derivative contour line extraction and terrain RGB hillshade packaging. |
| **Proprietary Lidar Survey Feeds** | `proprietary-lidar-unlicensed` | Proprietary / Non-redistributable | **Rejected** | 2027-08-07 | High-resolution national lidar without open redistribution rights cannot be redistributed in public packages. |

### 2.3 Airspace
| Candidate / Provider | Dataset Identifier | License / Terms | Decision | Review Expiry | Attribution & Redistribution Notes |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **open flightmaps (OFM)** | `open-flightmaps-aixm` | [CC BY-NC-SA 4.0](https://www.openflightmaps.org/terms-and-conditions/) | **Approved** | 2027-08-07 | Attribution: `Airspace data © open flightmaps contributors`. Structured AIXM/GeoJSON airspace data with 28-day ICAO AIRAC cycle updates. Non-commercial flight preparation use permitted. |
| **OpenAIP Worldwide Aviation Database** | `openaip-community-airspace` | [CC BY-NC-SA 4.0](https://www.openaip.net/terms-of-service) | **Approved** | 2027-08-07 | Attribution: `Airspace data © openAIP.net contributors`. Community airspace database approved for secondary/supplementary airspace verification under CC BY-NC-SA 4.0. |
| **Commercial NavData (e.g. Jeppesen)** | `jeppesen-commercial-navdata` | Proprietary Aviation License | **Rejected** | 2027-08-07 | Commercial proprietary subscription forbids third-party packaging and public open-source distribution. |

### 2.4 Geocoding (Place & Launch Search)
| Candidate / Provider | Dataset Identifier | License / Terms | Decision | Review Expiry | Attribution & Redistribution Notes |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Photon / Komoot (OSM-based)** | `photon-offline-geocoding` | [ODbL 1.0 / Apache 2.0](https://photon.komoot.io/) | **Approved** | 2027-08-07 | Attribution: `Geocoding data © OpenStreetMap contributors`. Allows building offline SQLite search indices bundled directly inside regional map packages for zero-network flight lookup. |
| **Google Geocoding API** | `google-maps-geocoding` | [Google Maps Platform Terms](https://cloud.google.com/maps-platform/terms) | **Rejected** | 2027-08-07 | Google Terms of Service explicitly prohibit offline pre-fetching, bulk coordinate caching, and rendering on third-party vector map engines. |

### 2.5 Live Pilot Tracking & Telemetry
| Candidate / Provider | Dataset Identifier | License / Terms | Decision | Review Expiry | Privacy & Operational Governance |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Open Glider Network (OGN)** | `ogn-live-aprs-traffic` | [OGN API & APRS Terms](https://www.glidernet.org/) | **Approved** | 2027-08-07 | Attribution: `Live traffic courtesy of Open Glider Network (OGN)`. **Privacy Constraints**: Personal device location data. Ephemeral in-memory display only (<5 min retention). **MUST** respect OGN `no-track` privacy flags and DDB stealth registrations immediately. Legal basis: Flight safety / collision avoidance (GDPR Art. 6(1)(f)). |
| **BrandyFly Live Network (1st-Party)** | `brandyfly-pilot-group-sharing` | MIT / BrandyFly Terms | **Approved** | 2027-08-07 | Attribution: `BrandyFly Live Sharing`. **Privacy Constraints**: Explicit opt-in user consent (GDPR Art. 6(1)(a)). Pilot controls visibility, buddy groups, and ephemeral retention (purged within 24 hours on backend). |
| **Unverified Live Tracking Scraping** | `third-party-live-scraping` | Undocumented Endpoints | **Blocked** | 2027-08-07 | Gated until documented API agreement, consent framework, and GDPR compliance documentation are established. |

### 2.6 Thermal-Derived Data
| Candidate / Provider | Dataset Identifier | License / Terms | Decision | Review Expiry | Attribution & Redistribution Notes |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Thermal.kk7.ch** | `thermal-kk7-hotspots` | [KK7 Terms](http://thermal.kk7.ch/) | **Approved** | 2027-08-07 | Attribution: `Thermal map © thermal.kk7.ch`. Non-commercial paragliding use and offline layer packaging permitted. Data consists of statistical climb aggregations (contains no individual pilot tracklogs). |
| **Raw Crowdsourced IGC Tracklog Mining** | `raw-crowdsourced-igc-mining` | Unverified Portal Data | **Blocked** | 2027-08-07 | Blocked pending explicit consent model, anonymization pipeline, and data ingestion agreements. |

---

## 3. Package Manifest Contract (`DataPackageManifest`)

Every generated data package (PMTiles, elevation archive, airspace bundle, geocoding DB) MUST include a root `manifest.json` containing the following schema fields defined in `packages/contracts`:

```rust
pub struct DataPackageManifest {
    pub schema_version: u16,                     // Must be 1
    pub dataset_identifier: String,              // e.g. "osm-alps-vector-v1"
    pub provider: String,                        // e.g. "osm-geofabrik"
    pub source_version_or_date: String,          // e.g. "2026-08-01"
    pub build_time: String,                      // ISO 8601 UTC timestamp
    pub license_identifier_or_terms_url: String, // e.g. "ODbL-1.0"
    pub attribution_text: String,                // e.g. "© OpenStreetMap contributors"
    pub attribution_url: Option<String>,         // e.g. "https://www.openstreetmap.org/copyright"
    pub geographic_coverage: String,             // e.g. "Alps (bbox: 5.8,43.7,16.5,48.2)"
    pub checksum: String,                        // SHA-256 package hash
    pub review_expiry: String,                   // YYYY-MM-DD revalidation deadline
}
```

Manifests missing any required field, carrying unapproved providers, or having expired review dates are rejected by package validation before distribution.

---

## 4. Operational and Incident Safety Responses

### 4.1 Upstream Source Outages
- If an upstream provider (e.g. Geofabrik, OGN APRS) is temporarily unreachable, build pipelines fall back to secondary mirrors (e.g. OpenStreetMap planet mirrors) or queue the build.
- The mobile application continues normal flight operation with installed offline packages and flags live feed status as disconnected without impacting flight calculations.

### 4.2 Stale Data and AIRAC Cycle Expiry
- Airspace packages carry the 28-day AIRAC cycle date in their manifest.
- When an airspace package exceeds its AIRAC cycle validity, the user interface displays a non-intrusive advisory banner (`Airspace expired on YYYY-MM-DD. Verify active NOTAMs.`).
- Under no circumstances does the application disable or hide airspace data during flight.

### 4.3 License Revocation or Changed Terms
- If a data provider alters terms or revokes redistribution rights:
  1. The dataset record is immediately updated to `state: Rejected` or `state: Blocked` in repository governance contracts.
  2. Automated build and release pipelines halt distribution of new packages immediately.
  3. **In-Flight Safety Policy**: Client devices retain their already-downloaded local offline data with clear provenance labels to ensure pilot navigation is never abruptly deleted in flight.
  4. An incident report identifies affected package versions and schedules replacement packages from approved alternative providers.

### 4.4 Personal Data and Privacy Minimization
- No live pilot locations, personal tracking logs, API secrets, or private flight data are ever committed to the source repository.
- Live pilot telemetry is processed strictly in memory or transient short-lived buffers (<24 hours on backend), and pilot opt-out flags are processed immediately.

---

## 5. Verification and CI Enforcement

Repository data source compliance is continuously verified:
- **Rust Contract Tests**: `cargo test --workspace` validates all data governance schema fixtures and package manifest rules.
- **Repository Audit CLI**: `tools/validate-data-sources.sh` (backed by `validate_data_sources`) checks all candidate records against review expiry and verifies category coverage.
- **OpenSpec Strict Validation**: `npx --yes @fission-ai/openspec@latest validate --all --strict` ensures all durable capability specifications remain fully compliant.
