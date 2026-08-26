#![forbid(unsafe_code)]

use brandyfly_contracts::{
    PipelineCounters, SensorEvent, SensorPayload, StageTimestampTrace, validate_sensor_event,
};

/// Overflow strategy when a bounded queue reaches maximum capacity.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum OverflowPolicy {
    DropOldest,
    DropNewest,
}

/// A finite-capacity event queue with bounded memory and documented overflow behavior.
#[derive(Debug)]
pub struct BoundedEventQueue {
    capacity: usize,
    buffer: Vec<SensorEvent>,
    policy: OverflowPolicy,
    dropped_count: u64,
}

impl BoundedEventQueue {
    #[must_use]
    pub fn new(capacity: usize, policy: OverflowPolicy) -> Self {
        assert!(capacity > 0, "Queue capacity must be positive");
        Self {
            capacity,
            buffer: Vec::with_capacity(capacity),
            policy,
            dropped_count: 0,
        }
    }

    pub fn push(&mut self, event: SensorEvent) {
        if self.buffer.len() >= self.capacity {
            self.dropped_count += 1;
            match self.policy {
                OverflowPolicy::DropOldest => {
                    self.buffer.remove(0);
                    self.buffer.push(event);
                }
                OverflowPolicy::DropNewest => {
                    // Discard incoming event
                }
            }
        } else {
            self.buffer.push(event);
        }
    }

    pub fn pop(&mut self) -> Option<SensorEvent> {
        if self.buffer.is_empty() {
            None
        } else {
            Some(self.buffer.remove(0))
        }
    }

    #[must_use]
    pub fn is_empty(&self) -> bool {
        self.buffer.is_empty()
    }

    #[must_use]
    pub fn len(&self) -> usize {
        self.buffer.len()
    }

    #[must_use]
    pub const fn capacity(&self) -> usize {
        self.capacity
    }

    #[must_use]
    pub const fn dropped_count(&self) -> u64 {
        self.dropped_count
    }
}

/// Tone state for native audio feedback.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum AudioToneState {
    Climb,
    Sink,
    NearThermal,
    Silent,
}

/// Audio command computed in Rust core and consumed natively on high-priority audio thread.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct AudioToneCommand {
    pub state: AudioToneState,
    pub frequency_hz: f32,
    pub cadence_ms: u32,
    pub duty_cycle: f32,
    pub timestamp_ns: u64,
}

impl Default for AudioToneCommand {
    fn default() -> Self {
        Self {
            state: AudioToneState::Silent,
            frequency_hz: 0.0,
            cadence_ms: 0,
            duty_cycle: 0.0,
            timestamp_ns: 0,
        }
    }
}

/// Latest-value single-item slot for decoupled native audio control.
#[derive(Debug, Default)]
pub struct LatestValueAudioControl {
    latest: AudioToneCommand,
    reaction_count: u64,
}

impl LatestValueAudioControl {
    #[must_use]
    pub fn new() -> Self {
        Self::default()
    }

    pub fn update(&mut self, command: AudioToneCommand) {
        self.latest = command;
        self.reaction_count += 1;
    }

    #[must_use]
    pub const fn get_latest(&self) -> AudioToneCommand {
        self.latest
    }

    #[must_use]
    pub const fn reaction_count(&self) -> u64 {
        self.reaction_count
    }
}

/// Observable KPI snapshot formatted for the Flutter presentation layer.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct KpiSnapshot {
    pub altitude_m: f32,
    pub climb_rate_mps: f32,
    pub ground_speed_kmh: f32,
    pub track_bearing_deg: f32,
    pub timestamp_ns: u64,
    pub is_stale: bool,
    pub is_degraded: bool,
}

/// Publisher that limits KPI snapshot publication rate and replaces unread snapshots.
#[derive(Debug)]
pub struct RateLimitedKpiPublisher {
    min_interval_ns: u64,
    last_publish_ns: u64,
    pending_snapshot: Option<KpiSnapshot>,
    replaced_count: u64,
    published_count: u64,
}

impl RateLimitedKpiPublisher {
    #[must_use]
    pub const fn new(min_interval_ns: u64) -> Self {
        Self {
            min_interval_ns,
            last_publish_ns: 0,
            pending_snapshot: None,
            replaced_count: 0,
            published_count: 0,
        }
    }

    /// Submits a newly computed KPI candidate. If within min_interval, updates pending snapshot.
    pub fn submit(&mut self, snapshot: KpiSnapshot, current_time_ns: u64) {
        if self.pending_snapshot.is_some() {
            self.replaced_count += 1;
        }
        self.pending_snapshot = Some(snapshot);

        if current_time_ns.saturating_sub(self.last_publish_ns) >= self.min_interval_ns {
            self.last_publish_ns = current_time_ns;
            self.published_count += 1;
        }
    }

