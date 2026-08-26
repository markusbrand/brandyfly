#![forbid(unsafe_code)]

use brandyfly_contracts::{
    NATIVE_PIPELINE_SCHEMA_VERSION, SKYDROP1_PROTOCOL_SCHEMA_VERSION, SensorEvent, SensorPayload,
    SensorQualityFlags, SensorSourceId, SkyDrop1IntegrityCounters, SkyDrop1ParseError,
    SkyDrop1ParsedSample, SkyDrop1RawFrame, calculate_nmea_checksum, parse_skydrop1_frame,
};

/// Types of SkyDrop 1 replay scenarios.
#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash)]
pub enum SkyDrop1ReplayScenario {
    ValidStream,
    MalformedFrames,
    TruncatedFrames,
    DuplicateFrames,
    OutOfOrderFrames,
    SanitizationViolation,
    CombinedStress,
}

/// Types of synthetic replay fixtures.
#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash)]
pub enum SyntheticReplayScenario {
    NormalCadence,
    BurstTraffic,
    SensorGaps,
    StaleEvents,
    MalformedRecords,
    CombinedStress,
}

/// Generates synthetic sensor event sequences for deterministic replay and benchmarking.
#[derive(Clone, Debug)]
pub struct SyntheticReplayGenerator {
    seed: u64,
    base_timestamp_ns: u64,
}

impl SyntheticReplayGenerator {
    #[must_use]
    pub const fn new(seed: u64, base_timestamp_ns: u64) -> Self {
        Self {
            seed,
            base_timestamp_ns,
        }
    }

    #[must_use]
    pub const fn seed(&self) -> u64 {
        self.seed
    }

    #[must_use]
    pub fn generate_fixture(&self, scenario: SyntheticReplayScenario) -> Vec<SensorEvent> {
        match scenario {
            SyntheticReplayScenario::NormalCadence => self.generate_normal(100),
            SyntheticReplayScenario::BurstTraffic => self.generate_burst(300),
            SyntheticReplayScenario::SensorGaps => self.generate_gaps(),
            SyntheticReplayScenario::StaleEvents => self.generate_stale(50),
            SyntheticReplayScenario::MalformedRecords => self.generate_malformed(),
            SyntheticReplayScenario::CombinedStress => self.generate_combined_stress(),
        }
    }

    fn generate_normal(&self, count: usize) -> Vec<SensorEvent> {
        let mut events = Vec::with_capacity(count);
        let mut current_time_ns = self.base_timestamp_ns;
        let mut current_pressure = 1013.25 - ((self.seed % 10) as f64 * 0.1);
        let mut alt = 1500.0 + ((self.seed % 100) as f64);

        for seq in 1..=(count as u64) {
            // 50Hz sensor cadence = 20ms = 20_000_000 ns
            current_time_ns += 20_000_000;
            current_pressure -= 0.05; // slight climb
            alt += 0.4;

            if seq % 2 == 1 {
                events.push(SensorEvent {
                    schema_version: NATIVE_PIPELINE_SCHEMA_VERSION,
                    source_id: SensorSourceId::Barometer,
                    source_timestamp_ns: Some(current_time_ns - 1_000_000),
                    native_received_timestamp_ns: current_time_ns,
                    sequence: seq,
                    quality_flags: SensorQualityFlags::nominal(),
                    payload: SensorPayload::Barometer {
                        pressure_hpa: current_pressure,
                        temperature_c: Some(18.0),
                    },
                });
            } else {
                events.push(SensorEvent {
                    schema_version: NATIVE_PIPELINE_SCHEMA_VERSION,
                    source_id: SensorSourceId::Gps,
                    source_timestamp_ns: Some(current_time_ns - 2_000_000),
                    native_received_timestamp_ns: current_time_ns,
                    sequence: seq,
                    quality_flags: SensorQualityFlags::nominal(),
                    payload: SensorPayload::Gps {
                        latitude_deg: 47.55 + (seq as f64 * 0.0001),
                        longitude_deg: 13.62 + (seq as f64 * 0.0001),
                        altitude_m: alt as f32,
                        ground_speed_mps: 11.5,
                        bearing_deg: 120.0,
                        accuracy_m: 1.8,
                    },
                });
            }
        }
        events
    }

