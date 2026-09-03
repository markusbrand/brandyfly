## ADDED Requirements

### Requirement: Continuous FM audio synthesis engine for mobile and web
The system SHALL provide real-time continuous waveform audio synthesis without pre-recorded audio sample playback or click/pop artifacts, leveraging low-latency native audio streams on mobile (Oboe/AAudio on Android, AVAudioEngine on iOS) and the Web Audio API (`AudioContext` with `OscillatorNode` / `GainNode`) on web platforms.

#### Scenario: Real-time tone synthesis on mobile platforms
- **WHEN** the audio vario engine receives an audio command on Android or iOS
- **THEN** the native synthesizer updates waveform generation parameters in the active low-latency audio stream with under 15 ms latency
- **AND** generates clean, continuous sine/triangle waves without audible clicking or sample buffer looping artifacts

#### Scenario: Real-time tone synthesis on Web platforms
- **WHEN** BrandyFly runs in a web browser environment
- **THEN** the audio engine utilizes Web Audio API `AudioContext`, `OscillatorNode`, and `GainNode` with scheduled parameter automation ramps
- **AND** responds to vario tone commands without blocking the browser UI thread

### Requirement: Climb rate frequency and pulse modulation
The audio synthesizer SHALL modulate audio frequency from 450 Hz to 1800 Hz for positive climb rates between +0.2 m/s and +8.0 m/s, and SHALL modulate pulse beeping frequency from 2 Hz (+0.2 m/s) up to 12 Hz (+6.0 m/s) with a dynamic duty cycle.

#### Scenario: Synthesizing weak climb
- **WHEN** the vertical speed is +0.2 m/s (minimum lift threshold)
- **THEN** the synthesizer produces beeps at 450 Hz with a pulse rate of 2 Hz (period of 500 ms) and approximately 50% duty cycle

#### Scenario: Synthesizing strong climb
- **WHEN** the vertical speed reaches +6.0 m/s or higher
- **THEN** the synthesizer produces high-pitched beeps at or above 1600 Hz (up to 1800 Hz at +8.0 m/s) with a rapid pulse rate of 12 Hz
- **AND** smooth pitch-bend transitions occur between consecutive climb updates without phase discontinuities

### Requirement: Sink rate warning tone
The audio synthesizer SHALL generate a continuous low-frequency warning drone between 300 Hz and 180 Hz when the vertical speed drops below -1.5 m/s.

#### Scenario: Transitioning into sink
- **WHEN** the vertical speed drops below -1.5 m/s (sink threshold)
- **THEN** the synthesizer outputs a continuous (100% duty cycle) tone starting at 300 Hz and decreasing linearly down to 180 Hz as sink intensifies

#### Scenario: Recovering from sink to neutral air
- **WHEN** the vertical speed rises above -1.5 m/s into neutral flight
- **THEN** the synthesizer smoothly fades out the sink drone and silences the output without popping artifacts

### Requirement: Near-thermal and sniffer tone modulation
The audio synthesizer SHALL provide an optional low-volume sniffer/near-thermal acoustic tone between -0.3 m/s and +0.1 m/s to indicate rising airmass or zero sink when enabled by the pilot.

#### Scenario: Flying through near-thermal zero-sink airmass with sniffer enabled
- **WHEN** vertical speed is between -0.3 m/s and +0.1 m/s and the sniffer tone setting is enabled
- **THEN** the synthesizer emits a distinctive low-volume buzzing/clicking cadence (e.g., 400–450 Hz with low duty cycle) to alert the pilot of buoyant air

#### Scenario: Sniffer tone disabled
- **WHEN** vertical speed is between -0.3 m/s and +0.1 m/s but the sniffer tone is disabled in settings
- **THEN** the synthesizer remains completely silent

### Requirement: Audio settings, volume control, and mute management
The application SHALL allow pilots to adjust master audio vario volume, toggle mute state, customize lift/sink thresholds, and persist audio preferences across app restarts.

#### Scenario: Muting audio vario during flight
- **WHEN** the pilot taps the audio vario mute button
- **THEN** the audio output is immediately silenced
- **AND** resuming audio unmutes synthesis without restarting the flight tracking session

#### Scenario: Updating audio settings during active flight
- **WHEN** the pilot modifies the lift threshold or volume in flight settings
- **THEN** the changes apply immediately to the audio vario synthesis engine without interrupting sensor tracking
