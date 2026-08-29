## 2024-03-24 - Missing tooltips on IconButtons
**Learning:** In the flutter mobile app, many IconButtons are missing the `tooltip` property, which impacts accessibility by not providing context to screen readers or users who long-press.
**Action:** Adding tooltips to all IconButtons that don't have them in `top_nav_bar.dart`, `ui_settings_panel.dart`, `main.dart`, `layout_strategy_container.dart`, and `widget_picker_sheet.dart`.
## 2024-05-19 - Safe IconButton Replacement for InkWell
**Learning:** In Flutter, replacing an `InkWell` containing an `Icon` with an `IconButton` is a great way to improve accessibility (by adding a `tooltip`). However, `IconButton` includes default padding and constraints that can break existing tight layouts.
**Action:** When replacing `InkWell` + `Icon` with `IconButton` in tight layouts, always apply `padding: EdgeInsets.zero` and `constraints: const BoxConstraints()` to the `IconButton` to preserve the original visual sizing while gaining the accessibility benefits.
