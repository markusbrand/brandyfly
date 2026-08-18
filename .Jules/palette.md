## 2024-03-24 - Missing tooltips on IconButtons
**Learning:** In the flutter mobile app, many IconButtons are missing the `tooltip` property, which impacts accessibility by not providing context to screen readers or users who long-press.
**Action:** Adding tooltips to all IconButtons that don't have them in `top_nav_bar.dart`, `ui_settings_panel.dart`, `main.dart`, `layout_strategy_container.dart`, and `widget_picker_sheet.dart`.
