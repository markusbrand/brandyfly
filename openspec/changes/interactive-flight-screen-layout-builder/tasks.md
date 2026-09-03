## 1. Layout Contract & Schema Specification (`packages/contracts`)
- [ ] 1.1 Define the `ScreenLayoutProfile` and `WidgetPlacementSpec` schemas and Rust structures in `packages/contracts/src/screen_layout.rs`
- [ ] 1.2 Add minimum cell constraint definitions and validation logic in `packages/contracts`
- [ ] 1.3 Create JSON schema fixtures for valid and invalid screen layouts in `packages/contracts/fixtures/`
- [ ] 1.4 Implement contract unit tests validating layout serialization, deserialization, and boundary checks

## 2. Fractional Grid Layout Engine (`apps/mobile`)
- [ ] 2.1 Implement `FractionalGridEngine` in `apps/mobile` supporting 8x8 portrait and 12x8 landscape grid systems
- [ ] 2.2 Define widget minimum cell constraints table and boundary clamping in `apps/mobile/lib/models/ui_config.dart`
- [ ] 2.3 Update `ScreenManagerService` to manage fractional grid coordinates, orientation transitions, and placement sanitization
- [ ] 2.4 Add unit tests for `FractionalGridEngine` coordinate conversions, constraint clamping, and orientation adaptations

## 3. Interactive Edit Mode Gestures & Canvas (`apps/mobile`)
- [ ] 3.1 Implement long-press gesture detector on flight screen widgets with haptic feedback to trigger edit mode
- [ ] 3.2 Implement `InteractiveLayoutCanvas` overlay widget with active bounding boxes and draggable anchor handles
- [ ] 3.3 Implement drag-to-move gesture controller with real-time coordinate tracking and grid snapping
- [ ] 3.4 Implement corner-drag and pinch resize gesture controller enforcing minimum widget cell dimensions

## 4. Collision Resolver, Snapping & Swap Feedback (`apps/mobile`)
- [ ] 4.1 Implement real-time collision detection algorithm between active candidate bounds and existing widgets
- [ ] 4.2 Add visual collision feedback overlays (red warning highlights for invalid drops, cyan snap lines for valid grid targets)
- [ ] 4.3 Implement widget swap handle controller to exchange widget coordinates when dropped over existing widgets
- [ ] 4.4 Add edit mode toolbar with discard, reset to default, and save actions

## 5. Profile Export & Import via QR Code and Clipboard (`apps/mobile`)
- [ ] 5.1 Implement `LayoutCodecService` for GZip compression and URL-safe Base64 encoding/decoding of layout profiles
- [ ] 5.2 Implement QR code generator dialog for sharing screen profiles or individual screens
- [ ] 5.3 Implement QR code camera scanner and clipboard import dialog with schema validation and layout preview
- [ ] 5.4 Add unit tests for `LayoutCodecService` encoding, compression ratios, decoding, and error recovery

## 6. Integration, Widget Tests & Verification
- [ ] 6.1 Add widget tests for `InteractiveLayoutCanvas` verifying long-press, drag, resize, and swap interactions
- [ ] 6.2 Add widget tests for QR code generation and clipboard import/export dialogs
- [ ] 6.3 Verify backward compatibility and automatic migration of existing saved UI configurations
- [ ] 6.4 Perform end-to-end flight screen customization in mock flight mode on Linux desktop