    fn generate_burst(&self, burst_count: usize) -> Vec<SensorEvent> {
        let mut events = Vec::with_capacity(burst_count);
        let mut current_time_ns = self.base_timestamp_ns;

        for seq in 1..=(burst_count as u64) {
            // High frequency burst: 100 microseconds per event
            current_time_ns += 100_000;
            events.push(SensorEvent {
                schema_version: NATIVE_PIPELINE_SCHEMA_VERSION,
                source_id: SensorSourceId::Barometer,
                source_timestamp_ns: Some(current_time_ns - 10_000),
                native_received_timestamp_ns: current_time_ns,
                sequence: seq,
                quality_flags: SensorQualityFlags::nominal(),
                payload: SensorPayload::Barometer {
                    pressure_hpa: 1010.0 + ((seq % 20) as f64 * 0.1),
                    temperature_c: Some(20.0),
                },
            });
        }
        events
    }

    fn generate_gaps(&self) -> Vec<SensorEvent> {
        let mut events = Vec::with_capacity(60);
        let mut current_time_ns = self.base_timestamp_ns;

        for seq in 1..=20u64 {
            current_time_ns += 20_000_000;
            events.push(SensorEvent {
                schema_version: NATIVE_PIPELINE_SCHEMA_VERSION,
                source_id: SensorSourceId::Barometer,
                source_timestamp_ns: Some(current_time_ns - 1_000_000),
                native_received_timestamp_ns: current_time_ns,
                sequence: seq,
                quality_flags: SensorQualityFlags::nominal(),
                payload: SensorPayload::Barometer {
                    pressure_hpa: 1012.0,
                    temperature_c: Some(19.0),
                },
            });
        }

        // 3-second gap in sensor reception
        current_time_ns += 3_000_000_000;

        for seq in 21..=40u64 {
            current_time_ns += 20_000_000;
            events.push(SensorEvent {
                schema_version: NATIVE_PIPELINE_SCHEMA_VERSION,
                source_id: SensorSourceId::Barometer,
                source_timestamp_ns: Some(current_time_ns - 1_000_000),
                native_received_timestamp_ns: current_time_ns,
                sequence: seq,
                quality_flags: SensorQualityFlags::nominal(),
                payload: SensorPayload::Barometer {
                    pressure_hpa: 1008.0,
                    temperature_c: Some(19.5),
                },
            });
        }

        events
    }

    fn generate_stale(&self, count: usize) -> Vec<SensorEvent> {
        let mut events = Vec::with_capacity(count);
        let mut current_time_ns = self.base_timestamp_ns;

        for seq in 1..=(count as u64) {
            current_time_ns += 20_000_000;
            // Hardware sample was generated 2.5 seconds ago (stale)
            let stale_source_time = current_time_ns.saturating_sub(2_500_000_000);
            events.push(SensorEvent {
                schema_version: NATIVE_PIPELINE_SCHEMA_VERSION,
                source_id: SensorSourceId::Barometer,
                source_timestamp_ns: Some(stale_source_time),
                native_received_timestamp_ns: current_time_ns,
                sequence: seq,
                quality_flags: SensorQualityFlags::stale(),
                payload: SensorPayload::Barometer {
                    pressure_hpa: 1005.0,
                    temperature_c: Some(16.0),
                },
            });
        }
        events
    }

