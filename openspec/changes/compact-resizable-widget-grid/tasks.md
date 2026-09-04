## 1. UI Model & Default Presets

- [x] 1.1 Update `UIConfig.defaultConfig()` screen presets to use 8-column grid coordinates and verify models serialize and deserialize correctly
- [x] 1.2 Add automatic 4-to-8 column coordinate migration in `FlightScreenModel.fromJson` to ensure backward compatibility for saved presets and verify with unit tests

## 2. Screen Manager Service Coordinate System

- [x] 2.1 Update `ScreenManagerService` bounds clamping (`w.clamp(1, 8)`, `h.clamp(1, 16)`, `x.clamp(0, 8 - w)`) and default widget dimensions
- [x] 2.2 Update and expand `test/screen_manager_test.dart` to cover 8-column move, resize, and boundary enforcement

## 3. High-Density Layout Container & Adaptive Edit Controls

- [x] 3.1 Update `LayoutStrategyContainer` to use 8-column grid width (`totalWidth / 8`), lower minimum row height floor to 38px, and update grid guide lines
- [x] 3.2 Adapt `_WidgetEditFrame` header, nudge/stepper buttons, and corner drag handle to scale down cleanly on compact widgets without clipping content
- [x] 3.3 Update widget tune configuration dialog position and size controls to support the 8-column range
- [x] 3.4 Verify responsive scaling in `NumericTextWidget`, `VarioLiftSinkBar`, `WindDirectionWidget`, and `AltitudeSparklineChart` for compact cell bounds

## 4. Verification & Validation

- [x] 4.1 Run full Flutter test suite (`flutter test`) in `apps/mobile` to ensure all unit and widget tests pass
- [x] 4.2 Run `npx openspec validate --all --strict` to verify OpenSpec schema compliance across all artifacts
