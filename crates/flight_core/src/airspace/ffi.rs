//! Safe C-ABI / Native Assets boundary for airspace queries and proximity evaluations.

use std::sync::Mutex;

use super::ast::{Airspace, Coordinate};
use super::fixtures::DACH_OPENAIR_SAMPLE;
use super::parser::parse_openair;
use super::proximity::{AirspaceProximityEngine, AlertLevel, project_glide_slope};
use super::spatial::RTree;

/// C-compatible input structure for single-cycle airspace proximity queries.
#[repr(C)]
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct AirspaceEvaluationInput {
    pub latitude: f64,
    pub longitude: f64,
    pub altitude_msl: f64,
    pub groundspeed_mps: f64,
    pub track_heading_deg: f64,
    pub glide_ratio: f64,
    pub qnh_hpa: f64,
    pub terrain_elevation_msl: f64,
    pub timestamp_ms: u64,
}

/// C-compatible output structure surfacing top proximity metrics and alert status.
#[repr(C)]
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct AirspaceEvaluationOutput {
    /// 0 = None, 1 = Advisory, 2 = Warning, 3 = Violation
    pub alert_level: u8,
    pub horizontal_separation_m: f64,
    pub vertical_separation_m: f64,
    pub total_3d_distance_m: f64,
    pub is_inside_horizontal: u8,
    pub is_inside_vertical: u8,
    pub floor_msl_m: f64,
    pub ceiling_msl_m: f64,
    pub forward_intersection_distance_m: f64,
    pub forward_intersection_time_s: f64,
    pub will_penetrate_glide_slope: u8,
}

impl Default for AirspaceEvaluationOutput {
    fn default() -> Self {
        Self {
            alert_level: AlertLevel::None as u8,
            horizontal_separation_m: f64::INFINITY,
            vertical_separation_m: f64::INFINITY,
            total_3d_distance_m: f64::INFINITY,
            is_inside_horizontal: 0,
            is_inside_vertical: 0,
            floor_msl_m: 0.0,
            ceiling_msl_m: 0.0,
            forward_intersection_distance_m: -1.0,
            forward_intersection_time_s: -1.0,
            will_penetrate_glide_slope: 0,
        }
    }
}

/// In-memory runtime store for active airspaces and proximity engine.
#[derive(Default)]
pub struct AirspaceStore {
    pub airspaces: Vec<Airspace>,
    pub rtree: RTree<usize>,
    pub proximity_engine: AirspaceProximityEngine,
}

impl AirspaceStore {
    #[must_use]
    pub fn new() -> Self {
        Self::default()
    }

    /// Loads OpenAir formatted string, compiling airspaces and rebuilding spatial index.
    pub fn load_openair_text(&mut self, text: &str) -> usize {
        let result = parse_openair(text);
        let items: Vec<_> = result
            .airspaces
            .iter()
            .enumerate()
            .map(|(idx, a)| (a.bounding_box, idx))
            .collect();
        self.rtree = RTree::bulk_load(items);
        self.airspaces = result.airspaces;
        self.proximity_engine.reset();
        self.airspaces.len()
    }

    /// Clears all loaded airspaces.
    pub fn clear(&mut self) {
        self.airspaces.clear();
        self.rtree = RTree::new();
        self.proximity_engine.reset();
    }

