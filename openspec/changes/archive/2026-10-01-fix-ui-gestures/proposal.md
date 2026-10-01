## Why

The application currently intercepts all vertical drag gestures and taps across the entire screen due to a rogue `GestureDetector` in the `TopNavBarOverlay`. This prevents users from interacting with the map, scrollable widgets, or accessing other functionalities, making the app effectively unusable (appearing as a frozen screen). Additionally, the map pipeline failed to execute because it used deprecated package requirements and lacked an auto-download flag for the vector tile engine.

## What Changes

- Remove the global `GestureDetector` wrapper in `TopNavBarOverlay` that was incorrectly placed around the main `Stack`.
- Correct the syntax where `GestureDetector` was replaced by `Stack` but left dangling parentheses.
- Add `--download` flag to `Planetiler` invocation in `tools/map-pipeline/generate_vector_tiles.py`.
- Update `rio-rgbify` version requirement in `tools/map-pipeline/requirements.txt` from `>=1.1.0` to `>=0.4.0` due to a PyPI versioning mismatch.

## Capabilities

### New Capabilities
None.

### Modified Capabilities
None.

## Impact

- **UI**: The app's main view and map are fully interactive again.
- **Tooling**: The offline map generation pipeline now correctly resolves dependencies and automatically downloads missing Java utilities to complete its run successfully.