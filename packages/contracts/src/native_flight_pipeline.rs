#![forbid(unsafe_code)]

/// Schema version for native flight pipeline contracts.
pub const NATIVE_PIPELINE_SCHEMA_VERSION: u16 = 1;

/// Latency threshold gates in milliseconds.
pub const MAX_ALLOWED_CORE_P95_LATENCY_MS: f64 = 50.0;
pub const MAX_ALLOWED_AUDIO_P95_LATENCY_MS: f64 = 80.0;
pub const MAX_ALLOWED_KPI_P95_LATENCY_MS: f64 = 100.0;

/// Quality flags for a sensor event.
#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash)]
pub struct SensorQualityFlags {
    pub is_valid: bool,
    pub is_degraded: bool,
    pub is_stale: bool,
    pub is_calibrated: bool,
}

impl Default for SensorQualityFlags {
    fn default() -> Self {
        Self {
            is_valid: true,
            is_degraded: false,
            is_stale: false,
            is_calibrated: true,
        }
    }
}

impl SensorQualityFlags {
    #[must_use]
    pub const fn nominal() -> Self {
        Self {
            is_valid: true,
            is_degraded: false,
            is_stale: false,
            is_calibrated: true,
        }
    }

    #[must_use]
    pub const fn stale() -> Self {
        Self {
            is_valid: true,
            is_degraded: true,
            is_stale: true,
            is_calibrated: true,
        }
    }

    #[must_use]
    pub const fn invalid() -> Self {
        Self {
            is_valid: false,
            is_degraded: true,
            is_stale: false,
            is_calibrated: false,
        }
    }

    #[must_use]
    pub const fn as_u8(self) -> u8 {
        let mut b = 0u8;
        if self.is_valid {
            b |= 1 << 0;
        }
        if self.is_degraded {
            b |= 1 << 1;
        }
        if self.is_stale {
            b |= 1 << 2;
        }
        if self.is_calibrated {
            b |= 1 << 3;
        }
        b
    }

    #[must_use]
    pub const fn from_u8(val: u8) -> Self {
        Self {
            is_valid: (val & (1 << 0)) != 0,
            is_degraded: (val & (1 << 1)) != 0,
            is_stale: (val & (1 << 2)) != 0,
            is_calibrated: (val & (1 << 3)) != 0,
        }
    }
}

/// Identifies the sensor source.
#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash)]
pub enum SensorSourceId {
    Barometer,
    Gps,
    Imu,
    Variometer,
    Synthetic,
}

impl SensorSourceId {
    #[must_use]
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::Barometer => "barometer",
            Self::Gps => "gps",
            Self::Imu => "imu",
            Self::Variometer => "variometer",
            Self::Synthetic => "synthetic",
        }
    }

    #[must_use]
    pub const fn type_id(self) -> u8 {
        match self {
            Self::Barometer => 1,
            Self::Gps => 2,
            Self::Imu => 3,
            Self::Variometer => 4,
            Self::Synthetic => 5,
        }
    }

    #[must_use]
    pub const fn from_type_id(id: u8) -> Option<Self> {
        match id {
            1 => Some(Self::Barometer),
            2 => Some(Self::Gps),
            3 => Some(Self::Imu),
            4 => Some(Self::Variometer),
            5 => Some(Self::Synthetic),
            _ => None,
        }
    }
}

/// Payload data for individual sensor types.
#[derive(Clone, Debug, PartialEq)]
pub enum SensorPayload {
    Barometer {
        pressure_hpa: f64,
        temperature_c: Option<f32>,
    },
    Gps {
        latitude_deg: f64,
        longitude_deg: f64,
        altitude_m: f32,
        ground_speed_mps: f32,
        bearing_deg: f32,
        accuracy_m: f32,
    },
    Imu {
        accel_mps2: [f32; 3],
        gyro_radps: [f32; 3],
    },
    Variometer {
        climb_rate_mps: f32,
        integrated_lift_mps: f32,
    },
}

/// A versioned sensor event carrying end-to-end timing metadata.
#[derive(Clone, Debug, PartialEq)]
pub struct SensorEvent {
    pub schema_version: u16,
    pub source_id: SensorSourceId,
    pub source_timestamp_ns: Option<u64>,
    pub native_received_timestamp_ns: u64,
    pub sequence: u64,
    pub quality_flags: SensorQualityFlags,
    pub payload: SensorPayload,
}

