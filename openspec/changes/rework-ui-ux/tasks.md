## 1. Cockpit Design System Foundation

- [ ] 1.1 Create `lib/ui/theme/cockpit_theme.dart` defining high-visibility color tokens, glassmorphism surface styling, and typography scale.
- [ ] 1.2 Build reusable `TelemetryCard` widget with glassmorphism, high contrast text, and subtle inner borders.
- [ ] 1.3 Implement `CockpitNavBar` with glove-friendly 48dp touch targets and active state indicators.

## 2. Animated Vario Instrument & Telemetry Visuals

- [ ] 2.1 Refactor `_VarioGauge` and `_GaugePainter` in `apps/mobile/lib/demo/vario_screen.dart` to support smooth radial sweep animation, climb/sink gradient coding, and thermal core indicators.
- [ ] 2.2 Create smooth `SparklineChart` widget for dynamic altitude profile and climb-rate history rendering.

## 3. Multi-Layout Cockpit Dashboard Views

- [ ] 3.1 Implement `ThermalView` focused on climb rate gradient, altitude MSL, and instantaneous vario trends.
- [ ] 3.2 Implement `CruiseView` focused on ground speed, glide ratio, wind vectors, and altitude sparkline.
- [ ] 3.3 Implement `SplitView` adaptive grid for cockpit phone/tablet flight deck mounts in portrait and landscape orientations.

## 4. Integration & UI/UX Polish

- [ ] 4.1 Update `main.dart` and `vario_screen.dart` to seamlessly integrate new cockpit themes, navigation bar, and view switcher.
- [ ] 4.2 Verify UI responsiveness, touch target sizes, and flutter test suite execution.
