## 1. Native Audio Synthesizer Engine (`plugins/brandyfly_native`)
- [ ] 1.1 Implement Android low-latency audio stream using Oboe/AAudio with phase-continuous oscillator and envelope generator
- [ ] 1.2 Implement iOS real-time audio synthesizer using `AVAudioEngine` and `AVAudioSourceNode` with `AVAudioSession` configuration
- [ ] 1.3 Add platform channel and method handlers for synthesizer lifecycle, tone commands, volume, and mute controls in `brandyfly_native`
- [ ] 1.4 Add Linux / desktop fallback synthesizer support for local development and mock mode
- [ ] 1.5 Write unit tests for `brandyfly_native` platform interface and audio parameter mapping

## 2. Web Audio API Synthesizer Implementation
- [ ] 2.1 Implement Web Audio API synthesizer engine with `AudioContext`, `OscillatorNode`, and `GainNode` parameter automation
- [ ] 2.2 Implement browser user-gesture autoplay unlock and lifecycle pause/resume handling
- [ ] 2.3 Implement Dart Web interop bridge connecting `AudioVarioService` to Web Audio synthesis on web targets
- [ ] 2.4 Add automated tests for Web Audio synthesizer state transitions and parameter scheduling

## 3. Acoustic Frequency, Pulse & Tone Mapping Engine
- [ ] 3.1 Implement climb rate frequency mapping (+0.2 to +8.0 m/s -> 450 Hz to 1800 Hz) and beeping pulse rate modulation (2 Hz to 12 Hz)
- [ ] 3.2 Implement continuous sink rate warning drone (below -1.5 m/s, 300 Hz down to 180 Hz)
- [ ] 3.3 Implement optional near-thermal / sniffer tone (-0.3 m/s to +0.1 m/s low-volume buzzing)
- [ ] 3.4 Implement anti-click envelope ramps (attack/decay) and watchdog auto-silence on telemetry stall
- [ ] 3.5 Add unit tests in Dart verifying exact mathematical frequency and cadence mappings across vario ranges

## 4. Dart Audio Vario Service & Core Integration (`apps/mobile`)
- [ ] 4.1 Implement `AudioVarioService` in `apps/mobile/lib/services/` coordinating telemetry updates with platform audio engines
- [ ] 4.2 Integrate `AudioVarioService` with `FlightTrackingService` and `flight_core` tone streams
- [ ] 4.3 Implement app lifecycle listeners for backgrounding, foregrounding, and audio interruptions
- [ ] 4.4 Add unit tests for `AudioVarioService` state management, muting, and error recovery

## 5. Settings, UI Controls & Verification
- [ ] 5.1 Extend `FlightSettings` with audio vario preferences (`varioAudioEnabled`, `varioVolume`, `varioClimbThresholdMs`, `varioSinkThresholdMs`, `varioSnifferEnabled`)
- [ ] 5.2 Add audio vario settings controls (switches, sliders, threshold inputs) to `UiSettingsPanel`
- [ ] 5.3 Add quick-access audio vario mute/unmute button to the flight screen / top navigation bar
- [ ] 5.4 Add widget tests for audio settings and mute button interactions
- [ ] 5.5 Perform end-to-end flight simulation testing in mock flight mode and verify zero-latency sound synthesis
