## 1. Network & Platform Configuration

- [x] 1.1 Add `NSAllowsLocalNetworking: true` under `NSAppTransportSecurity` in `apps/mobile/ios/Runner/Info.plist` and verify with `plutil -lint apps/mobile/ios/Runner/Info.plist`

## 2. Dynamic Upstream Snapshot Resolution & Disk Cache

- [x] 2.1 Update `LocalTileServer` with dynamic OpenFreeMap snapshot discovery (`https://tiles.openfreemap.org/planet`) and a resilient static snapshot fallback template (`/planet/20260906_080001_pt/{z}/{x}/{y}.pbf`), verifying that valid non-empty vector tile payloads are retrieved
- [x] 2.2 Implement persistent disk caching for proxied vector tiles under `cache/vector_tiles/{z}/{x}/{y}.pbf` in `LocalTileServer` and verify cached tiles are served on subsequent requests without network access
- [x] 2.3 Implement timeout protection (<= 3s) on upstream requests in `LocalTileServer` returning HTTP 204 No Content when disconnected, and verify offline resilience with unit tests

## 3. MapLibre Integration & UI Indicator

- [x] 3.1 Expose `isOnlinePreviewActive` on `LocalTileServer` and `MapLibreMapService` to signal when vector tiles are actively served via online proxy
- [x] 3.2 Update `MapWidget` header status badge to render `"Online preview (No offline data)"` when streaming online tiles vs. `"No offline data (Overview fallback)"` when disconnected or empty, and verify with widget tests

## 4. Verification & Validation

- [x] 4.1 Run automated test suite (`flutter test test/services/local_tile_server_test.dart test/map_widget_integration_test.dart`) and verify all tests pass
- [x] 4.2 Run `npx openspec validate online-map-dev-fallback --strict` and verify complete change coherence
- [x] 4.3 Hot-restart the running app on the iOS simulator and capture a screenshot verifying live OpenStreetMap vector tiles render on screen
