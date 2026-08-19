## 2026-08-19 - [Missing Semantics for Icon Buttons in BrandyFly Flutter UI]
**Learning:** Found an interactive icon element implemented using `InkWell` without any semantic labels or tooltips, which negatively impacts accessibility for screen readers and lacks helpful context for users.
**Action:** When inspecting Flutter custom UI elements, ensure interactive icons (like `InkWell` + `Icon` or `GestureDetector` + `Icon`) are either replaced with `IconButton` that has a `tooltip`, or explicitly wrapped in `Semantics` or `Tooltip` widgets.
