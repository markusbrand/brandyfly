#![forbid(unsafe_code)]

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
                MockFlightScenarioKind::Nominal,
                "Nominal glide",
                format!(
                    "Altitude {} m, climb {}.2 m/s, speed {} km/h",
                    altitude, lift, speed
                ),
                "Offline tiles cached locally; map interaction enabled".to_string(),
                "Telemetry stream healthy; all dashboard cards updated".to_string(),
                "No alerts; flight state steady".to_string(),
                "Upload queue idle; local export ready".to_string(),
                "IGC preview available with simulated-session marker".to_string(),
                false,
                false,
                0,
            ),
            build_frame(
                &config,
                MockFlightScenarioKind::Offline,
                "Offline validation",
                "Synthetic telemetry continues without any network input".to_string(),
                "Network disabled; cached map tiles and UI snapshots remain available".to_string(),
                "Remote feeds unavailable by design; local flow continues".to_string(),
                "Offline mode acknowledged and handled explicitly".to_string(),
                "Remote upload unavailable; local export preserved".to_string(),
                "Export stays available with offline label".to_string(),
                false,
                false,
                1,
            ),
            build_frame(
                &config,
                MockFlightScenarioKind::Stale,
                "Stale telemetry",
                "Telemetry aged beyond the stale threshold until fresh data resumes".to_string(),
                "Track marker remains visible but marked stale".to_string(),
                "Stale event counted and reported to the operator".to_string(),
                "Degraded state shown until fresh telemetry arrives".to_string(),
                "Replay stays deterministic while stale data is surfaced".to_string(),
                "Export contains stale-state provenance".to_string(),
                true,
                true,
                2,
            ),
            build_frame(
                &config,
                MockFlightScenarioKind::Failure,
                "Injected failure",
                "One upstream dependency times out while unrelated features continue".to_string(),
                "Map remains visible; failed dependency is isolated".to_string(),
                "Structured error recorded for the failed integration point".to_string(),
                "Graceful degradation visible to the operator".to_string(),
                "Failed upstream action leaves local state intact".to_string(),
                "Export includes failure marker and replay hash".to_string(),
                false,
                true,
                3,
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
        let hashes = self
            .frames
            .iter()
            .map(|frame| frame.canonical_event_hash.clone())
            .collect::<Vec<_>>();
        stable_hash(&hashes)
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

fn build_frame(
    config: &LocalMockFlightModeConfig,
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
) -> MockFlightFrame {
    let occurred_at_ms = config.start_time_ms + config.logical_clock_step_ms * step;
    let canonical_event_hash = stable_hash(&[
        config.fixture_version.to_string(),
        config.seed.to_string(),
        config.logical_clock_step_ms.to_string(),
        config.provenance.to_string(),
        kind_name(kind).to_string(),
        title.to_string(),
        telemetry_summary.clone(),
        map_summary.clone(),
        log_summary.clone(),
        alert_summary.clone(),
        upload_summary.clone(),
        export_summary.clone(),
        stale.to_string(),
        degraded.to_string(),
        occurred_at_ms.to_string(),
    ]);

    MockFlightFrame {
        kind,
        title: title.to_string(),
        telemetry_summary,
        map_summary,
        log_summary,
        alert_summary,
        upload_summary,
        export_summary,
        canonical_event_hash,
        occurred_at_ms,
        stale,
        degraded,
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

fn stable_hash(parts: &[String]) -> String {
    const OFFSET: u64 = 0xcbf29ce484222325;
    const PRIME: u64 = 0x100000001b3;
    let mut hash = OFFSET;
    for byte in parts.join("|").bytes() {
        hash ^= u64::from(byte);
        hash = hash.wrapping_mul(PRIME);
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
}
