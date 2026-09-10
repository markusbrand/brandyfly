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
