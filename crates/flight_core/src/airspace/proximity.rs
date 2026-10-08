//! 3D Airspace proximity detection, multi-tier warning state machine, hysteresis debouncing,
//! and forward glide slope trajectory projection.

use std::collections::HashMap;

use super::ast::{Airspace, AirspaceClass, BoundingBox, Coordinate};
use super::parser::geodesic_destination;
use super::spatial::distance_point_to_polygon_meters;
use super::vertical::resolve_airspace_vertical_bounds_meters;

/// Multi-tier proximity warning level for airspace avoidance.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub enum AlertLevel {
    /// Normal flight clearance (safe distance)
    None = 0,
    /// Level 1 Advisory: within 1000m horizontal or 150m vertical
    Level1Advisory = 1,
    /// Level 2 Warning: within 500m horizontal or 75m vertical
    Level2Warning = 2,
    /// Level 3 Violation: inside horizontal polygon and between floor and ceiling
    Level3Violation = 3,
}

impl AlertLevel {
    /// Human-readable label for HUD and banner display.
    #[must_use]
    pub const fn as_str(&self) -> &'static str {
        match self {
            Self::None => "CLEAR",
            Self::Level1Advisory => "ADVISORY",
            Self::Level2Warning => "WARNING",
            Self::Level3Violation => "VIOLATION",
        }
    }
}

/// Instantaneous 3D proximity metric between aircraft and an airspace.
#[derive(Clone, Debug, PartialEq)]
pub struct AirspaceProximity {
    pub airspace_id: String,
    pub airspace_name: String,
    pub airspace_class: AirspaceClass,
    pub horizontal_separation_m: f64,
    pub vertical_separation_m: f64,
    pub total_3d_distance_m: f64,
    pub is_horizontally_inside: bool,
    pub is_vertically_inside: bool,
    pub floor_msl_m: f64,
    pub ceiling_msl_m: f64,
    pub alert_level: AlertLevel,
    pub vector_to_nearest_m: (f64, f64, f64),
}

/// Hysteresis tracker for an individual airspace alert level.
#[derive(Clone, Debug, PartialEq)]
pub struct AirspaceHysteresisState {
    pub current_level: AlertLevel,
    pub candidate_level: AlertLevel,
    pub candidate_first_seen_ms: u64,
}

impl AirspaceHysteresisState {
    #[must_use]
    pub const fn new() -> Self {
        Self {
            current_level: AlertLevel::None,
            candidate_level: AlertLevel::None,
            candidate_first_seen_ms: 0,
        }
    }
}

impl Default for AirspaceHysteresisState {
    fn default() -> Self {
        Self::new()
    }
}

/// Evaluates instantaneous 3D proximity metrics between aircraft and a candidate airspace.
#[must_use]
pub fn evaluate_airspace_proximity(
    airspace: &Airspace,
    aircraft_pos: Coordinate,
    aircraft_alt_msl: f64,
    qnh_hpa: f64,
    terrain_elevation_msl: f64,
) -> AirspaceProximity {
    let (h_dist_m, is_h_inside, closest_xy) =
        distance_point_to_polygon_meters(aircraft_pos, &airspace.polygon);

    let (floor_m, ceiling_m) = resolve_airspace_vertical_bounds_meters(
        airspace.floor,
        airspace.ceiling,
        qnh_hpa,
        terrain_elevation_msl,
    );

    let (v_dist_m, is_v_inside, delta_z) = if aircraft_alt_msl < floor_m {
        (
            floor_m - aircraft_alt_msl,
            false,
            floor_m - aircraft_alt_msl,
        )
    } else if aircraft_alt_msl > ceiling_m {
        (
            aircraft_alt_msl - ceiling_m,
            false,
            ceiling_m - aircraft_alt_msl,
        )
    } else {
        (0.0, true, 0.0)
    };

    let total_3d = (h_dist_m.powi(2) + v_dist_m.powi(2)).sqrt();

    // Alert level determination matching spec:
    // Level 3 Violation: horizontally inside and vertically inside
    // Level 2 Warning: inside horizontal with dV < 75m, or outside horizontal with dH < 500m and (dV < 75m or vertically inside)
    // Level 1 Advisory: inside horizontal with dV < 150m, or outside horizontal with dH < 1000m and (dV < 150m or vertically inside)
    let raw_level = if is_h_inside {
        if is_v_inside {
            AlertLevel::Level3Violation
        } else if v_dist_m < 75.0 {
            AlertLevel::Level2Warning
        } else if v_dist_m < 150.0 {
            AlertLevel::Level1Advisory
        } else {
            AlertLevel::None
        }
    } else if h_dist_m < 500.0 && (is_v_inside || v_dist_m < 75.0) {
        AlertLevel::Level2Warning
    } else if h_dist_m < 1000.0 && (is_v_inside || v_dist_m < 150.0) {
        AlertLevel::Level1Advisory
    } else {
        AlertLevel::None
    };

    AirspaceProximity {
        airspace_id: airspace.id.clone(),
        airspace_name: airspace.name.clone(),
        airspace_class: airspace.class.clone(),
        horizontal_separation_m: h_dist_m,
        vertical_separation_m: v_dist_m,
        total_3d_distance_m: total_3d,
        is_horizontally_inside: is_h_inside,
        is_vertically_inside: is_v_inside,
        floor_msl_m: floor_m,
        ceiling_msl_m: ceiling_m,
        alert_level: raw_level,
        vector_to_nearest_m: (closest_xy.0, closest_xy.1, delta_z),
    }
}

