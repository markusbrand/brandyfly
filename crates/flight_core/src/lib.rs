#![forbid(unsafe_code)]

pub mod benchmark;
pub mod bounded_pipeline;

pub mod durable_recorder;
pub mod procedural_generator;
pub mod replay_fixtures;

pub use benchmark::{BenchmarkConfig, run_pipeline_benchmark};
pub use bounded_pipeline::{
    AudioToneCommand, AudioToneState, BoundedEventQueue, BoundedFlightPipeline, KpiSnapshot,
    LatestValueAudioControl, OverflowPolicy, RateLimitedKpiPublisher,
};
pub use durable_recorder::{
    DurableFlightRecorder, FlightRecordFrame, MAX_RECORD_PAYLOAD_SIZE, RECORDER_MAGIC,
    RecoveryReport, calculate_crc32, recover_flight_records,
};
pub use procedural_generator::{ProceduralFlightGenerator, ProceduralManeuver, TelemetrySource};
pub use replay_fixtures::{
    SkyDrop1ReplayGenerator, SkyDrop1ReplayScenario, SyntheticReplayGenerator,
    SyntheticReplayScenario, replay_skydrop1_sequence,
};

/// Version of the public flight-core contract.
pub const CORE_API_VERSION: u16 = 1;

/// Returns the public contract version exposed by this crate.
#[must_use]
pub const fn core_api_version() -> u16 {
    CORE_API_VERSION
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct LocalMockFlightModeConfig {
    pub enabled: bool,
    pub fixture_version: &'static str,
    pub seed: u64,
    pub logical_clock_step_ms: u64,
    pub start_time_ms: u64,
    pub provenance: &'static str,
    pub session_label: &'static str,
}

impl LocalMockFlightModeConfig {
    #[must_use]
    pub const fn new(
        enabled: bool,
        fixture_version: &'static str,
        seed: u64,
        logical_clock_step_ms: u64,
        start_time_ms: u64,
        provenance: &'static str,
        session_label: &'static str,
    ) -> Self {
        Self {
            enabled,
            fixture_version,
            seed,
            logical_clock_step_ms,
            start_time_ms,
            provenance,
            session_label,
        }
    }

    #[must_use]
    pub const fn disabled() -> Self {
        Self::new(
            false,
            "mock-flight-v1",
            1,
            1_000,
            0,
            "synthetic-anonymized",
            "simulated",
        )
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum MockFlightScenarioKind {
    Nominal,
    Offline,
    Stale,
    Failure,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct MockFlightFrame {
    pub kind: MockFlightScenarioKind,
    pub title: String,
    pub telemetry_summary: String,
    pub map_summary: String,
    pub log_summary: String,
    pub alert_summary: String,
    pub upload_summary: String,
    pub export_summary: String,
    pub canonical_event_hash: String,
    pub occurred_at_ms: u64,
    pub stale: bool,
    pub degraded: bool,
}

impl MockFlightFrame {
    #[must_use]
    pub fn session_marker(&self) -> String {
        format!(
            "SIMULATED_SESSION:{:?}:{}",
            self.kind, self.canonical_event_hash
        )
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct MockFlightReplay {
    config: LocalMockFlightModeConfig,
    frames: Vec<MockFlightFrame>,
}

impl MockFlightReplay {
    #[must_use]
    pub fn new(config: LocalMockFlightModeConfig) -> Self {
        let mut rng = XorShift32::new(config.seed as u32);
        let altitude = 1200 + rng.next_range(0, 420);
        let speed = 18 + rng.next_range(0, 17);
        let lift = 1 + rng.next_range(0, 5);

        let frames = vec![
            build_frame(
                &config,
                FrameSpec {
                    kind: MockFlightScenarioKind::Nominal,
                    title: "Nominal glide",
                    telemetry_summary: format!(
                        "Altitude {} m, climb {}.2 m/s, speed {} km/h",
                        altitude, lift, speed
                    ),
                    map_summary: "Offline tiles cached locally; map interaction enabled"
                        .to_string(),
                    log_summary: "Telemetry stream healthy; all dashboard cards updated"
                        .to_string(),
                    alert_summary: "No alerts; flight state steady".to_string(),
                    upload_summary: "Upload queue idle; local export ready".to_string(),
                    export_summary: "IGC preview available with simulated-session marker"
                        .to_string(),
                    stale: false,
                    degraded: false,
                    step: 0,
                },
            ),
            build_frame(
                &config,
                FrameSpec {
                    kind: MockFlightScenarioKind::Offline,
                    title: "Offline validation",
                    telemetry_summary: "Synthetic telemetry continues without any network input"
                        .to_string(),
                    map_summary:
                        "Network disabled; cached map tiles and UI snapshots remain available"
                            .to_string(),
                    log_summary: "Remote feeds unavailable by design; local flow continues"
                        .to_string(),
                    alert_summary: "Offline mode acknowledged and handled explicitly".to_string(),
                    upload_summary: "Remote upload unavailable; local export preserved".to_string(),
                    export_summary: "Export stays available with offline label".to_string(),
                    stale: false,
                    degraded: false,
                    step: 1,
                },
            ),
            build_frame(
                &config,
                FrameSpec {
                    kind: MockFlightScenarioKind::Stale,
                    title: "Stale telemetry",
                    telemetry_summary:
                        "Telemetry aged beyond the stale threshold until fresh data resumes"
                            .to_string(),
                    map_summary: "Track marker remains visible but marked stale".to_string(),
                    log_summary: "Stale event counted and reported to the operator".to_string(),
                    alert_summary: "Degraded state shown until fresh telemetry arrives".to_string(),
                    upload_summary: "Replay stays deterministic while stale data is surfaced"
                        .to_string(),
                    export_summary: "Export contains stale-state provenance".to_string(),
                    stale: true,
                    degraded: true,
                    step: 2,
                },
            ),
            build_frame(
                &config,
                FrameSpec {
                    kind: MockFlightScenarioKind::Failure,
                    title: "Injected failure",
                    telemetry_summary:
                        "One upstream dependency times out while unrelated features continue"
                            .to_string(),
                    map_summary: "Map remains visible; failed dependency is isolated".to_string(),
                    log_summary: "Structured error recorded for the failed integration point"
                        .to_string(),
                    alert_summary: "Graceful degradation visible to the operator".to_string(),
                    upload_summary: "Failed upstream action leaves local state intact".to_string(),
                    export_summary: "Export includes failure marker and replay hash".to_string(),
                    stale: false,
                    degraded: true,
                    step: 3,
                },
            ),
        ];

        Self { config, frames }
    }

    #[must_use]
    pub fn frames(&self) -> &[MockFlightFrame] {
        &self.frames
    }

    #[must_use]
    pub fn canonical_replay_hash(&self) -> String {
        stable_hash(self.frames.iter().map(|frame| &frame.canonical_event_hash))
    }

    #[must_use]
    pub fn export_summary(&self) -> String {
        let frame = &self.frames[0];
        format!(
            "SIMULATED_SESSION={}\nfixture={}\nseed={}\nclock_step_ms={}\nprovenance={}\nphase={:?}\nevent_hash={}",
            self.config.session_label,
            self.config.fixture_version,
            self.config.seed,
            self.config.logical_clock_step_ms,
            self.config.provenance,
            frame.kind,
            frame.canonical_event_hash
        )
    }
}

struct FrameSpec {
    kind: MockFlightScenarioKind,
    title: &'static str,
    telemetry_summary: String,
    map_summary: String,
    log_summary: String,
    alert_summary: String,
    upload_summary: String,
    export_summary: String,
    stale: bool,
    degraded: bool,
    step: u64,
}

fn build_frame(config: &LocalMockFlightModeConfig, spec: FrameSpec) -> MockFlightFrame {
    let occurred_at_ms = config.start_time_ms + config.logical_clock_step_ms * spec.step;
    let seed_str = config.seed.to_string();
    let clock_step_str = config.logical_clock_step_ms.to_string();
    let stale_str = spec.stale.to_string();
    let degraded_str = spec.degraded.to_string();
    let occurred_at_str = occurred_at_ms.to_string();

    let canonical_event_hash = stable_hash([
        config.fixture_version,
        &seed_str,
        &clock_step_str,
        config.provenance,
        kind_name(spec.kind),
        spec.title,
        &spec.telemetry_summary,
        &spec.map_summary,
        &spec.log_summary,
        &spec.alert_summary,
        &spec.upload_summary,
        &spec.export_summary,
        &stale_str,
        &degraded_str,
        &occurred_at_str,
    ]);

    MockFlightFrame {
        kind: spec.kind,
        title: spec.title.to_string(),
        telemetry_summary: spec.telemetry_summary,
        map_summary: spec.map_summary,
        log_summary: spec.log_summary,
        alert_summary: spec.alert_summary,
        upload_summary: spec.upload_summary,
        export_summary: spec.export_summary,
        canonical_event_hash,
        occurred_at_ms,
        stale: spec.stale,
        degraded: spec.degraded,
    }
}

fn kind_name(kind: MockFlightScenarioKind) -> &'static str {
    match kind {
        MockFlightScenarioKind::Nominal => "nominal",
        MockFlightScenarioKind::Offline => "offline",
        MockFlightScenarioKind::Stale => "stale",
        MockFlightScenarioKind::Failure => "failure",
    }
}

fn stable_hash<I, S>(parts: I) -> String
where
    I: IntoIterator<Item = S>,
    S: AsRef<str>,
{
    const OFFSET: u64 = 0xcbf29ce484222325;
    const PRIME: u64 = 0x100000001b3;
    let mut hash = OFFSET;
    let mut first = true;
    for part in parts {
        if !first {
            hash ^= u64::from(b'|');
            hash = hash.wrapping_mul(PRIME);
        }
        first = false;
        for byte in part.as_ref().bytes() {
            hash ^= u64::from(byte);
            hash = hash.wrapping_mul(PRIME);
        }
    }
    format!("{hash:016x}")
}

#[derive(Clone, Copy, Debug)]
struct XorShift32 {
    state: u32,
}

impl XorShift32 {
    fn new(seed: u32) -> Self {
        Self {
            state: if seed == 0 { 0x6d2b79f5 } else { seed },
        }
    }

    fn next(&mut self) -> u32 {
        let mut value = self.state;
        value ^= value << 13;
        value ^= value >> 17;
        value ^= value << 5;
        self.state = value;
        value
    }

    fn next_range(&mut self, min_inclusive: u32, max_exclusive: u32) -> u32 {
        assert!(max_exclusive > min_inclusive);
        min_inclusive + (self.next() % (max_exclusive - min_inclusive))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn reports_the_current_api_version() {
        assert_eq!(core_api_version(), 1);
    }

    #[test]
    fn replay_is_deterministic_for_identical_inputs() {
        let config = LocalMockFlightModeConfig::new(
            true,
            "mock-flight-v1",
            7,
            1_000,
            1_700,
            "synthetic-anonymized",
            "simulated",
        );
        let first = MockFlightReplay::new(config.clone());
        let second = MockFlightReplay::new(config);

        assert_eq!(first, second);
        assert_eq!(
            first.canonical_replay_hash(),
            second.canonical_replay_hash()
        );
    }

    #[test]
    fn replay_hash_changes_when_seed_changes() {
        let first = MockFlightReplay::new(LocalMockFlightModeConfig::new(
            true,
            "mock-flight-v1",
            7,
            1_000,
            1_700,
            "synthetic-anonymized",
            "simulated",
        ));
        let second = MockFlightReplay::new(LocalMockFlightModeConfig::new(
            true,
            "mock-flight-v1",
            8,
            1_000,
            1_700,
            "synthetic-anonymized",
            "simulated",
        ));

        assert_ne!(
            first.canonical_replay_hash(),
            second.canonical_replay_hash()
        );
    }

    #[test]
    fn disabled_config_initializes_with_expected_defaults() {
        let config = LocalMockFlightModeConfig::disabled();
        assert!(!config.enabled);
        assert_eq!(config.seed, 1);
        assert_eq!(config.logical_clock_step_ms, 1_000);
        assert_eq!(config.provenance, "synthetic-anonymized");
        assert_eq!(config.session_label, "simulated");
    }

    #[test]
    fn export_summary_and_session_markers_format_correctly() {
        let config = LocalMockFlightModeConfig::new(
            true,
            "mock-flight-v1",
            42,
            1_000,
            0,
            "synthetic-anonymized",
            "simulated",
        );
        let replay = MockFlightReplay::new(config);
        let frames = replay.frames();

        assert_eq!(frames.len(), 4);
        assert_eq!(frames[0].kind, MockFlightScenarioKind::Nominal);
        assert_eq!(frames[1].kind, MockFlightScenarioKind::Offline);
        assert_eq!(frames[2].kind, MockFlightScenarioKind::Stale);
        assert_eq!(frames[3].kind, MockFlightScenarioKind::Failure);

        let marker = frames[0].session_marker();
        assert!(marker.starts_with("SIMULATED_SESSION:Nominal:"));

        let summary = replay.export_summary();
        assert!(summary.contains("SIMULATED_SESSION=simulated"));
        assert!(summary.contains("fixture=mock-flight-v1"));
        assert!(summary.contains("seed=42"));
        assert!(summary.contains("phase=Nominal"));
    }
}