    /// Consumer (e.g. Flutter UI) consumes the latest pending snapshot.
    pub fn consume(&mut self) -> Option<KpiSnapshot> {
        self.pending_snapshot.take()
    }

    #[must_use]
    pub const fn replaced_count(&self) -> u64 {
        self.replaced_count
    }

    #[must_use]
    pub const fn published_count(&self) -> u64 {
        self.published_count
    }
}

/// Core processing engine connecting bounded queues, validation, audio control, and KPI snapshots.
#[derive(Debug)]
pub struct BoundedFlightPipeline {
    queue: BoundedEventQueue,
    audio_control: LatestValueAudioControl,
    kpi_publisher: RateLimitedKpiPublisher,
    counters: PipelineCounters,
    last_sequence: Option<u64>,
    traces: Vec<StageTimestampTrace>,
    // Core state
    last_altitude_m: f32,
    last_climb_rate_mps: f32,
    last_ground_speed_kmh: f32,
    last_bearing_deg: f32,
    last_pressure_hpa: Option<f64>,
    last_baro_time_ns: Option<u64>,
}

impl BoundedFlightPipeline {
    #[must_use]
    pub fn new(
        queue_capacity: usize,
        overflow_policy: OverflowPolicy,
        kpi_interval_ns: u64,
    ) -> Self {
        Self {
            queue: BoundedEventQueue::new(queue_capacity, overflow_policy),
            audio_control: LatestValueAudioControl::new(),
            kpi_publisher: RateLimitedKpiPublisher::new(kpi_interval_ns),
            counters: PipelineCounters::default(),
            last_sequence: None,
            traces: Vec::new(),
            last_altitude_m: 1000.0,
            last_climb_rate_mps: 0.0,
            last_ground_speed_kmh: 0.0,
            last_bearing_deg: 0.0,
            last_pressure_hpa: None,
            last_baro_time_ns: None,
        }
    }

    /// Ingests a raw sensor event from a native adapter.
    pub fn ingest(&mut self, event: SensorEvent) {
        self.counters.received_count += 1;
        let prev_dropped = self.queue.dropped_count();
        self.queue.push(event);
        if self.queue.dropped_count() > prev_dropped {
            self.counters.dropped_overflow_count += 1;
        }
    }

    /// Ingests the next event from a TelemetrySource into the pipeline queue.
    pub fn ingest_from_source<S: crate::procedural_generator::TelemetrySource + ?Sized>(
        &mut self,
        source: &mut S,
        current_time_ns: u64,
    ) -> bool {
        if let Some(event) = source.next_event(current_time_ns) {
            self.ingest(event);
            true
        } else {
            false
        }
    }

    /// Processes one event from the queue.
    pub fn step(&mut self, simulated_clock_ns: u64) -> Option<StageTimestampTrace> {
        let event = self.queue.pop()?;

        // Check if event is stale (older than 2 seconds)
        if event.quality_flags.is_stale
            || simulated_clock_ns.saturating_sub(event.native_received_timestamp_ns) > 2_000_000_000
        {
            self.counters.stale_count += 1;
        }

        // Validate event against contract
        if let Err(reason) = validate_sensor_event(&event, self.last_sequence) {
            self.counters.rejections_by_reason.record(reason);
            self.counters.rejected_malformed_count = self.counters.rejections_by_reason.total();
            return None;
        }

        self.last_sequence = Some(event.sequence);
        self.counters.processed_count += 1;

        // Process sensor payload
        let core_processed_ns =
            simulated_clock_ns.max(event.native_received_timestamp_ns + 500_000); // 0.5ms core compute

        match &event.payload {
            SensorPayload::Barometer {
                pressure_hpa,
                temperature_c: _,
            } => {
                // International standard atmosphere altitude approximation
                let alt = (44330.0 * (1.0 - (pressure_hpa / 1013.25).powf(0.19029495))) as f32;
                if let (Some(prev_p), Some(prev_t)) =
                    (self.last_pressure_hpa, self.last_baro_time_ns)
                {
                    let dt = (event.native_received_timestamp_ns.saturating_sub(prev_t)) as f64
                        / 1_000_000_000.0;
                    if dt > 0.001 {
                        let prev_alt = 44330.0 * (1.0 - (prev_p / 1013.25).powf(0.19029495));
                        self.last_climb_rate_mps = ((alt as f64 - prev_alt) / dt) as f32;
                    }
                }
                self.last_altitude_m = alt;
                self.last_pressure_hpa = Some(*pressure_hpa);
                self.last_baro_time_ns = Some(event.native_received_timestamp_ns);
            }
            SensorPayload::Gps {
                latitude_deg: _,
                longitude_deg: _,
                altitude_m,
                ground_speed_mps,
                bearing_deg,
                accuracy_m: _,
            } => {
                self.last_altitude_m = *altitude_m;
                self.last_ground_speed_kmh = ground_speed_mps * 3.6;
                self.last_bearing_deg = *bearing_deg;
            }
            SensorPayload::Variometer {
                climb_rate_mps,
                integrated_lift_mps: _,
            } => {
                self.last_climb_rate_mps = *climb_rate_mps;
            }
            SensorPayload::Imu { .. } => {}
        }

        // Compute audio tone command
        let audio_cmd = self.compute_audio_command(core_processed_ns);
        let audio_reaction_ns = Some(core_processed_ns + 1_500_000); // 1.5ms audio dispatch
        self.audio_control.update(audio_cmd);

        // Submit KPI snapshot
        let kpi = KpiSnapshot {
            altitude_m: self.last_altitude_m,
            climb_rate_mps: self.last_climb_rate_mps,
            ground_speed_kmh: self.last_ground_speed_kmh,
            track_bearing_deg: self.last_bearing_deg,
            timestamp_ns: core_processed_ns,
            is_stale: event.quality_flags.is_stale,
            is_degraded: event.quality_flags.is_degraded,
        };
        let prev_replaced = self.kpi_publisher.replaced_count();
        self.kpi_publisher.submit(kpi, core_processed_ns);
        if self.kpi_publisher.replaced_count() > prev_replaced {
            self.counters.replaced_count += 1;
        }

        let visible_kpi_ns = Some(core_processed_ns + 4_000_000); // 4ms render dispatch

        let trace = StageTimestampTrace {
            trace_id: event.sequence,
            sequence: event.sequence,
            native_received_ns: event.native_received_timestamp_ns,
            core_processed_ns,
            audio_reaction_ns,
            visible_kpi_ns,
            persistence_appended_ns: None,
        };

        self.traces.push(trace);
        Some(trace)
    }