    fn generate_malformed(&self) -> Vec<SensorEvent> {
        vec![
            // 1. Valid event
            SensorEvent {
                schema_version: NATIVE_PIPELINE_SCHEMA_VERSION,
                source_id: SensorSourceId::Barometer,
                source_timestamp_ns: Some(self.base_timestamp_ns + 10_000_000),
                native_received_timestamp_ns: self.base_timestamp_ns + 20_000_000,
                sequence: 1,
                quality_flags: SensorQualityFlags::nominal(),
                payload: SensorPayload::Barometer {
                    pressure_hpa: 1013.25,
                    temperature_c: Some(15.0),
                },
            },
            // 2. Bad schema version
            SensorEvent {
                schema_version: 99,
                source_id: SensorSourceId::Barometer,
                source_timestamp_ns: Some(self.base_timestamp_ns + 30_000_000),
                native_received_timestamp_ns: self.base_timestamp_ns + 40_000_000,
                sequence: 2,
                quality_flags: SensorQualityFlags::nominal(),
                payload: SensorPayload::Barometer {
                    pressure_hpa: 1013.25,
                    temperature_c: Some(15.0),
                },
            },
            // 3. Zero native timestamp
            SensorEvent {
                schema_version: NATIVE_PIPELINE_SCHEMA_VERSION,
                source_id: SensorSourceId::Barometer,
                source_timestamp_ns: Some(self.base_timestamp_ns + 50_000_000),
                native_received_timestamp_ns: 0,
                sequence: 3,
                quality_flags: SensorQualityFlags::nominal(),
                payload: SensorPayload::Barometer {
                    pressure_hpa: 1013.25,
                    temperature_c: Some(15.0),
                },
            },
            // 4. Non-monotonic sequence (sequence repeats 1)
            SensorEvent {
                schema_version: NATIVE_PIPELINE_SCHEMA_VERSION,
                source_id: SensorSourceId::Barometer,
                source_timestamp_ns: Some(self.base_timestamp_ns + 70_000_000),
                native_received_timestamp_ns: self.base_timestamp_ns + 80_000_000,
                sequence: 1,
                quality_flags: SensorQualityFlags::nominal(),
                payload: SensorPayload::Barometer {
                    pressure_hpa: 1013.25,
                    temperature_c: Some(15.0),
                },
            },
            // 5. Out of bounds pressure (negative / unrealistic)
            SensorEvent {
                schema_version: NATIVE_PIPELINE_SCHEMA_VERSION,
                source_id: SensorSourceId::Barometer,
                source_timestamp_ns: Some(self.base_timestamp_ns + 90_000_000),
                native_received_timestamp_ns: self.base_timestamp_ns + 100_000_000,
                sequence: 5,
                quality_flags: SensorQualityFlags::nominal(),
                payload: SensorPayload::Barometer {
                    pressure_hpa: 150.0,
                    temperature_c: Some(15.0),
                },
            },
            // 6. Out of bounds GPS latitude (99 deg)
            SensorEvent {
                schema_version: NATIVE_PIPELINE_SCHEMA_VERSION,
                source_id: SensorSourceId::Gps,
                source_timestamp_ns: Some(self.base_timestamp_ns + 110_000_000),
                native_received_timestamp_ns: self.base_timestamp_ns + 120_000_000,
                sequence: 6,
                quality_flags: SensorQualityFlags::nominal(),
                payload: SensorPayload::Gps {
                    latitude_deg: 99.0,
                    longitude_deg: 13.0,
                    altitude_m: 1000.0,
                    ground_speed_mps: 10.0,
                    bearing_deg: 0.0,
                    accuracy_m: 5.0,
                },
            },
            // 7. Valid concluding event
            SensorEvent {
                schema_version: NATIVE_PIPELINE_SCHEMA_VERSION,
                source_id: SensorSourceId::Barometer,
                source_timestamp_ns: Some(self.base_timestamp_ns + 130_000_000),
                native_received_timestamp_ns: self.base_timestamp_ns + 140_000_000,
                sequence: 7,
                quality_flags: SensorQualityFlags::nominal(),
                payload: SensorPayload::Barometer {
                    pressure_hpa: 1012.0,
                    temperature_c: Some(16.0),
                },
            },
        ]
    }

    fn generate_combined_stress(&self) -> Vec<SensorEvent> {
        let mut events = Vec::new();
        events.extend(self.generate_normal(50));
        events.extend(self.generate_burst(150));
        events.extend(self.generate_gaps());
        events.extend(self.generate_stale(30));
        events.extend(self.generate_malformed());
        events
    }
}

/// Generates deterministic SkyDrop 1 raw frame sequences.
#[derive(Clone, Debug)]
pub struct SkyDrop1ReplayGenerator {
    base_timestamp_ns: u64,
}

impl SkyDrop1ReplayGenerator {
    #[must_use]
    pub const fn new(base_timestamp_ns: u64) -> Self {
        Self { base_timestamp_ns }
    }

    #[must_use]
    pub fn generate_frames(&self, scenario: SkyDrop1ReplayScenario) -> Vec<SkyDrop1RawFrame> {
        match scenario {
            SkyDrop1ReplayScenario::ValidStream => self.generate_valid_stream(50),
            SkyDrop1ReplayScenario::MalformedFrames => self.generate_malformed_frames(),
            SkyDrop1ReplayScenario::TruncatedFrames => self.generate_truncated_frames(),
            SkyDrop1ReplayScenario::DuplicateFrames => self.generate_duplicate_frames(),
            SkyDrop1ReplayScenario::OutOfOrderFrames => self.generate_out_of_order_frames(),
            SkyDrop1ReplayScenario::SanitizationViolation => {
                self.generate_sanitization_violation_frames()
            }
            SkyDrop1ReplayScenario::CombinedStress => self.generate_combined_stress(),
        }
    }

