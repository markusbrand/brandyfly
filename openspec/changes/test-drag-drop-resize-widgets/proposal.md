## Why

The current flight screen UI configuration is static and inflexible. Pilots need the ability to customize their flight screen layout directly in the app to match their preferences and specific flight situations. They also need to be able to swipe between different screens (e.g., normal flight vs. thermaling), and configure individual widget settings independently rather than having global settings apply to all widgets of the same type.

## What Changes

- Implement drag-and-drop capability for widgets on the flight screen.
- Implement resizing capability for widgets on the flight screen.
- Move widget-specific settings from the global settings page into a widget configuration overlay.
- Make widget settings unique to each instance, rather than globally applying to all widgets of the same type.
- Implement swipe gestures to navigate between different flight screens (except for the automatically triggered thermaling screen).

## Capabilities

### New Capabilities
- `ui/widget-customization`: The ability to resize, drag, and drop widgets on the flight screen, and configure their visual styles individually.
- `ui/screen-navigation`: The ability to swipe horizontally between different configured flight screens.

### Modified Capabilities

## Impact

- Flutter UI layer (screens, widget containers, settings panel)
- UI State Management (ScreenManagerService, UIConfig models)
- **GitHub Issue**: https://github.com/fission-ai/brandyfly/issues/1
