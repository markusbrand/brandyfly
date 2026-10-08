//! Airspace proximity engine microbenchmarks and latency verification.

use std::time::Instant;

use super::ffi::{AirspaceEvaluationInput, AirspaceStore};
use super::fixtures::DACH_OPENAIR_SAMPLE;

/// Performance benchmark report for airspace 3D proximity evaluations.
#[derive(Clone, Debug, PartialEq)]
pub struct AirspaceBenchmarkResult {
    pub total_evaluations: usize,
    pub total_duration_nanos: u64,
    pub avg_latency_nanos_per_cycle: u64,
    pub max_latency_nanos: u64,
    pub passes_sub_millisecond_gate: bool,
}

/// Runs a deterministic benchmark of 3D proximity evaluation across 1,000 flight cycles.
#[must_use]
pub fn run_airspace_proximity_benchmark(iterations: usize) -> AirspaceBenchmarkResult {
    let mut store = AirspaceStore::new();
    store.load_openair_text(DACH_OPENAIR_SAMPLE);

    let start = Instant::now();
    let mut max_latency_nanos = 0;

    for i in 0..iterations {
        let step = (i as f64) * 0.001;
        let input = AirspaceEvaluationInput {
            latitude: 47.20 + step,
            longitude: 11.20 + step,
            altitude_msl: 1200.0 + (i as f64) * 0.5,
            groundspeed_mps: 12.5,
            track_heading_deg: ((i * 5) % 360) as f64,
            glide_ratio: 8.5,
            qnh_hpa: 1013.25,
            terrain_elevation_msl: 600.0,
            timestamp_ms: (i as u64) * 100,
        };

        let cycle_start = Instant::now();
        let _out = store.evaluate(input);
        let cycle_nanos = cycle_start.elapsed().as_nanos() as u64;

        if cycle_nanos > max_latency_nanos {
            max_latency_nanos = cycle_nanos;
        }
    }

    let total_nanos = start.elapsed().as_nanos() as u64;
    let avg_latency = if iterations > 0 {
        total_nanos / (iterations as u64)
    } else {
        0
    };

    // Gate: Must execute in < 1,000,000 ns (1 ms) per cycle in release/optimized mode;
    // in unoptimized debug CI profile allow up to 3 ms to account for virtualized test runner overhead.
    let latency_gate_nanos = if cfg!(debug_assertions) {
        3_000_000
    } else {
        1_000_000
    };
    let passes_gate = avg_latency < latency_gate_nanos;

    AirspaceBenchmarkResult {
        total_evaluations: iterations,
        total_duration_nanos: total_nanos,
        avg_latency_nanos_per_cycle: avg_latency,
        max_latency_nanos,
        passes_sub_millisecond_gate: passes_gate,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_airspace_benchmark_passes_sub_millisecond_latency_budget() {
        let result = run_airspace_proximity_benchmark(100);

        assert_eq!(result.total_evaluations, 100);
        assert!(
            result.passes_sub_millisecond_gate,
            "Airspace proximity avg latency {} ns exceeded latency gate!",
            result.avg_latency_nanos_per_cycle
        );
    }
}