    fn generate_valid_stream(&self, count: usize) -> Vec<SkyDrop1RawFrame> {
        let mut frames = Vec::with_capacity(count);
        let mut time_ns = self.base_timestamp_ns;
        let mut pressure = 101325;
        let mut alt = 1200;
        let mut vario = 120;

        for seq in 1..=(count as u64) {
            time_ns += 50_000_000; // 20Hz cadence = 50ms
            pressure -= 5;
            alt += 1;
            vario += (seq % 5) as i32;

            let body = format!("LK8EX1,{},{},{},21,95", pressure, alt, vario);
            let csum = calculate_nmea_checksum(&body);
            let raw_text = format!("${}*{:02X}\r\n", body, csum);

            frames.push(SkyDrop1RawFrame {
                schema_version: SKYDROP1_PROTOCOL_SCHEMA_VERSION,
                trace_id: 2000 + seq,
                sequence: seq,
                native_received_timestamp_ns: time_ns,
                raw_payload: raw_text.into_bytes(),
            });
        }
        frames
    }

    fn generate_malformed_frames(&self) -> Vec<SkyDrop1RawFrame> {
        let mut time_ns = self.base_timestamp_ns;
        vec![
            // Valid frame
            {
                time_ns += 50_000_000;
                let body = "LK8EX1,101325,1200,100,20,95";
                let csum = calculate_nmea_checksum(body);
                SkyDrop1RawFrame {
                    schema_version: SKYDROP1_PROTOCOL_SCHEMA_VERSION,
                    trace_id: 3001,
                    sequence: 1,
                    native_received_timestamp_ns: time_ns,
                    raw_payload: format!("${}*{:02X}\r\n", body, csum).into_bytes(),
                }
            },
            // Checksum mismatch
            {
                time_ns += 50_000_000;
                SkyDrop1RawFrame {
                    schema_version: SKYDROP1_PROTOCOL_SCHEMA_VERSION,
                    trace_id: 3002,
                    sequence: 2,
                    native_received_timestamp_ns: time_ns,
                    raw_payload: b"$LK8EX1,101325,1200,100,20,95*00\r\n".to_vec(),
                }
            },
            // Missing prefix
            {
                time_ns += 50_000_000;
                SkyDrop1RawFrame {
                    schema_version: SKYDROP1_PROTOCOL_SCHEMA_VERSION,
                    trace_id: 3003,
                    sequence: 3,
                    native_received_timestamp_ns: time_ns,
                    raw_payload: b"LK8EX1,101325,1200,100,20,95*3B\r\n".to_vec(),
                }
            },
            // Blocked unverified proprietary sentence
            {
                time_ns += 50_000_000;
                let body = "PGRMZ,1200,m,3";
                let csum = calculate_nmea_checksum(body);
                SkyDrop1RawFrame {
                    schema_version: SKYDROP1_PROTOCOL_SCHEMA_VERSION,
                    trace_id: 3004,
                    sequence: 4,
                    native_received_timestamp_ns: time_ns,
                    raw_payload: format!("${}*{:02X}\r\n", body, csum).into_bytes(),
                }
            },
        ]
    }

    fn generate_truncated_frames(&self) -> Vec<SkyDrop1RawFrame> {
        let mut time_ns = self.base_timestamp_ns;
        vec![
            {
                time_ns += 50_000_000;
                SkyDrop1RawFrame {
                    schema_version: SKYDROP1_PROTOCOL_SCHEMA_VERSION,
                    trace_id: 4001,
                    sequence: 1,
                    native_received_timestamp_ns: time_ns,
                    raw_payload: b"$LK8EX1,1013".to_vec(),
                }
            },
            {
                time_ns += 50_000_000;
                SkyDrop1RawFrame {
                    schema_version: SKYDROP1_PROTOCOL_SCHEMA_VERSION,
                    trace_id: 4002,
                    sequence: 2,
                    native_received_timestamp_ns: time_ns,
                    raw_payload: b"".to_vec(),
                }
            },
        ]
    }

