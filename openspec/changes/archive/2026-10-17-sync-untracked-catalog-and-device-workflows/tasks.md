## 1. Offline Region Management & Catalog Fallback

- [x] 1.1 Verify RegionManagerService loads bundled assets/map_data/catalog.json when offline with no local cache
- [x] 1.2 Validate catalog parsing and region list display in unit tests

## 2. Thermal Prefetch Bounds & Threshold Protection

- [x] 2.1 Verify RegionBoundsProvider extracts valid bounds from regional meta.json
- [x] 2.2 Verify ThermalPrefetchService skips prefetch when calculated tile count exceeds 25,000 tiles

## 3. Device Workflows Documentation & Conventions

- [x] 3.1 Verify AGENTS.md, GEMINI.md, and docs/development.md reflect accurate macOS iOS Simulator / Device Hub conventions
- [x] 3.2 Verify execution target conventions for Garuda PC local GPU emulator

## 4. Verification & Validation

- [x] 4.1 Run unit and widget tests for region management and thermal prefetch
- [x] 4.2 Run OpenSpec strict validation across all changes and specifications