/// Proximity engine managing alert states and hysteresis across telemetry cycles.
#[derive(Clone, Debug, Default)]
pub struct AirspaceProximityEngine {
    states: HashMap<String, AirspaceHysteresisState>,
}

impl AirspaceProximityEngine {
    #[must_use]
    pub fn new() -> Self {
        Self {
            states: HashMap::new(),
        }
    }

    /// Evaluates proximity for an airspace and applies hysteresis rules:
    /// - Escalation is instantaneous.
    /// - Downgrades require separation > threshold * 1.10 sustained for >= 2000 ms.
    pub fn update_proximity(
        &mut self,
        airspace: &Airspace,
        aircraft_pos: Coordinate,
        aircraft_alt_msl: f64,
        qnh_hpa: f64,
        terrain_elevation_msl: f64,
        timestamp_ms: u64,
    ) -> AirspaceProximity {
        let mut prox = evaluate_airspace_proximity(
            airspace,
            aircraft_pos,
            aircraft_alt_msl,
            qnh_hpa,
            terrain_elevation_msl,
        );

        let state = self.states.entry(airspace.id.clone()).or_default();

        let raw_level = prox.alert_level;
        let current_level = state.current_level;

        let final_level = if raw_level > current_level {
            // Immediate escalation
            state.current_level = raw_level;
            state.candidate_level = raw_level;
            state.candidate_first_seen_ms = timestamp_ms;
            raw_level
        } else if raw_level < current_level {
            // Check hysteresis downgrade clearance (+10% margin)
            let clearance_met = match current_level {
                AlertLevel::Level3Violation => {
                    // Downgrade from violation requires separation outside violation
                    !prox.is_horizontally_inside || !prox.is_vertically_inside
                }
                AlertLevel::Level2Warning => {
                    // Warning threshold was 500m / 75m -> +10% is 550m / 82.5m
                    prox.horizontal_separation_m > 550.0 || prox.vertical_separation_m > 82.5
                }
                AlertLevel::Level1Advisory => {
                    // Advisory threshold was 1000m / 150m -> +10% is 1100m / 165m
                    prox.horizontal_separation_m > 1100.0 || prox.vertical_separation_m > 165.0
                }
                AlertLevel::None => true,
            };

            if clearance_met {
                if state.candidate_level != raw_level {
                    state.candidate_level = raw_level;
                    state.candidate_first_seen_ms = timestamp_ms;
                    current_level
                } else if timestamp_ms.saturating_sub(state.candidate_first_seen_ms) >= 2000 {
                    state.current_level = raw_level;
                    raw_level
                } else {
                    current_level
                }
            } else {
                // Not cleared by +10%, hold current level
                state.candidate_level = current_level;
                current_level
            }
        } else {
            // Same level
            state.candidate_level = current_level;
            current_level
        };

        prox.alert_level = final_level;
        prox
    }

    /// Resets all alert states (e.g. at start of new flight).
    pub fn reset(&mut self) {
        self.states.clear();
    }
}