/// Reasons why a sensor event or record can be rejected during validation.
#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash)]
pub enum EventRejectionReason {
    UnsupportedSchemaVersion,
    NonPositiveReceiveTimestamp,
    NonMonotonicSequence,
    OutOfBoundsPressure,
    OutOfBoundsCoordinates,
    OutOfBoundsClimbRate,
    CorruptedPayload,
    ChecksumMismatch,
}

impl EventRejectionReason {
    #[must_use]
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::UnsupportedSchemaVersion => "unsupported_schema_version",
            Self::NonPositiveReceiveTimestamp => "non_positive_receive_timestamp",
            Self::NonMonotonicSequence => "non_monotonic_sequence",
            Self::OutOfBoundsPressure => "out_of_bounds_pressure",
            Self::OutOfBoundsCoordinates => "out_of_bounds_coordinates",
            Self::OutOfBoundsClimbRate => "out_of_bounds_climb_rate",
            Self::CorruptedPayload => "corrupted_payload",
            Self::ChecksumMismatch => "checksum_mismatch",
        }
    }
}

/// Breakdown of rejected event counters by reason.
#[derive(Clone, Copy, Debug, Default, Eq, PartialEq)]
pub struct RejectionReasonCounters {
    pub unsupported_schema_version: u64,
    pub non_positive_receive_timestamp: u64,
    pub non_monotonic_sequence: u64,
    pub out_of_bounds_pressure: u64,
    pub out_of_bounds_coordinates: u64,
    pub out_of_bounds_climb_rate: u64,
    pub corrupted_payload: u64,
    pub checksum_mismatch: u64,
}

impl RejectionReasonCounters {
    pub fn record(&mut self, reason: EventRejectionReason) {
        match reason {
            EventRejectionReason::UnsupportedSchemaVersion => {
                self.unsupported_schema_version += 1;
            }
            EventRejectionReason::NonPositiveReceiveTimestamp => {
                self.non_positive_receive_timestamp += 1;
            }
            EventRejectionReason::NonMonotonicSequence => {
                self.non_monotonic_sequence += 1;
            }
            EventRejectionReason::OutOfBoundsPressure => {
                self.out_of_bounds_pressure += 1;
            }
            EventRejectionReason::OutOfBoundsCoordinates => {
                self.out_of_bounds_coordinates += 1;
            }
            EventRejectionReason::OutOfBoundsClimbRate => {
                self.out_of_bounds_climb_rate += 1;
            }
            EventRejectionReason::CorruptedPayload => {
                self.corrupted_payload += 1;
            }
            EventRejectionReason::ChecksumMismatch => {
                self.checksum_mismatch += 1;
            }
        }
    }

    #[must_use]
    pub const fn total(&self) -> u64 {
        self.unsupported_schema_version
            + self.non_positive_receive_timestamp
            + self.non_monotonic_sequence
            + self.out_of_bounds_pressure
            + self.out_of_bounds_coordinates
            + self.out_of_bounds_climb_rate
            + self.corrupted_payload
            + self.checksum_mismatch
    }
}

/// Counters tracking observable queue dynamics and data loss.
#[derive(Clone, Copy, Debug, Default, Eq, PartialEq)]
pub struct PipelineCounters {
    pub received_count: u64,
    pub processed_count: u64,
    pub dropped_overflow_count: u64,
    pub replaced_count: u64,
    pub stale_count: u64,
    pub rejected_malformed_count: u64,
    pub rejections_by_reason: RejectionReasonCounters,
}

/// Stage timestamps recorded along the path of an event.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct StageTimestampTrace {
    pub trace_id: u64,
    pub sequence: u64,
    pub native_received_ns: u64,
    pub core_processed_ns: u64,
    pub audio_reaction_ns: Option<u64>,
    pub visible_kpi_ns: Option<u64>,
    pub persistence_appended_ns: Option<u64>,
}

impl StageTimestampTrace {
    #[must_use]
    pub fn core_latency_ms(&self) -> f64 {
        if self.core_processed_ns >= self.native_received_ns {
            (self.core_processed_ns - self.native_received_ns) as f64 / 1_000_000.0
        } else {
            0.0
        }
    }

    #[must_use]
    pub fn audio_latency_ms(&self) -> Option<f64> {
        self.audio_reaction_ns.map(|audio_ns| {
            if audio_ns >= self.native_received_ns {
                (audio_ns - self.native_received_ns) as f64 / 1_000_000.0
            } else {
                0.0
            }
        })
    }