    fn generate_duplicate_frames(&self) -> Vec<SkyDrop1RawFrame> {
        let mut time_ns = self.base_timestamp_ns;
        let body = "LK8EX1,101325,1200,100,20,95";
        let csum = calculate_nmea_checksum(body);
        let text = format!("${}*{:02X}\r\n", body, csum).into_bytes();

        time_ns += 50_000_000;
        let frame1 = SkyDrop1RawFrame {
            schema_version: SKYDROP1_PROTOCOL_SCHEMA_VERSION,
            trace_id: 5001,
            sequence: 1,
            native_received_timestamp_ns: time_ns,
            raw_payload: text.clone(),
        };

        time_ns += 50_000_000;
        let frame2 = SkyDrop1RawFrame {
            schema_version: SKYDROP1_PROTOCOL_SCHEMA_VERSION,
            trace_id: 5002,
            sequence: 1, // duplicate sequence!
            native_received_timestamp_ns: time_ns,
            raw_payload: text,
        };

        vec![frame1, frame2]
    }

    fn generate_out_of_order_frames(&self) -> Vec<SkyDrop1RawFrame> {
        let mut time_ns = self.base_timestamp_ns;
        let body = "LK8EX1,101325,1200,100,20,95";
        let csum = calculate_nmea_checksum(body);
        let text = format!("${}*{:02X}\r\n", body, csum).into_bytes();

        time_ns += 50_000_000;
        let frame1 = SkyDrop1RawFrame {
            schema_version: SKYDROP1_PROTOCOL_SCHEMA_VERSION,
            trace_id: 6001,
            sequence: 10,
            native_received_timestamp_ns: time_ns,
            raw_payload: text.clone(),
        };

        time_ns += 50_000_000;
        let frame2 = SkyDrop1RawFrame {
            schema_version: SKYDROP1_PROTOCOL_SCHEMA_VERSION,
            trace_id: 6002,
            sequence: 5, // out of order / regressed sequence!
            native_received_timestamp_ns: time_ns,
            raw_payload: text,
        };

        vec![frame1, frame2]
    }

    fn generate_sanitization_violation_frames(&self) -> Vec<SkyDrop1RawFrame> {
        let mut time_ns = self.base_timestamp_ns;
        vec![
            {
                time_ns += 50_000_000;
                SkyDrop1RawFrame {
                    schema_version: SKYDROP1_PROTOCOL_SCHEMA_VERSION,
                    trace_id: 7001,
                    sequence: 1,
                    native_received_timestamp_ns: time_ns,
                    raw_payload: b"$LK8EX1,101325,1200,pin=4321*00\r\n".to_vec(),
                }
            },
            {
                time_ns += 50_000_000;
                SkyDrop1RawFrame {
                    schema_version: SKYDROP1_PROTOCOL_SCHEMA_VERSION,
                    trace_id: 7002,
                    sequence: 2,
                    native_received_timestamp_ns: time_ns,
                    raw_payload:
                        b"$GPGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,46.9,M,,*47\r\n"
                            .to_vec(),
                }
            },
        ]
    }

    fn generate_combined_stress(&self) -> Vec<SkyDrop1RawFrame> {
        let mut frames = Vec::new();
        frames.extend(self.generate_valid_stream(20));
        frames.extend(self.generate_malformed_frames());
        frames.extend(self.generate_truncated_frames());
        frames.extend(self.generate_duplicate_frames());
        frames.extend(self.generate_out_of_order_frames());
        frames.extend(self.generate_sanitization_violation_frames());
        frames
    }
}

