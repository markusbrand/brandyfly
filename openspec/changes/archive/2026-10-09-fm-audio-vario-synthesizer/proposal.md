## Why

Paragliding and hang gliding pilots rely on instantaneous, continuous acoustic vario feedback to sense thermals and airmass movement without keeping their eyes fixed on a display screen. Traditional approaches that play discrete, pre-recorded audio sample files incur significant latency (often 50–200 ms), cause audible clicking/popping artifacts during loop restarts or rapid pitch shifts, and cannot smoothly modulate pitch and pulse duty cycle in response to micro-lift fluctuations.

A zero-latency, continuous frequency-modulated (FM) synthesizer generates audio waveforms directly in real-time on a dedicated audio thread or Web Audio graph, enabling immediate (<10 ms) acoustic response, click-free pitch transitions, dynamic pulse cadences, and nuanced near-thermal sniffer alerts.

## What Changes

- **Continuous FM Audio Synthesis Engine**:
  - Android: Native C++/Kotlin low-latency stream engine using Oboe/AAudio via `plugins/brandyfly_native`.
  - iOS: Native Swift/Objective-C audio engine using `AVAudioEngine` / `AVAudioSourceNode` via `plugins/brandyfly_native`.
  - Web: Web Audio API engine (`AudioContext`, `OscillatorNode`, `GainNode`) with parameter automation curves.
  - Desktop / Linux Fallback: Native or simulated audio synthesizer support for local desktop development.
- **Acoustic Modulation & Mapping**:
  - Lift Range (+0.2 m/s to +8.0 m/s): Continuous tone modulated from 450 Hz to 1800 Hz with beeping pulse rates scaling from 2 Hz (+0.2 m/s) to 12 Hz (+6.0 m/s).
  - Sink Tone (below -1.5 m/s): Continuous low warning drone modulated from 300 Hz down to 180 Hz.
  - Near-Thermal / Sniffer Tone (-0.3 m/s to +0.1 m/s): Optional low-volume pulsing/buzzing tone signaling rising airmass or zero-sink.
- **Dart Audio Vario Service & UI Controls**:
  - `AudioVarioService` in `apps/mobile` consuming `AudioToneCommand` / `AudioToneState` from `crates/flight_core` or telemetry pipelines.
  - User audio settings (master volume, mute toggle, lift/sink threshold customization, sniffer toggle) integrated into `FlightSettings` and UI configuration panels.

## Capabilities

- **Zero-Latency Real-Time Audio**: Continuous sample generation with zero asset file decoding and no loop artifacts.
- **Cross-Platform Parity**: Unified tone behavior and acoustic profile across Android, iOS, Web, and Desktop environments.
- **Configurable Acoustic Profiles**: Pilot-adjustable lift, sink, and near-thermal thresholds, volume levels, and audio mute states.
- **Flight Pipeline Decoupling**: High-frequency audio generation decoupled from Flutter UI render frame rates.

## Non-Goals

- Synthetic speech generation or voice flight metric announcements (e.g., spoken altitude/speed alerts).
- Custom proprietary Bluetooth audio streaming protocol implementations (standard OS Bluetooth A2DP audio routing is used).
- Full musical polyphony; synthesizer focuses strictly on monophonic and modulated vario tone generation.

## Impact

- **`plugins/brandyfly_native`**: Adds native audio synthesis interfaces, method channel / FFI bindings, and platform-specific audio generators.
- **`apps/mobile`**: Adds `AudioVarioService`, audio settings persistence, and UI controls for vario acoustics.