    #[must_use]
    pub fn kpi_latency_ms(&self) -> Option<f64> {
        self.visible_kpi_ns.map(|kpi_ns| {
            if kpi_ns >= self.native_received_ns {
                (kpi_ns - self.native_received_ns) as f64 / 1_000_000.0
            } else {
                0.0
            }
        })
    }
}

/// Percentile latency statistics.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct LatencySummary {
    pub p50_ms: f64,
    pub p95_ms: f64,
    pub max_ms: f64,
}

impl LatencySummary {
    #[must_use]
    pub fn from_samples(mut samples: Vec<f64>) -> Self {
        if samples.is_empty() {
            return Self {
                p50_ms: 0.0,
                p95_ms: 0.0,
                max_ms: 0.0,
            };
        }
        samples.sort_by(|a, b| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal));
        let len = samples.len();
        let p50_idx = ((len as f64 * 0.50).ceil() as usize)
            .saturating_sub(1)
            .min(len - 1);
        let p95_idx = ((len as f64 * 0.95).ceil() as usize)
            .saturating_sub(1)
            .min(len - 1);
        let max_idx = len - 1;

        Self {
            p50_ms: samples[p50_idx],
            p95_ms: samples[p95_idx],
            max_ms: samples[max_idx],
        }
    }
}

/// Benchmark result schema verifying gates and counters.
#[derive(Clone, Debug, PartialEq)]
pub struct BenchmarkResult {
    pub platform: String,
    pub total_events: usize,
    pub counters: PipelineCounters,
    pub core_latency: LatencySummary,
    pub audio_latency: LatencySummary,
    pub kpi_latency: LatencySummary,
    pub core_gate_passed: bool,
    pub audio_gate_passed: bool,
    pub kpi_gate_passed: bool,
    pub all_gates_passed: bool,
    pub lifecycle_scenarios_tested: Vec<String>,
}

impl BenchmarkResult {
    #[must_use]
    pub fn new(
        platform: String,
        total_events: usize,
        counters: PipelineCounters,
        core_samples: Vec<f64>,
        audio_samples: Vec<f64>,
        kpi_samples: Vec<f64>,
        lifecycle_scenarios_tested: Vec<String>,
    ) -> Self {
        let core_latency = LatencySummary::from_samples(core_samples);
        let audio_latency = LatencySummary::from_samples(audio_samples);
        let kpi_latency = LatencySummary::from_samples(kpi_samples);

        let core_gate_passed = core_latency.p95_ms <= MAX_ALLOWED_CORE_P95_LATENCY_MS;
        let audio_gate_passed = audio_latency.p95_ms <= MAX_ALLOWED_AUDIO_P95_LATENCY_MS;
        let kpi_gate_passed = kpi_latency.p95_ms <= MAX_ALLOWED_KPI_P95_LATENCY_MS;
        let all_gates_passed = core_gate_passed && audio_gate_passed && kpi_gate_passed;

        Self {
            platform,
            total_events,
            counters,
            core_latency,
            audio_latency,
            kpi_latency,
            core_gate_passed,
            audio_gate_passed,
            kpi_gate_passed,
            all_gates_passed,
            lifecycle_scenarios_tested,
        }
    }
}

