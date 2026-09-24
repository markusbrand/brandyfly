## 1. UI Navigation Fixes

- [x] 1.1 Update `TopNavBarOverlay` gesture container to use `HitTestBehavior.deferToChild` or ignore pointer so taps can reach the `ChoiceChip` widgets. Verify by running the app and successfully switching flight screens via the top navigation chips.

## 2. MapLibre Glyph Configurations

- [x] 2.1 Update `alpine_relief.json` glyphs URL to point to `https://tiles.openfreemap.org/fonts/{fontstack}/{range}.pbf` to prevent missing font errors and `unknown pbf field type` exceptions. Verify by confirming the JSON is syntactically valid.
- [x] 2.2 Define explicit `text-font` fallbacks for `place-omt-labels` (`["Noto Sans Bold"]`) and `mountain-peak-label` (`["Noto Sans Regular"]`). Verify the JSON updates successfully.
- [x] 2.3 Increase `text-size` for `place-omt-labels` to 18 and for `mountain-peak-label` to 15 to ensure readability. Verify by checking the updated MapLibre style JSON.

## 3. Emulation Environment Check

- [x] 3.1 Verify the Android emulator is launched with a hardware GPU backend (`-gpu host`) instead of `swiftshader_indirect` to prevent OpenGL alpha channel corruption of the glyph textures. Verify by checking `ps aux` or emulator boot flags.