    /// Evaluates proximity for an aircraft telemetry tick.
    pub fn evaluate(&mut self, input: AirspaceEvaluationInput) -> AirspaceEvaluationOutput {
        if self.airspaces.is_empty() {
            return AirspaceEvaluationOutput::default();
        }

        let pos = Coordinate::new(input.latitude, input.longitude);
        // Query candidate airspaces within 15 km
        let candidate_indices = self.rtree.query_radius(pos, 15_000.0);

        let mut top_alert = AlertLevel::None;
        let mut min_h_dist = f64::INFINITY;
        let mut min_v_dist = f64::INFINITY;
        let mut min_3d_dist = f64::INFINITY;
        let mut is_h_in = false;
        let mut is_v_in = false;
        let mut top_floor = 0.0;
        let mut top_ceiling = 0.0;

        for &idx in &candidate_indices {
            let airspace = &self.airspaces[*idx];
            let prox = self.proximity_engine.update_proximity(
                airspace,
                pos,
                input.altitude_msl,
                input.qnh_hpa,
                input.terrain_elevation_msl,
                input.timestamp_ms,
            );

            if prox.alert_level > top_alert
                || (prox.alert_level == top_alert && prox.total_3d_distance_m < min_3d_dist)
            {
                top_alert = prox.alert_level;
                min_h_dist = prox.horizontal_separation_m;
                min_v_dist = prox.vertical_separation_m;
                min_3d_dist = prox.total_3d_distance_m;
                is_h_in = prox.is_horizontally_inside;
                is_v_in = prox.is_vertically_inside;
                top_floor = prox.floor_msl_m;
                top_ceiling = prox.ceiling_msl_m;
            }
        }

        // Project glide slope
        let intersections = project_glide_slope(
            pos,
            input.altitude_msl,
            input.groundspeed_mps,
            input.track_heading_deg,
            input.glide_ratio,
            &self.airspaces,
            input.qnh_hpa,
            input.terrain_elevation_msl,
            10_000.0,
        );

        let (fwd_dist, fwd_time, will_penetrate) = if let Some(first_inter) = intersections.first()
        {
            (
                first_inter.entry_distance_m,
                first_inter.time_to_entry_seconds,
                if first_inter.will_penetrate { 1 } else { 0 },
            )
        } else {
            (-1.0, -1.0, 0)
        };

        AirspaceEvaluationOutput {
            alert_level: top_alert as u8,
            horizontal_separation_m: min_h_dist,
            vertical_separation_m: min_v_dist,
            total_3d_distance_m: min_3d_dist,
            is_inside_horizontal: if is_h_in { 1 } else { 0 },
            is_inside_vertical: if is_v_in { 1 } else { 0 },
            floor_msl_m: top_floor,
            ceiling_msl_m: top_ceiling,
            forward_intersection_distance_m: fwd_dist,
            forward_intersection_time_s: fwd_time,
            will_penetrate_glide_slope: will_penetrate,
        }
    }
}

static AIRSPACE_STORE: Mutex<Option<AirspaceStore>> = Mutex::new(None);

fn with_store<R, F: FnOnce(&mut AirspaceStore) -> R>(f: F) -> R {
    let mut guard = AIRSPACE_STORE.lock().unwrap();
    let store = guard.get_or_insert_with(AirspaceStore::new);
    f(store)
}

/// Initializes or resets the global airspace store.
pub extern "C" fn airspace_init_store() -> u32 {
    with_store(|store| {
        store.clear();
        1
    })
}

/// Loads the standard European/DACH test fixture into the global store.
pub extern "C" fn airspace_load_dach_fixture() -> u32 {
    with_store(|store| store.load_openair_text(DACH_OPENAIR_SAMPLE) as u32)
}

/// Clears all airspaces from the global store.
pub extern "C" fn airspace_clear_store() -> u32 {
    with_store(|store| {
        store.clear();
        0
    })
}

/// Returns the number of loaded airspaces.
pub extern "C" fn airspace_count() -> u32 {
    with_store(|store| store.airspaces.len() as u32)
}

/// Evaluates aircraft proximity against loaded airspaces.
pub extern "C" fn airspace_evaluate(input: AirspaceEvaluationInput) -> AirspaceEvaluationOutput {
    with_store(|store| store.evaluate(input))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_ffi_lifecycle_and_evaluation() {
        assert_eq!(airspace_init_store(), 1);
        let count = airspace_load_dach_fixture();
        assert_eq!(count, 7);
        assert_eq!(airspace_count(), 7);

        // Aircraft inside Innsbruck CTR (lat 47.233 to 47.300, lon 11.166 to 11.583)
        let input = AirspaceEvaluationInput {
            latitude: 47.26,
            longitude: 11.25,
            altitude_msl: 800.0,
            groundspeed_mps: 12.0,
            track_heading_deg: 90.0,
            glide_ratio: 8.0,
            qnh_hpa: 1013.25,
            terrain_elevation_msl: 580.0,
            timestamp_ms: 1000,
        };

        let output = airspace_evaluate(input);
        assert_eq!(output.alert_level, 3); // Violation
        assert_eq!(output.is_inside_horizontal, 1);
        assert_eq!(output.is_inside_vertical, 1);

        assert_eq!(airspace_clear_store(), 0);
        assert_eq!(airspace_count(), 0);
    }
}