/// Replays a sequence of SkyDrop 1 frames and collects parse results and integrity counters.
pub fn replay_skydrop1_sequence(
    frames: &[SkyDrop1RawFrame],
) -> (
    Vec<Result<SkyDrop1ParsedSample, SkyDrop1ParseError>>,
    SkyDrop1IntegrityCounters,
) {
    let mut results = Vec::with_capacity(frames.len());
    let mut counters = SkyDrop1IntegrityCounters::default();
    let mut last_seq: Option<u64> = None;

    for frame in frames {
        counters.total_frames_received += 1;
        let core_ts = frame.native_received_timestamp_ns + 200_000; // 0.2ms core delay
        let res = parse_skydrop1_frame(frame, last_seq, core_ts);
        match &res {
            Ok(_) => {
                counters.valid_samples_parsed += 1;
                last_seq = Some(frame.sequence);
            }
            Err(SkyDrop1ParseError::NonMonotonicSequence) => {
                counters.parse_failures += 1;
                if let Some(prev) = last_seq
                    && frame.sequence == prev
                {
                    counters.duplicates_detected += 1;
                }
            }
            Err(_) => {
                counters.parse_failures += 1;
            }
        }
        results.push(res);
    }

    (results, counters)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn replay_fixtures_are_deterministic_repeated_three_times() {
        let scenarios = [
            SyntheticReplayScenario::NormalCadence,
            SyntheticReplayScenario::BurstTraffic,
            SyntheticReplayScenario::SensorGaps,
            SyntheticReplayScenario::StaleEvents,
            SyntheticReplayScenario::MalformedRecords,
            SyntheticReplayScenario::CombinedStress,
        ];

        let gen1 = SyntheticReplayGenerator::new(42, 1_000_000_000);
        let gen2 = SyntheticReplayGenerator::new(42, 1_000_000_000);
        let gen3 = SyntheticReplayGenerator::new(42, 1_000_000_000);

        for scenario in scenarios {
            let run1 = gen1.generate_fixture(scenario);
            let run2 = gen2.generate_fixture(scenario);
            let run3 = gen3.generate_fixture(scenario);

            assert_eq!(run1, run2, "Scenario {:?} mismatch run1 vs run2", scenario);
            assert_eq!(run2, run3, "Scenario {:?} mismatch run2 vs run3", scenario);
            assert!(!run1.is_empty());
        }
    }

    #[test]
    fn skydrop1_replay_fixtures_are_deterministic_across_repeated_runs() {
        let scenarios = [
            SkyDrop1ReplayScenario::ValidStream,
            SkyDrop1ReplayScenario::MalformedFrames,
            SkyDrop1ReplayScenario::TruncatedFrames,
            SkyDrop1ReplayScenario::DuplicateFrames,
            SkyDrop1ReplayScenario::OutOfOrderFrames,
            SkyDrop1ReplayScenario::SanitizationViolation,
            SkyDrop1ReplayScenario::CombinedStress,
        ];

        let gen1 = SkyDrop1ReplayGenerator::new(1_000_000_000);
        let gen2 = SkyDrop1ReplayGenerator::new(1_000_000_000);
        let gen3 = SkyDrop1ReplayGenerator::new(1_000_000_000);

        for scenario in scenarios {
            let frames1 = gen1.generate_frames(scenario);
            let frames2 = gen2.generate_frames(scenario);
            let frames3 = gen3.generate_frames(scenario);

            assert_eq!(frames1, frames2);
            assert_eq!(frames2, frames3);

            let (res1, count1) = replay_skydrop1_sequence(&frames1);
            let (res2, count2) = replay_skydrop1_sequence(&frames2);
            let (res3, count3) = replay_skydrop1_sequence(&frames3);

            assert_eq!(res1, res2);
            assert_eq!(res2, res3);
            assert_eq!(count1, count2);
            assert_eq!(count2, count3);
        }
    }

    #[test]
    fn skydrop1_valid_stream_produces_zero_failures() {
        let generator = SkyDrop1ReplayGenerator::new(1_000_000_000);
        let frames = generator.generate_frames(SkyDrop1ReplayScenario::ValidStream);
        let (results, counters) = replay_skydrop1_sequence(&frames);

        assert_eq!(counters.total_frames_received, 50);
        assert_eq!(counters.valid_samples_parsed, 50);
        assert_eq!(counters.parse_failures, 0);
        assert_eq!(results.len(), 50);
        for res in results {
            assert!(res.is_ok());
        }
    }

    #[test]
    fn skydrop1_replay_catches_duplicates_and_out_of_order() {
        let generator = SkyDrop1ReplayGenerator::new(1_000_000_000);

        let dup_frames = generator.generate_frames(SkyDrop1ReplayScenario::DuplicateFrames);
        let (dup_res, dup_counters) = replay_skydrop1_sequence(&dup_frames);
        assert_eq!(dup_counters.total_frames_received, 2);
        assert_eq!(dup_counters.valid_samples_parsed, 1);
        assert_eq!(dup_counters.duplicates_detected, 1);
        assert!(dup_res[0].is_ok());
        assert_eq!(dup_res[1], Err(SkyDrop1ParseError::NonMonotonicSequence));

        let ooo_frames = generator.generate_frames(SkyDrop1ReplayScenario::OutOfOrderFrames);
        let (ooo_res, ooo_counters) = replay_skydrop1_sequence(&ooo_frames);
        assert_eq!(ooo_counters.total_frames_received, 2);
        assert_eq!(ooo_counters.valid_samples_parsed, 1);
        assert_eq!(ooo_counters.parse_failures, 1);
        assert_eq!(ooo_res[1], Err(SkyDrop1ParseError::NonMonotonicSequence));
    }
}
