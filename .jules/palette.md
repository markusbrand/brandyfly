## 2024-03-24 - Missing tooltips on IconButtons
**Learning:** In the flutter mobile app, many IconButtons are missing the `tooltip` property, which impacts accessibility by not providing context to screen readers or users who long-press.
**Action:** Adding tooltips to all IconButtons that don't have them in `top_nav_bar.dart`, `ui_settings_panel.dart`, `main.dart`, `layout_strategy_container.dart`, and `widget_picker_sheet.dart`.

## 2024-03-24 - Replacing InkWell with IconButton
**Learning:** In Flutter, `InkWell` + `Icon` (often used to tighten hitboxes in cramped layouts) does not announce properly to screen readers and lacks native long-press tooltips.
**Action:** When improving accessibility in tight UI spaces, replace `InkWell` + `Icon` with `IconButton`, adding a `tooltip` and applying `padding: EdgeInsets.zero` (or equivalent tight padding) along with `constraints: const BoxConstraints()` to preserve the compact design while ensuring native screen reader and tooltip support.