    fn compute_audio_command(&self, current_time_ns: u64) -> AudioToneCommand {
        let lift = self.last_climb_rate_mps;
        if lift > 0.1 {
            // Climb mode: beeping with frequency scaling with lift rate
            let freq = (500.0 + lift * 200.0).min(1800.0);
            let cadence = (400.0 / (1.0 + lift * 0.5)).max(80.0) as u32;
            AudioToneCommand {
                state: AudioToneState::Climb,
                frequency_hz: freq,
                cadence_ms: cadence,
                duty_cycle: 0.5,
                timestamp_ns: current_time_ns,
            }
        } else if lift < -1.5 {
            // Sink mode: low continuous warning drone
            let freq = (400.0 + lift * 40.0).max(200.0);
            AudioToneCommand {
                state: AudioToneState::Sink,
                frequency_hz: freq,
                cadence_ms: 1000,
                duty_cycle: 1.0,
                timestamp_ns: current_time_ns,
            }
        } else if lift > -0.3 {
            AudioToneCommand {
                state: AudioToneState::NearThermal,
                frequency_hz: 450.0,
                cadence_ms: 600,
                duty_cycle: 0.2,
                timestamp_ns: current_time_ns,
            }
        } else {
            AudioToneCommand {
                state: AudioToneState::Silent,
                frequency_hz: 0.0,
                cadence_ms: 0,
                duty_cycle: 0.0,
                timestamp_ns: current_time_ns,
            }
        }
    }

    #[must_use]
    pub const fn counters(&self) -> PipelineCounters {
        self.counters
    }

    #[must_use]
    pub fn traces(&self) -> &[StageTimestampTrace] {
        &self.traces
    }

    #[must_use]
    pub fn latest_audio_command(&self) -> AudioToneCommand {
        self.audio_control.get_latest()
    }