/// Validates a single sensor event against the contract.
pub fn validate_sensor_event(
    event: &SensorEvent,
    last_sequence: Option<u64>,
) -> Result<(), EventRejectionReason> {
    if event.schema_version != NATIVE_PIPELINE_SCHEMA_VERSION {
        return Err(EventRejectionReason::UnsupportedSchemaVersion);
    }
    if event.native_received_timestamp_ns == 0 {
        return Err(EventRejectionReason::NonPositiveReceiveTimestamp);
    }
    if let Some(prev_seq) = last_sequence
        && event.sequence <= prev_seq
    {
        return Err(EventRejectionReason::NonMonotonicSequence);
    }

    match &event.payload {
        SensorPayload::Barometer {
            pressure_hpa,
            temperature_c,
        } => {
            if *pressure_hpa < 300.0 || *pressure_hpa > 1200.0 || pressure_hpa.is_nan() {
                return Err(EventRejectionReason::OutOfBoundsPressure);
            }
            if let Some(temp) = temperature_c
                && (*temp < -50.0 || *temp > 85.0 || temp.is_nan())
            {
                return Err(EventRejectionReason::CorruptedPayload);
            }
        }
        SensorPayload::Gps {
            latitude_deg,
            longitude_deg,
            altitude_m,
            ground_speed_mps,
            bearing_deg,
            accuracy_m,
        } => {
            if *latitude_deg < -90.0
                || *latitude_deg > 90.0
                || *longitude_deg < -180.0
                || *longitude_deg > 180.0
                || latitude_deg.is_nan()
                || longitude_deg.is_nan()
            {
                return Err(EventRejectionReason::OutOfBoundsCoordinates);
            }
            if *altitude_m < -500.0
                || *altitude_m > 15000.0
                || *ground_speed_mps < 0.0
                || *ground_speed_mps > 200.0
                || *bearing_deg < 0.0
                || *bearing_deg > 360.0
                || *accuracy_m < 0.0
                || altitude_m.is_nan()
                || ground_speed_mps.is_nan()
                || bearing_deg.is_nan()
                || accuracy_m.is_nan()
            {
                return Err(EventRejectionReason::CorruptedPayload);
            }
        }
        SensorPayload::Imu {
            accel_mps2,
            gyro_radps,
        } => {
            for a in accel_mps2 {
                if a.is_nan() || *a < -200.0 || *a > 200.0 {
                    return Err(EventRejectionReason::CorruptedPayload);
                }
            }
            for g in gyro_radps {
                if g.is_nan() || *g < -50.0 || *g > 50.0 {
                    return Err(EventRejectionReason::CorruptedPayload);
                }
            }
        }
        SensorPayload::Variometer {
            climb_rate_mps,
            integrated_lift_mps,
        } => {
            if climb_rate_mps.is_nan()
                || *climb_rate_mps < -50.0
                || *climb_rate_mps > 50.0
                || integrated_lift_mps.is_nan()
                || *integrated_lift_mps < -50.0
                || *integrated_lift_mps > 50.0
            {
                return Err(EventRejectionReason::OutOfBoundsClimbRate);
            }
        }
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn quality_flags_round_trip_and_defaults() {
        let nominal = SensorQualityFlags::nominal();
        assert_eq!(nominal, SensorQualityFlags::default());
        assert_eq!(nominal.as_u8(), 0b00001001);
        assert_eq!(SensorQualityFlags::from_u8(nominal.as_u8()), nominal);

        let stale = SensorQualityFlags::stale();
        assert_eq!(stale.as_u8(), 0b00001111);
        assert_eq!(SensorQualityFlags::from_u8(stale.as_u8()), stale);

        let invalid = SensorQualityFlags::invalid();
        assert_eq!(invalid.as_u8(), 0b00000010);
        assert_eq!(SensorQualityFlags::from_u8(invalid.as_u8()), invalid);
    }

    #[test]
    fn sensor_source_id_mapping() {
        let sources = [
            (SensorSourceId::Barometer, "barometer", 1),
            (SensorSourceId::Gps, "gps", 2),
            (SensorSourceId::Imu, "imu", 3),
            (SensorSourceId::Variometer, "variometer", 4),
            (SensorSourceId::Synthetic, "synthetic", 5),
        ];
        for (source, name, id) in sources {
            assert_eq!(source.as_str(), name);
            assert_eq!(source.type_id(), id);
            assert_eq!(SensorSourceId::from_type_id(id), Some(source));
        }
        assert_eq!(SensorSourceId::from_type_id(99), None);
    }

    #[test]
    fn validates_nominal_sensor_events() {
        let baro_event = SensorEvent {
            schema_version: 1,
            source_id: SensorSourceId::Barometer,
            source_timestamp_ns: Some(1_000_000),
            native_received_timestamp_ns: 1_005_000,
            sequence: 1,
            quality_flags: SensorQualityFlags::nominal(),
            payload: SensorPayload::Barometer {
                pressure_hpa: 1013.25,
                temperature_c: Some(15.5),
            },
        };
        assert_eq!(validate_sensor_event(&baro_event, None), Ok(()));

        let gps_event = SensorEvent {
            schema_version: 1,
            source_id: SensorSourceId::Gps,
            source_timestamp_ns: Some(1_000_000),
            native_received_timestamp_ns: 1_005_000,
            sequence: 2,
            quality_flags: SensorQualityFlags::nominal(),
            payload: SensorPayload::Gps {
                latitude_deg: 47.5,
                longitude_deg: 13.5,
                altitude_m: 1800.0,
                ground_speed_mps: 12.5,
                bearing_deg: 180.0,
                accuracy_m: 2.5,
            },
        };
        assert_eq!(validate_sensor_event(&gps_event, Some(1)), Ok(()));
    }

    #[test]
    fn rejects_malformed_sensor_events_with_proper_reasons() {
        let mut event = SensorEvent {
            schema_version: 1,
            source_id: SensorSourceId::Barometer,
            source_timestamp_ns: Some(1_000_000),
            native_received_timestamp_ns: 1_005_000,
            sequence: 5,
            quality_flags: SensorQualityFlags::nominal(),
            payload: SensorPayload::Barometer {
                pressure_hpa: 1013.25,
                temperature_c: Some(15.5),
            },
        };

        // Unsupported version
        event.schema_version = 2;
        assert_eq!(
            validate_sensor_event(&event, Some(4)),
            Err(EventRejectionReason::UnsupportedSchemaVersion)
        );
        event.schema_version = 1;

        // Zero native timestamp
        event.native_received_timestamp_ns = 0;
        assert_eq!(
            validate_sensor_event(&event, Some(4)),
            Err(EventRejectionReason::NonPositiveReceiveTimestamp)
        );
        event.native_received_timestamp_ns = 1_005_000;

        // Non-monotonic sequence
        assert_eq!(
            validate_sensor_event(&event, Some(5)),
            Err(EventRejectionReason::NonMonotonicSequence)
        );
        assert_eq!(
            validate_sensor_event(&event, Some(6)),
            Err(EventRejectionReason::NonMonotonicSequence)
        );

        // Out of bounds pressure
        event.payload = SensorPayload::Barometer {
            pressure_hpa: 250.0, // too low
            temperature_c: None,
        };
        assert_eq!(
            validate_sensor_event(&event, Some(4)),
            Err(EventRejectionReason::OutOfBoundsPressure)
        );

        // Out of bounds GPS coordinates
        event.payload = SensorPayload::Gps {
            latitude_deg: 95.0, // invalid
            longitude_deg: 13.5,
            altitude_m: 1000.0,
            ground_speed_mps: 10.0,
            bearing_deg: 0.0,
            accuracy_m: 5.0,
        };
        assert_eq!(
            validate_sensor_event(&event, Some(4)),
            Err(EventRejectionReason::OutOfBoundsCoordinates)
        );

        // Out of bounds climb rate
        event.payload = SensorPayload::Variometer {
            climb_rate_mps: 60.0, // impossible extreme
            integrated_lift_mps: 0.0,
        };
        assert_eq!(
            validate_sensor_event(&event, Some(4)),
            Err(EventRejectionReason::OutOfBoundsClimbRate)
        );
    }

    #[test]
    fn rejection_counters_and_benchmark_result_verification() {
        let mut counters = PipelineCounters::default();
        counters
            .rejections_by_reason
            .record(EventRejectionReason::OutOfBoundsPressure);
        counters
            .rejections_by_reason
            .record(EventRejectionReason::NonMonotonicSequence);
        counters.rejected_malformed_count = counters.rejections_by_reason.total();

        assert_eq!(counters.rejections_by_reason.out_of_bounds_pressure, 1);
        assert_eq!(counters.rejections_by_reason.non_monotonic_sequence, 1);
        assert_eq!(counters.rejected_malformed_count, 2);

        let core_samples = vec![5.0, 10.0, 15.0, 20.0, 25.0];
        let audio_samples = vec![10.0, 20.0, 30.0, 40.0, 50.0];
        let kpi_samples = vec![20.0, 30.0, 40.0, 50.0, 60.0];

        let result = BenchmarkResult::new(
            "linux-desktop".to_string(),
            5,
            counters,
            core_samples,
            audio_samples,
            kpi_samples,
            vec!["nominal_flow".to_string(), "background_pause".to_string()],
        );

        assert!(result.all_gates_passed);
        assert!(result.core_gate_passed);
        assert!(result.audio_gate_passed);
        assert!(result.kpi_gate_passed);
        assert_eq!(result.core_latency.p50_ms, 15.0);
        assert_eq!(result.core_latency.max_ms, 25.0);
    }
}
