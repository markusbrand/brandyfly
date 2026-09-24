## 2024-08-18 - Optimize CustomPainter array reductions
**Learning:** In Flutter, `CustomPainter.paint` loops run at 60Hz. Using `Iterable.reduce` inside `paint` allocates closures and executes an O(N) pass for every `reduce` call (e.g., calling `.reduce` twice for min/max means two O(N) passes and two closure allocations per frame). Over an array of 60 items, this is minor, but for longer histories it can accumulate and trigger garbage collection stutters.
**Action:** Always replace `.reduce` loops inside rendering hot-paths with a single inline `for` loop to compute min/max simultaneously, saving CPU cycles and minimizing allocations. Also, ensure `shouldRepaint` correctly tests properties instead of always returning `true`.

## 2024-08-19 - Lazily parse layout variables to prevent O(N * W) scaling
**Learning:** In Flutter's layout strategies, eagerly parsing arrays (like using `.map(...).toList()` on `history`) for every widget placement causes redundant list allocations and closure creation. Because these widgets build repeatedly based on state updates, this turns an O(N) array allocation per screen into an O(N * W) cost (where N is list size, W is number of widgets).
**Action:** Always parse expensive data (like lists) or read specific keys locally within the specific switch/case or builder where that data is actually used.

## 2026-08-23 - Optimize Paint object allocations in CustomPainter
**Learning:** In Flutter, `CustomPainter.paint()` can be called up to 60-120 times per second. Eagerly allocating `Paint` objects directly inside the `paint()` method causes unnecessary object creation on the hot-path, leading to increased Garbage Collection overhead and potential frame drops (jank).
**Action:** Always instantiate `Paint` objects as `final` properties of the `CustomPainter` class. If properties of the `Paint` (like color) depend on dynamic constructor arguments, initialize the `Paint` object outside, and just update its properties (e.g., `_paint.color = newColor`) inside the `paint()` method.

## 2024-08-24 - Prevent Unconditional Repaints in CustomPainter
**Learning:** In Flutter, `CustomPainter.shouldRepaint` checks that rely on reference equality (`oldDelegate.property != property`) for lists will cause unconditional repaints on every layout frame if the parent widget is reallocating the list during `build` (such as `.toList()` from dynamic JSON arrays).
**Action:** Always use `listEquals(oldDelegate.list, list)` from `package:flutter/foundation.dart` for deep equality comparison of list properties in `shouldRepaint` methods to avoid expensive, unnecessary canvas redraws.

## 2024-08-26 - CustomPainter and `const` Constructors vs Caching `Paint`
**Learning:** In Flutter `CustomPainter` implementations, caching `Paint` objects as `final` class properties prevents per-frame allocations during `paint()`. However, because `Paint` cannot be `const`, doing this forces the painter constructor to become non-const. If the parent widget passes fixed data (like a completed flight track) and originally instantiated the painter with `const`, making the constructor non-const will inadvertently force the entire painter object (and the `Paint` object) to be reallocated on every `build()`.
**Action:** Before converting a `const` painter to cache a non-const `Paint`, evaluate the lifecycle. If the parent widget is frequently rebuilding but passing static data, preserving the `const` constructor may be more efficient than caching the `Paint` locally inside the `paint()` method.

## 2024-08-26 - Large Lists and `listEquals` vs Reference Equality in `shouldRepaint`
**Learning:** In Flutter `CustomPainter.shouldRepaint` methods, using `listEquals()` for large list properties (like a flight track with thousands of points) introduces an O(N) operation on the main UI thread during every rebuild, causing severe UI stuttering.
**Action:** Prefer reference equality (`!=`) over `listEquals()` for large list properties in `shouldRepaint` when it is safe to assume the parent widget uses immutable updates (i.e. it passes a new list instance when state changes, rather than mutating an existing list).

## 2026-03-31 - Table-driven CRC32 calculation in flight recorder
**Learning:** Naive bit-by-bit CRC32 evaluation loops over every byte 8 times with branching bit-shifts, causing high CPU overhead during high-frequency telemetry recording. A 256-entry lookup table precomputed at compile time replaces the inner 8-iteration loop with single-step byte indexing and table lookup.
**Action:** Always use a 256-entry lookup table for standard CRC32 checksum calculations to achieve ~3.2x throughput improvement without external dependencies.

## 2026-09-08 - Use `repaint` Listenable in CustomPainter instead of AnimatedBuilder
**Learning:** In Flutter, wrapping a `CustomPaint` widget inside an `AnimatedBuilder` to force it to redraw during animations causes the entire `CustomPaint` widget to be rebuilt and the `CustomPainter` to be re-allocated on every single frame.
**Action:** Always pass the `Animation` or `Listenable` directly to the `CustomPainter`'s constructor and forward it to `super(repaint: animation)`. The painter will automatically trigger canvas redraws when the animation ticks without needing the parent widget to rebuild. Ensure you then access the animation's `.value` directly inside the `paint()` method.

## 2026-09-09 - Avoid vector allocations for string splitting in Rust frame parsers
**Learning:** Calling `.split(',').collect::<Vec<&str>>()` when parsing frame payloads creates heap allocations per packet. In high-frequency frame parsing hot-paths (e.g. 20-100Hz telemetry feeds), this creates unnecessary heap allocation overhead.
**Action:** Use string split iterators (`str::split(',')`) directly with `impl Iterator<Item = &str>` parameter signatures and `.next()`, eliminating heap vector allocations and boosting parsing throughput.

