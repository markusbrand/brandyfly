## 2024-08-18 - Optimize CustomPainter array reductions
**Learning:** In Flutter, `CustomPainter.paint` loops run at 60Hz. Using `Iterable.reduce` inside `paint` allocates closures and executes an O(N) pass for every `reduce` call (e.g., calling `.reduce` twice for min/max means two O(N) passes and two closure allocations per frame). Over an array of 60 items, this is minor, but for longer histories it can accumulate and trigger garbage collection stutters.
**Action:** Always replace `.reduce` loops inside rendering hot-paths with a single inline `for` loop to compute min/max simultaneously, saving CPU cycles and minimizing allocations. Also, ensure `shouldRepaint` correctly tests properties instead of always returning `true`.

## 2024-08-19 - Lazily parse layout variables to prevent O(N * W) scaling
**Learning:** In Flutter's layout strategies, eagerly parsing arrays (like using `.map(...).toList()` on `history`) for every widget placement causes redundant list allocations and closure creation. Because these widgets build repeatedly based on state updates, this turns an O(N) array allocation per screen into an O(N * W) cost (where N is list size, W is number of widgets).
**Action:** Always parse expensive data (like lists) or read specific keys locally within the specific switch/case or builder where that data is actually used.

## 2026-08-23 - Optimize Paint object allocations in CustomPainter
**Learning:** In Flutter, `CustomPainter.paint()` can be called up to 60-120 times per second. Eagerly allocating `Paint` objects directly inside the `paint()` method causes unnecessary object creation on the hot-path, leading to increased Garbage Collection overhead and potential frame drops (jank).
**Action:** Always instantiate `Paint` objects as `final` properties of the `CustomPainter` class. If properties of the `Paint` (like color) depend on dynamic constructor arguments, initialize the `Paint` object outside, and just update its properties (e.g., `_paint.color = newColor`) inside the `paint()` method.
