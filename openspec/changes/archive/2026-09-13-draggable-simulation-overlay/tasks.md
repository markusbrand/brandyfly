## 1. Simulation Overlay Drag & Clamping Implementation

- [x] 1.1 Add stateful drag offset and boundary clamping logic to `_MockFlightViewState` in `apps/mobile/lib/main.dart` and verify the widget compiles and builds cleanly.
- [x] 1.2 Wrap the simulation overlay container in a `GestureDetector` with `onPanUpdate` tracking and verify child button taps (`skip_next`, `restart_alt`, minimize/expand) execute without displacing the overlay.
- [x] 1.3 Implement dynamic boundary clamping using parent `BoxConstraints` and `MediaQuery.paddingOf(context)` on drag updates and minimize/expand toggles, verifying the container remains within safe viewport bounds.

## 2. Testing and Verification

- [x] 2.1 Add widget tests in `apps/mobile/test/app_test.dart` testing drag gestures, boundary constraints, button tap precedence, and offset preservation across scenario ticks, verifying all tests pass with `flutter test test/app_test.dart`.
- [x] 2.2 Run static analysis (`dart analyze`) on the mobile codebase to verify clean diagnostics with zero errors and warnings.
- [x] 2.3 Execute `npx openspec validate --all --strict` and verify that all change artifacts and specs pass validation.
