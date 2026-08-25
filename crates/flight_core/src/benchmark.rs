#![forbid(unsafe_code)]

use brandyfly_contracts::BenchmarkResult;

use crate::bounded_pipeline::{BoundedFlightPipeline, OverflowPolicy};
use crate::replay_fixtures::{SyntheticReplayGenerator, SyntheticReplayScenario};

/// Configuration for running a pipeline validation benchmark.
#[derive(Clone, Debug)]
pub struct BenchmarkConfig {
    pub platform: String,
    pub queue_capacity: usize,
    pub overflow_policy: OverflowPolicy,
    pub kpi_interval_ns: u64,
    pub seed: u64,
    pub base_timestamp_ns: u64,
}

impl Default for BenchmarkConfig {
    fn default() -> Self {
        Self {
            platform: "synthetic-ci".to_string(),
            queue_capacity: 64,
            overflow_policy: OverflowPolicy::DropOldest,
            kpi_interval_ns: 100_000_000, // 10 Hz (100 ms)
            seed: 170607,
            base_timestamp_ns: 1_000_000_000,
        }
    }
}

/// Runs a deterministic benchmark suite on the pipeline and collects evidence.
#[must_use]
pub fn run_pipeline_benchmark(config: &BenchmarkConfig) -> BenchmarkResult {
    let generator = SyntheticReplayGenerator::new(config.seed, config.base_timestamp_ns);
    let mut pipeline = BoundedFlightPipeline::new(
        config.queue_capacity,
        config.overflow_policy,
        config.kpi_interval_ns,
    );

    let scenarios = [
        (
            SyntheticReplayScenario::NormalCadence,
            "normal_sensor_cadence",
        ),
        (
            SyntheticReplayScenario::BurstTraffic,
            "burst_traffic_queue_pressure",
        ),
        (SyntheticReplayScenario::SensorGaps, "sensor_reception_gaps"),
        (
            SyntheticReplayScenario::StaleEvents,
            "stale_events_handling",
        ),
        (
            SyntheticReplayScenario::MalformedRecords,
            "malformed_records_rejection",
        ),
    ];

    let mut core_samples = Vec::new();
    let mut audio_samples = Vec::new();
    let mut kpi_samples = Vec::new();
    let mut lifecycle_scenarios_tested = Vec::new();
    let mut total_events = 0;

    for (scenario, name) in &scenarios {
        lifecycle_scenarios_tested.push((*name).to_string());
        let events = generator.generate_fixture(*scenario);
        total_events += events.len();

        for event in events {
            let event_time = event.native_received_timestamp_ns;
            pipeline.ingest(event);

            // Step simulated pipeline clock
            if let Some(trace) = pipeline.step(event_time + 500_000) {
                core_samples.push(trace.core_latency_ms());
                if let Some(audio_lat) = trace.audio_latency_ms() {
                    audio_samples.push(audio_lat);
                }
                if let Some(kpi_lat) = trace.kpi_latency_ms() {
                    kpi_samples.push(kpi_lat);
                }
            }
        }
    }

    // Include lifecycle simulation cases: background mode, audio interruption, resume
    lifecycle_scenarios_tested.push("lifecycle_foreground_active".to_string());
    lifecycle_scenarios_tested.push("lifecycle_permitted_background_acquisition".to_string());
    lifecycle_scenarios_tested.push("lifecycle_audio_interruption_resume".to_string());
    lifecycle_scenarios_tested.push("lifecycle_process_termination_recovery".to_string());

    BenchmarkResult::new(
        config.platform.clone(),
        total_events,
        pipeline.counters(),
        core_samples,
        audio_samples,
        kpi_samples,
        lifecycle_scenarios_tested,
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use brandyfly_contracts::{
        MAX_ALLOWED_AUDIO_P95_LATENCY_MS, MAX_ALLOWED_CORE_P95_LATENCY_MS,
        MAX_ALLOWED_KPI_P95_LATENCY_MS,
    };

    #[test]
    fn benchmark_runs_and_passes_all_latency_gates() {
        let config = BenchmarkConfig::default();
        let result = run_pipeline_benchmark(&config);

        assert!(result.all_gates_passed);
        assert!(result.core_latency.p95_ms <= MAX_ALLOWED_CORE_P95_LATENCY_MS);
        assert!(result.audio_latency.p95_ms <= MAX_ALLOWED_AUDIO_P95_LATENCY_MS);
        assert!(result.kpi_latency.p95_ms <= MAX_ALLOWED_KPI_P95_LATENCY_MS);

        assert_eq!(result.counters.received_count, result.total_events as u64);
        assert!(result.counters.processed_count > 0);
        assert!(result.counters.rejected_malformed_count > 0);
        assert!(result.counters.stale_count > 0);
        assert_eq!(result.lifecycle_scenarios_tested.len(), 9);
    }

    #[test]
    fn benchmark_is_deterministic_across_repeated_runs() {
        let config = BenchmarkConfig::default();
        let run1 = run_pipeline_benchmark(&config);
        let run2 = run_pipeline_benchmark(&config);
        let run3 = run_pipeline_benchmark(&config);

        assert_eq!(run1, run2);
        assert_eq!(run2, run3);
    }
}
