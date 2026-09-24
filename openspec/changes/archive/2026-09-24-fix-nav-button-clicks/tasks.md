## 1. Navigation Bar Tap Interaction Fixes

- [x] 1.1 Update `ChoiceChip.onSelected` in `_buildScreenSelector` in `top_nav_bar.dart` to unconditionally activate the target screen and dismiss the navigation drawer regardless of incoming boolean state, and verify via widget test.
- [x] 1.2 Wrap `_buildNavBarContent` in `top_nav_bar.dart` with an opaque `GestureDetector` to prevent clicks inside the drawer from falling through to the dismiss barrier or underlying map, and verify tap isolation.
- [x] 1.3 Add `ClampingScrollPhysics` to `SingleChildScrollView` containers in the navigation drawer to prevent micro-drags during clicks from canceling button taps, and verify action button tap reliability.

## 2. Verification and Testing

- [x] 2.1 Run `flutter test test/widgets/top_nav_bar_test.dart` and the mobile test suite to verify navigation interactions pass.
- [x] 2.2 Validate change artifacts with `npx openspec validate --all --strict`.
