## 2026-08-19 - [Missing Semantics for Icon Buttons in BrandyFly Flutter UI]
**Learning:** Found an interactive icon element implemented using `InkWell` without any semantic labels or tooltips, which negatively impacts accessibility for screen readers and lacks helpful context for users.
**Action:** When inspecting Flutter custom UI elements, ensure interactive icons (like `InkWell` + `Icon` or `GestureDetector` + `Icon`) are either replaced with `IconButton` that has a `tooltip`, or explicitly wrapped in `Semantics` or `Tooltip` widgets.

## 2026-08-20 - [Text Input Dialog Keyboard UX]
**Learning:** TextField dialogs that require tapping a separate 'Add' button break the natural flow of keyboard input on mobile devices.
**Action:** For Flutter UX consistency in dialogs and forms, configure `TextField` widgets with `autofocus: true`, semantic `textCapitalization`, and bind form submission to `onSubmitted` combined with `textInputAction: TextInputAction.done` to allow users to submit directly via the keyboard.
## 2026-08-21 - [Missing Semantics for Floating Action Buttons]
**Learning:** Found interactive `FloatingActionButton.extended` elements without any semantic `tooltip` properties, which negatively impacts accessibility for screen readers and lacks helpful context for users on hover or long-press.
**Action:** When using `FloatingActionButton.extended` widgets in Flutter, always include the `tooltip` property to ensure accessibility for screen readers and provide helpful context.
