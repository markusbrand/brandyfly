## 2024-05-18 - Accessibility of Custom Interactive Regions
**Learning:** Raw `GestureDetector` widgets used for drag handles and custom interactive overlays (like swipe-to-expand controls) are invisible to screen readers unless explicitly wrapped.
**Action:** Always wrap `GestureDetector` based interactive regions with a `Semantics` widget, setting `button: true` and a descriptive `label` that indicates its purpose and current state (e.g., "Expand controls").
