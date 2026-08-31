## 2024-03-24 - Missing tooltips on IconButtons
**Learning:** In the flutter mobile app, many IconButtons are missing the `tooltip` property, which impacts accessibility by not providing context to screen readers or users who long-press.
**Action:** Adding tooltips to all IconButtons that don't have them in `top_nav_bar.dart`, `ui_settings_panel.dart`, `main.dart`, `layout_strategy_container.dart`, and `widget_picker_sheet.dart`.

## 2024-03-24 - Replacing InkWell with IconButton
**Learning:** In Flutter, `InkWell` + `Icon` (often used to tighten hitboxes in cramped layouts) does not announce properly to screen readers and lacks native long-press tooltips.
**Action:** When improving accessibility in tight UI spaces, replace `InkWell` + `Icon` with `IconButton`, adding a `tooltip` and applying `padding: EdgeInsets.zero` (or equivalent tight padding) along with `constraints: const BoxConstraints()` to preserve the compact design while ensuring native screen reader and tooltip support.
## 2024-03-24 - Replacing InkWell with IconButton (Constraints & Splash)
**Learning:** When replacing `InkWell` inside a loosely constrained parent (like `Alignment.center`) with `IconButton` using `padding: EdgeInsets.zero` to preserve a tight layout, you must use explicit constraints (e.g., `constraints: const BoxConstraints.tightFor(width: 32, height: 32)`) rather than an empty `BoxConstraints()`. An empty `BoxConstraints()` allows the touch target to shrink to the size of the icon itself. Additionally, explicitly setting a `splashRadius` helps avoid visual clipping artifacts inside small rounded rectangles.
**Action:** When migrating `InkWell` to `IconButton` for tight UI components, always specify exact width/height constraints on the `IconButton` and provide an appropriate `splashRadius`.
