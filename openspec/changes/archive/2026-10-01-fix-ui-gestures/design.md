## Architecture

This is a bug fix that does not alter the underlying architecture. It strictly corrects gesture consumption behavior and pipeline dependency resolution.

## Technical Details

1. **TopNavBarOverlay Touch Fix**:
   - The `TopNavBarOverlay` previously returned a `GestureDetector` that wrapped the entire `Stack` containing the app's content, attempting to capture a swipe down with `onVerticalDragUpdate`.
   - By default, attaching `onVerticalDragUpdate` causes the `GestureDetector` to participate in the gesture arena for the entire screen, stealing vertical drag events from scroll views and the MapLibre view beneath it.
   - The fix removes the outermost `GestureDetector`. The top pull-down handle (already implemented separately as a `Positioned` element at the top edge) safely retains its dedicated `GestureDetector`, which handles both `onTap` and `onVerticalDragUpdate` for just that 48-pixel slice.

2. **Map Pipeline Tools**:
   - `rio-rgbify` on PyPI maxes out at version `0.4.0`. The `requirements.txt` mistakenly requested `>=1.1.0`. Changed to `>=0.4.0`.
   - `Planetiler` relies on `lake_centerlines` shapefiles which it can auto-download using the `--download` flag. This was appended to the subprocess call in `generate_vector_tiles.py`.

## Data Model Changes

None.

## Edge Cases

- **Swipe Area Size**: Users can only open the navbar by interacting with the topmost 48 pixels. This area intentionally does not overlap map controls.