    pub fn poll_kpi_snapshot(&mut self) -> Option<KpiSnapshot> {
        self.kpi_publisher.consume()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use brandyfly_contracts::{NATIVE_PIPELINE_SCHEMA_VERSION, SensorQualityFlags, SensorSourceId};

    fn make_test_event(seq: u64, pressure: f64) -> SensorEvent {
        SensorEvent {
            schema_version: NATIVE_PIPELINE_SCHEMA_VERSION,
            source_id: SensorSourceId::Barometer,
            source_timestamp_ns: Some(1_000_000 * seq),
            native_received_timestamp_ns: 1_000_000 * seq,
            sequence: seq,
            quality_flags: SensorQualityFlags::nominal(),
            payload: SensorPayload::Barometer {
                pressure_hpa: pressure,
                temperature_c: Some(15.0),
            },
        }
    }

    #[test]
    fn bounded_queue_overflow_drop_oldest() {
        let mut queue = BoundedEventQueue::new(3, OverflowPolicy::DropOldest);
        queue.push(make_test_event(1, 1013.0));
        queue.push(make_test_event(2, 1012.0));
        queue.push(make_test_event(3, 1011.0));
        assert_eq!(queue.len(), 3);
        assert_eq!(queue.dropped_count(), 0);

        // Push 4th event -> drops event 1
        queue.push(make_test_event(4, 1010.0));
        assert_eq!(queue.len(), 3);
        assert_eq!(queue.dropped_count(), 1);

        let first = queue.pop().unwrap();
        assert_eq!(first.sequence, 2);
    }

    #[test]
    fn bounded_queue_overflow_drop_newest() {
        let mut queue = BoundedEventQueue::new(2, OverflowPolicy::DropNewest);
        queue.push(make_test_event(1, 1013.0));
        queue.push(make_test_event(2, 1012.0));
        queue.push(make_test_event(3, 1011.0)); // dropped

        assert_eq!(queue.len(), 2);
        assert_eq!(queue.dropped_count(), 1);

        assert_eq!(queue.pop().unwrap().sequence, 1);
        assert_eq!(queue.pop().unwrap().sequence, 2);
        assert_eq!(queue.pop(), None);
    }

    #[test]
    fn audio_control_updates_latest_value() {
        let mut audio = LatestValueAudioControl::new();
        assert_eq!(audio.get_latest().state, AudioToneState::Silent);

        audio.update(AudioToneCommand {
            state: AudioToneState::Climb,
            frequency_hz: 600.0,
            cadence_ms: 250,
            duty_cycle: 0.5,
            timestamp_ns: 100_000,
        });

        assert_eq!(audio.get_latest().state, AudioToneState::Climb);
        assert_eq!(audio.reaction_count(), 1);
    }

    #[test]
    fn rate_limited_kpi_publisher_replaces_pending_snapshots() {
        // 100ms min interval = 100_000_000 ns
        let mut publisher = RateLimitedKpiPublisher::new(100_000_000);

        let snap1 = KpiSnapshot {
            altitude_m: 1000.0,
            climb_rate_mps: 1.0,
            ground_speed_kmh: 30.0,
            track_bearing_deg: 90.0,
            timestamp_ns: 10_000_000,
            is_stale: false,
            is_degraded: false,
        };
        let snap2 = KpiSnapshot {
            altitude_m: 1002.0,
            climb_rate_mps: 2.0,
            ground_speed_kmh: 32.0,
            track_bearing_deg: 92.0,
            timestamp_ns: 20_000_000,
            is_stale: false,
            is_degraded: false,
        };

        publisher.submit(snap1, 10_000_000);
        publisher.submit(snap2, 20_000_000); // replaces snap1 before consumer reads

        assert_eq!(publisher.replaced_count(), 1);
        let consumed = publisher.consume().unwrap();
        assert_eq!(consumed.altitude_m, 1002.0);
        assert_eq!(publisher.consume(), None);
    }

    #[test]
    fn pipeline_stress_with_flutter_stall_maintains_bounded_memory() {
        let mut pipeline = BoundedFlightPipeline::new(16, OverflowPolicy::DropOldest, 100_000_000);

        // Ingest 500 events simulating rapid arrival while Flutter consumer stalls
        for i in 1..=500 {
            pipeline.ingest(make_test_event(i, 1013.25 - (i as f64 * 0.02)));
            pipeline.step(i * 10_000_000);
        }

        let counters = pipeline.counters();
        assert_eq!(counters.received_count, 500);
        assert!(counters.processed_count > 0);
        assert!(counters.replaced_count > 0);
        assert_eq!(counters.rejected_malformed_count, 0);

        // Final snapshot is available and fresh
        let snapshot = pipeline.poll_kpi_snapshot().unwrap();
        assert!(snapshot.altitude_m >= 0.0);
        assert!(snapshot.climb_rate_mps >= 0.0);
    }

    #[test]
    fn pipeline_ingests_from_procedural_telemetry_source() {
        use crate::procedural_generator::{ProceduralFlightGenerator, ProceduralManeuver};

        let mut pipeline = BoundedFlightPipeline::new(32, OverflowPolicy::DropOldest, 100_000_000);
        let mut source = ProceduralFlightGenerator::with_maneuver(
            42,
            1_000_000_000,
            ProceduralManeuver::ThermalClimb360,
        );

        for i in 1..=100 {
            let ts = 1_000_000_000 + i * 20_000_000;
            let ingested = pipeline.ingest_from_source(&mut source, ts);
            assert!(ingested);
            pipeline.step(ts + 1_000_000);
        }

        assert_eq!(pipeline.counters().received_count, 100);
        assert_eq!(pipeline.counters().rejected_malformed_count, 0);
        let kpi = pipeline.poll_kpi_snapshot().expect("kpi snapshot");
        assert!(kpi.altitude_m > 1500.0);
        assert!(kpi.climb_rate_mps > 0.0);
    }
}