## 2026-09-09 - Zero-allocation ASCII case-insensitive search in protocol parsing
**Learning:** In Rust protocol parsing hot paths, calling `.to_lowercase()` on string/byte payloads allocates a new heap `String` on every incoming frame. When matching against ASCII markers (e.g. credential tokens or NMEA sentence headers), checking slices directly with `as_bytes().windows().any(|w| w.eq_ignore_ascii_case(needle.as_bytes()))` eliminates all heap allocations and avoids Unicode conversion overhead.
**Action:** Never use `.to_lowercase()` to perform case-insensitive ASCII pattern matching on incoming byte streams. Use zero-allocation slice windows with `.eq_ignore_ascii_case()` instead.

## 2026-09-09 - Avoid `Vec::remove(0)` in Bounded Queue Operations
**Learning:** Using `Vec::remove(0)` to drop the oldest item or pop elements from the front of a queue shifts every subsequent element in memory, resulting in O(N) operations per push/pop when capacity is reached. Switching the underlying storage to `VecDeque` converts `pop_front()` and `push_back()` into O(1) ring buffer operations.
**Action:** Always use `std::collections::VecDeque` instead of `Vec` for FIFO queues or bounded buffers where items are inserted at the back and removed from the front.
## 2026-09-22 - Fix per-frame Paint allocation in for loop
**Learning:** In Flutter `CustomPainter.paint` loops, when drawing large amounts of dynamic elements like points on a map using a `for` loop, allocating a new `Paint` object for every element dynamically creates massive Garbage Collection churn per frame, especially at 60Hz.
**Action:** Always allocate mutable `Paint` objects outside of iteration loops (or cache them) and update only the necessary properties (e.g. `color`) inside the loop before passing the `Paint` object to Canvas operations.

## 2026-09-22 - Prevent unconditional repaints via exhaustive equality check
**Learning:** `CustomPainter.shouldRepaint` that unconditionally returns `true` skips Flutter's optimization layers, causing it to repaint on every rebuild of the tree, even when the widget data hasn't changed.
**Action:** Always verify all passed-in fields inside `shouldRepaint` by checking for field equality. When lists are immutable in state management, reference equality (`!=`) works well to avoid expensive repaints.

## 2026-09-24 - Verification of Paint Object Reuse in CustomPainter Loops
**Learning:** In Flutter `CustomPainter.paint` loops, instantiating `Paint` objects inside `for` loops (e.g. for flight track polyline segments) creates massive per-frame heap allocations and Garbage Collection pressure on 60Hz hot paths. Instantiating a single `Paint` object outside the loop and updating its properties (e.g., `trackPaint.color = color`) per iteration eliminates heap churn while preserving rendering behavior.
**Action:** Always instantiate `Paint` objects outside iteration loops in `CustomPainter` methods and mutate properties in-place inside loops.
## 2024-09-24 - Prevent per-frame allocation of Paint/Path objects without breaking const constructor
**Learning:** In Flutter, allocating `Paint` or `Path` objects directly within a `CustomPainter`'s `paint()` method causes excessive Garbage Collection churn and stutter, especially at 60Hz. While caching them as `final` instance fields solves this, it prevents the painter from having a `const` constructor, which causes the entire painter object to be reallocated by the parent on every frame if the parent frequently rebuilds.
**Action:** When a `CustomPainter` takes static data but is embedded in a rapidly rebuilding parent, preserve the `const` constructor by caching the `Paint` and `Path` objects as `static final` class fields rather than instance fields, assuming the painting configuration is identical across all instances.
## 2026-09-24 - Cache layout canvas bounds on immutable screen models
**Learning:** In Flutter layout strategy builders, calculating screen bounds (such as `maxBottomGrid`) via an O(N) loop over all screen widgets inside `LayoutBuilder` executes on every frame rebuild, window resize, edit mode toggle, and telemetry tick. Because `FlightScreenModel` is an immutable data class updated via `copyWith`, re-computing layout bounds on every build pass is redundant.
**Action:** Compute and cache layout bounds (`maxBottomGrid`) on the immutable screen model when instantiated or copied (via `copyWith`), transforming repeated O(N) layout iterations into O(1) property accesses in the hot layout path.
## 2026-09-23 - Precalculate min/max bounds and loop-invariant scaling in sparkline painters
**Learning:** Performing multiple list iterations inside `CustomPainter.paint()` (e.g. one O(N) pass to calculate min/max bounds and a second pass to construct the `Path`) wastes CPU cycles on every frame paint. Furthermore, evaluating loop-invariant scaling math inside the path construction loop redundantly re-computes offsets for every element.
**Action:** Move min/max and range calculations to constructor initializer list / static helper functions so bounds are calculated once per painter instantiation. In addition, factor out loop-invariant scaling constants (`scaleY` and base offsets) before starting the path construction loop.
## 2026-09-24 - Single-Pass Longitude Wrapping Modulo Math
**Learning:** Replacing while loops for floating-point longitude wrapping with modulo math `(lng + 180.0) % 360.0 - 180.0` provides a constant O(1) single-expression computation.
**Action:** Use `(lng + 180.0) % 360.0 - 180.0` for geographic longitude normalization across map panning and telemetry processing routines.
## 2026-09-24 - Thermal Map Loop DateTime Benchmark Findings
**Learning:** In Dart/AOT, `DateTime.difference()` is implemented natively and optimized at the VM level. Pre-computing or caching integer timestamp fields (`millisecondsSinceEpoch`) or hoisting simple arithmetic outside loops can actually degrade performance due to additional field accesses, object overhead, or VM optimization disruption.
**Action:** Always benchmark proposed micro-optimizations in Dart before applying them; do not assume integer timestamps or manual loop hoisting are faster than native Dart `DateTime` arithmetic.