/// Intersection between projected flight path and an airspace block.
#[derive(Clone, Debug, PartialEq)]
pub struct ForwardAirspaceIntersection {
    pub airspace_id: String,
    pub airspace_name: String,
    pub airspace_class: AirspaceClass,
    pub entry_distance_m: f64,
    pub exit_distance_m: f64,
    pub entry_altitude_msl_m: f64,
    pub time_to_entry_seconds: f64,
    pub floor_msl_m: f64,
    pub ceiling_msl_m: f64,
    pub will_penetrate: bool,
}

/// Projects glider glide slope forward along track heading and calculates potential airspace penetration.
/// Formula: z(x) = h_0 - x / (L/D)
#[allow(clippy::too_many_arguments)]
#[must_use]
pub fn project_glide_slope(
    aircraft_pos: Coordinate,
    aircraft_alt_msl: f64,
    groundspeed_mps: f64,
    track_heading_deg: f64,
    glide_ratio: f64,
    airspaces: &[Airspace],
    qnh_hpa: f64,
    terrain_elevation_msl: f64,
    lookahead_distance_m: f64,
) -> Vec<ForwardAirspaceIntersection> {
    if groundspeed_mps <= 0.5 || glide_ratio <= 1.0 {
        return Vec::new();
    }

    let clamped_ld = glide_ratio.clamp(3.0, 15.0);
    let sample_step_m = 100.0;
    let num_samples = (lookahead_distance_m / sample_step_m).ceil() as usize;

    let mut forward_points = Vec::with_capacity(num_samples + 1);
    for i in 0..=num_samples {
        let x = (i as f64) * sample_step_m;
        let coord = geodesic_destination(aircraft_pos, x, track_heading_deg.to_radians());
        let alt = aircraft_alt_msl - (x / clamped_ld);
        forward_points.push((x, coord, alt));
    }

    let mut intersections = Vec::new();

    let end_coord = forward_points
        .last()
        .map(|(_, c, _)| *c)
        .unwrap_or(aircraft_pos);
    let track_bbox = BoundingBox {
        min_lat: aircraft_pos.latitude.min(end_coord.latitude) - 0.02,
        max_lat: aircraft_pos.latitude.max(end_coord.latitude) + 0.02,
        min_lon: aircraft_pos.longitude.min(end_coord.longitude) - 0.02,
        max_lon: aircraft_pos.longitude.max(end_coord.longitude) + 0.02,
    };

    for airspace in airspaces {
        if !airspace.bounding_box.intersects(&track_bbox) {
            continue;
        }

        let (floor_m, ceiling_m) = resolve_airspace_vertical_bounds_meters(
            airspace.floor,
            airspace.ceiling,
            qnh_hpa,
            terrain_elevation_msl,
        );

        let mut entry_dist: Option<f64> = None;
        let mut exit_dist: Option<f64> = None;
        let mut entry_alt = aircraft_alt_msl;
        let mut penetrates = false;

        for (x, coord, alt) in &forward_points {
            let (_, is_inside, _) = distance_point_to_polygon_meters(*coord, &airspace.polygon);

            if is_inside {
                if entry_dist.is_none() {
                    entry_dist = Some(*x);
                    entry_alt = *alt;
                }
                exit_dist = Some(*x);

                if *alt >= floor_m && *alt <= ceiling_m {
                    penetrates = true;
                }
            }
        }

        if let (Some(entry), Some(exit)) = (entry_dist, exit_dist) {
            let time_to_entry = entry / groundspeed_mps;
            intersections.push(ForwardAirspaceIntersection {
                airspace_id: airspace.id.clone(),
                airspace_name: airspace.name.clone(),
                airspace_class: airspace.class.clone(),
                entry_distance_m: entry,
                exit_distance_m: exit,
                entry_altitude_msl_m: entry_alt,
                time_to_entry_seconds: time_to_entry,
                floor_msl_m: floor_m,
                ceiling_msl_m: ceiling_m,
                will_penetrate: penetrates,
            });
        }
    }

    intersections.sort_by(|a, b| {
        a.entry_distance_m
            .partial_cmp(&b.entry_distance_m)
            .unwrap_or(std::cmp::Ordering::Equal)
    });

    intersections
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::airspace::ast::{AirspaceClass, VerticalLimit};

    fn make_test_airspace() -> Airspace {
        let coords = vec![
            Coordinate::new(47.20, 11.20),
            Coordinate::new(47.30, 11.20),
            Coordinate::new(47.30, 11.40),
            Coordinate::new(47.20, 11.40),
            Coordinate::new(47.20, 11.20),
        ];
        Airspace::new(
            "ctr-test".to_string(),
            "CTR TEST".to_string(),
            AirspaceClass::Ctr,
            VerticalLimit::Surface,
            VerticalLimit::FeetMsl(5000.0), // ~1524m MSL
            coords,
        )
        .expect("Airspace")
    }

    #[test]
    fn test_proximity_evaluation_levels() {
        let airspace = make_test_airspace();

        // 1. Inside both horizontally and vertically -> Level 3 Violation
        let p_violation = evaluate_airspace_proximity(
            &airspace,
            Coordinate::new(47.25, 11.30),
            1000.0,
            1013.25,
            600.0,
        );
        assert_eq!(p_violation.alert_level, AlertLevel::Level3Violation);
        assert_eq!(p_violation.horizontal_separation_m, 0.0);
        assert_eq!(p_violation.vertical_separation_m, 0.0);

        // 2. Horizontally inside, but vertically 50m above ceiling -> Level 2 Warning
        let p_warning = evaluate_airspace_proximity(
            &airspace,
            Coordinate::new(47.25, 11.30),
            1524.0 + 50.0,
            1013.25,
            600.0,
        );
        assert_eq!(p_warning.alert_level, AlertLevel::Level2Warning);
        assert_eq!(p_warning.horizontal_separation_m, 0.0);
        assert!((p_warning.vertical_separation_m - 50.0).abs() < 1e-4);

        // 3. Horizontally inside, but vertically 100m above ceiling -> Level 1 Advisory
        let p_advisory = evaluate_airspace_proximity(
            &airspace,
            Coordinate::new(47.25, 11.30),
            1524.0 + 100.0,
            1013.25,
            600.0,
        );
        assert_eq!(p_advisory.alert_level, AlertLevel::Level1Advisory);

        // 4. Far away -> None
        let p_none = evaluate_airspace_proximity(
            &airspace,
            Coordinate::new(47.25, 11.30),
            3000.0,
            1013.25,
            600.0,
        );
        assert_eq!(p_none.alert_level, AlertLevel::None);
    }

    #[test]
    fn test_hysteresis_immediate_escalation_and_debounced_downgrade() {
        let mut engine = AirspaceProximityEngine::new();
        let airspace = make_test_airspace();

        // Start far away
        let r1 = engine.update_proximity(
            &airspace,
            Coordinate::new(47.25, 11.30),
            3000.0,
            1013.25,
            600.0,
            1000,
        );
        assert_eq!(r1.alert_level, AlertLevel::None);

        // Instant escalation into Violation
        let r2 = engine.update_proximity(
            &airspace,
            Coordinate::new(47.25, 11.30),
            1000.0,
            1013.25,
            600.0,
            2000,
        );
        assert_eq!(r2.alert_level, AlertLevel::Level3Violation);

        // Aircraft climbs above ceiling to 1550m (Warning zone: 26m above 1524m < 75m)
        // At t = 2500 (+500ms), alert should remain Violation due to 2s debounce
        let r3 = engine.update_proximity(
            &airspace,
            Coordinate::new(47.25, 11.30),
            1550.0,
            1013.25,
            600.0,
            2500,
        );
        assert_eq!(r3.alert_level, AlertLevel::Level3Violation);

        // At t = 4600 (>2000ms elapsed since first seeing candidate level), downgrade to Warning
        let r4 = engine.update_proximity(
            &airspace,
            Coordinate::new(47.25, 11.30),
            1550.0,
            1013.25,
            600.0,
            4600,
        );
        assert_eq!(r4.alert_level, AlertLevel::Level2Warning);
    }

    #[test]
    fn test_glide_slope_projection_forward_intersection() {
        let airspace = make_test_airspace();
        let airspaces = vec![airspace];

        // Aircraft flying heading 90 (East) towards the airspace at 10 m/s
        let pos = Coordinate::new(47.25, 11.10); // West of airspace
        let intersections = project_glide_slope(
            pos, 2200.0, 10.0, 90.0, 8.0, // L/D 8.0
            &airspaces, 1013.25, 600.0, 15_000.0,
        );

        assert!(!intersections.is_empty());
        let inter = &intersections[0];
        assert_eq!(inter.airspace_name, "CTR TEST");
        assert!(inter.entry_distance_m > 0.0);
        assert!(inter.time_to_entry_seconds > 0.0);
        assert!(inter.will_penetrate);
    }
}
