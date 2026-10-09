//! Golden replay fixtures for cross-runtime thermal assistant parity.
//!
//! The scenarios are generated deterministically, run through the reference
//! [`ThermalAssistant`], and serialized to JSON. The Dart port in
//! `apps/mobile/lib/domain/thermal_assistant/` is tested against these files.
//!
//! Inputs are written with Rust's shortest round-trip float formatting so the
//! Dart side parses bit-identical values; expected outputs are computed from
//! those exact values.
//!
//! Regenerate with: `cargo run -p flight_core --bin thermal_fixtures`

use std::fmt::Write as _;

use crate::circling::{FlightState, TurnDirection};
use crate::thermal_assistant::{ThermalAssistant, ThermalAssistantOutput, ThermalSample};
use crate::wind::Position;

/// Schema version of the fixture JSON format.
pub const THERMAL_FIXTURE_SCHEMA_VERSION: u32 = 1;

/// Path of the fixture directory relative to the workspace root.
pub const THERMAL_FIXTURE_DIR: &str = "packages/contracts/fixtures/thermal_assistant";

const R_EARTH: f64 = 6_371_000.0;

/// Deterministic linear congruential generator for reproducible jitter.
struct Lcg(u64);

impl Lcg {
    fn next_unit(&mut self) -> f64 {
        self.0 = self
            .0
            .wrapping_mul(6_364_136_223_846_793_005)
            .wrapping_add(1_442_695_040_888_963_407);
        ((self.0 >> 11) as f64) / ((1_u64 << 53) as f64) * 2.0 - 1.0
    }
}

/// Kinematic glider with a drifting thermal for scenario generation.
struct Sim {
    t_ms: u64,
    lat: f64,
    lon: f64,
    heading: f64,
    airspeed: f64,
    wind_e: f64,
    wind_n: f64,
    /// Thermal core position (metres east/north of origin) at t = 0.
    core_e: f64,
    core_n: f64,
    origin: Position,
    rng: Lcg,
    samples: Vec<ThermalSample>,
}

impl Sim {
    fn new(seed: u64, wind_e: f64, wind_n: f64) -> Self {
        let origin = Position {
            lat: 47.5246,
            lon: 13.6917,
        };
        Self {
            t_ms: 1_700_000_000_000,
            lat: origin.lat,
            lon: origin.lon,
            heading: 37.0,
            airspeed: 10.5,
            wind_e,
            wind_n,
            core_e: 60.0,
            core_n: 40.0,
            origin,
            rng: Lcg(seed),
            samples: Vec::new(),
        }
    }

    fn offset_m(&self) -> (f64, f64) {
        let e = (self.lon - self.origin.lon).to_radians()
            * R_EARTH
            * self.origin.lat.to_radians().cos();
        let n = (self.lat - self.origin.lat).to_radians() * R_EARTH;
        (e, n)
    }

    fn climb(&mut self) -> f64 {
        let t_s = (self.t_ms - 1_700_000_000_000) as f64 / 1000.0;
        let (e, n) = self.offset_m();
        let ce = self.core_e + self.wind_e * t_s;
        let cn = self.core_n + self.wind_n * t_s;
        let d = ((e - ce).powi(2) + (n - cn).powi(2)).sqrt();
        let jitter = self.rng.next_unit() * 0.15;
        (3.2 - d / 28.0).max(-2.2) + jitter
    }

    /// Flies `seconds` at `hz` with the given turn rate (deg/s) and heading jitter.
    fn fly(&mut self, seconds: f64, hz: u32, turn_dps: f64, jitter_deg: f64, stale_every: usize) {
        let dt = 1.0 / f64::from(hz);
        let steps = (seconds * f64::from(hz)).round() as usize;
        for _ in 0..steps {
            self.heading = (self.heading + turn_dps * dt).rem_euclid(360.0);
            let h = self.heading.to_radians();
            let ve = self.airspeed * h.sin() + self.wind_e;
            let vn = self.airspeed * h.cos() + self.wind_n;
            self.lat += (vn * dt / R_EARTH).to_degrees();
            self.lon += (ve * dt / (R_EARTH * self.lat.to_radians().cos())).to_degrees();
            self.t_ms += (dt * 1000.0).round() as u64;
            let reported_heading =
                (self.heading + self.rng.next_unit() * jitter_deg).rem_euclid(360.0);
            let climb = self.climb();
            let stale = stale_every > 0 && (self.samples.len() + 1).is_multiple_of(stale_every);
            self.samples.push(ThermalSample {
                timestamp_ms: self.t_ms,
                position: Position {
                    lat: self.lat,
                    lon: self.lon,
                },
                // Stale samples carry a wild heading to prove they are ignored.
                heading_deg: if stale {
                    (reported_heading + 170.0).rem_euclid(360.0)
                } else {
                    reported_heading
                },
                climb_rate_ms: climb,
                stale,
            });
        }
    }

    /// Simulates a telemetry interruption (no samples) of `ms` milliseconds.
    fn gap(&mut self, ms: u64, turn_dps: f64) {
        let seconds = ms as f64 / 1000.0;
        let before = self.samples.len();
        self.fly(seconds, 1, turn_dps, 0.0, 0);
        self.samples.truncate(before);
    }
}

/// Returns all fixture scenarios as `(name, samples)`.
#[must_use]
pub fn thermal_fixture_scenarios() -> Vec<(&'static str, Vec<ThermalSample>)> {
    let mut out = Vec::new();

    let mut s = Sim::new(11, 0.0, 0.0);
    s.fly(20.0, 1, 0.0, 2.0, 0);
    s.fly(120.0, 1, 19.0, 3.0, 0);
    s.fly(20.0, 1, 0.0, 2.0, 0);
    out.push(("no_wind_thermal", s.samples));

    let mut s = Sim::new(23, 10.0, 0.0);
    s.fly(10.0, 5, 0.0, 2.0, 0);
    s.fly(150.0, 5, -17.0, 3.0, 0);
    s.fly(15.0, 5, 0.0, 2.0, 0);
    out.push(("drift_thermal_10ms", s.samples));

    let mut s = Sim::new(37, 3.0, -2.0);
    s.fly(120.0, 1, 0.0, 5.0, 0);
    out.push(("straight_glide", s.samples));

    let mut s = Sim::new(41, 0.0, 0.0);
    for i in 0..15 {
        let dir = if i % 2 == 0 { 40.0 } else { -40.0 };
        s.fly(4.0, 1, dir, 3.0, 0);
    }
    out.push(("erratic_reversals", s.samples));

    let mut s = Sim::new(53, 4.0, 2.0);
    s.fly(70.0, 1, 19.0, 3.0, 0);
    s.gap(8_000, 19.0);
    s.fly(70.0, 1, 19.0, 3.0, 0);
    out.push(("telemetry_gap", s.samples));

    let mut s = Sim::new(67, 5.0, 0.0);
    s.fly(100.0, 2, 18.5, 3.0, 7);
    out.push(("stale_samples", s.samples));

    out
}

/// Round-trips every sample through its JSON text form so expected outputs are
/// computed on exactly the values a parser of the fixture file will see.
fn roundtrip(sample: ThermalSample) -> ThermalSample {
    let p = |v: f64| -> f64 { format!("{v}").parse().expect("roundtrip float") };
    ThermalSample {
        timestamp_ms: sample.timestamp_ms,
        position: Position {
            lat: p(sample.position.lat),
            lon: p(sample.position.lon),
        },
        heading_deg: p(sample.heading_deg),
        climb_rate_ms: p(sample.climb_rate_ms),
        stale: sample.stale,
    }
}

fn mode_str(state: FlightState) -> (&'static str, &'static str) {
    match state {
        FlightState::Gliding => ("gliding", "none"),
        FlightState::Circling(TurnDirection::Left) => ("circling", "left"),
        FlightState::Circling(TurnDirection::Right) => ("circling", "right"),
        FlightState::Circling(TurnDirection::None) => ("circling", "none"),
    }
}

fn render_expected(out: &ThermalAssistantOutput) -> String {
    let (mode, turn) = mode_str(out.state);
    let wind = match (out.wind, out.wind_updated_ms) {
        (Some(w), Some(updated)) => format!(
            "{{\"speedKmh\":{:.6},\"dirDeg\":{:.6},\"updatedMs\":{updated}}}",
            w.speed_kmh, w.direction_deg
        ),
        _ => "null".to_string(),
    };
    let core = match out.core {
        Some(c) => format!(
            "{{\"lat\":{:.9},\"lon\":{:.9}}}",
            c.center.lat, c.center.lon
        ),
        None => "null".to_string(),
    };
    format!("{{\"mode\":\"{mode}\",\"turn\":\"{turn}\",\"wind\":{wind},\"core\":{core}}}")
}

/// Renders one scenario as fixture JSON (one sample per line).
#[must_use]
pub fn render_thermal_fixture(name: &str, samples: &[ThermalSample]) -> String {
    let mut ta = ThermalAssistant::new();
    let mut json = String::new();
    let _ = writeln!(
        json,
        "{{\"schemaVersion\":{THERMAL_FIXTURE_SCHEMA_VERSION},\"scenario\":\"{name}\",\"samples\":["
    );
    for (i, raw) in samples.iter().enumerate() {
        let s = roundtrip(*raw);
        let out = ta.update(s);
        let sep = if i + 1 == samples.len() { "" } else { "," };
        let _ = writeln!(
            json,
            "{{\"tMs\":{},\"lat\":{},\"lon\":{},\"headingDeg\":{},\"climbMs\":{},\"stale\":{},\"expected\":{}}}{sep}",
            s.timestamp_ms,
            s.position.lat,
            s.position.lon,
            s.heading_deg,
            s.climb_rate_ms,
            s.stale,
            render_expected(&out),
        );
    }
    json.push_str("]}\n");
    json
}

/// Renders all fixtures as `(file name, contents)`.
#[must_use]
pub fn render_all_thermal_fixtures() -> Vec<(String, String)> {
    thermal_fixture_scenarios()
        .into_iter()
        .map(|(name, samples)| {
            (
                format!("{name}.json"),
                render_thermal_fixture(name, &samples),
            )
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn fixture_dir() -> std::path::PathBuf {
        std::path::Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("../..")
            .join(THERMAL_FIXTURE_DIR)
    }

    #[test]
    fn checked_in_fixtures_match_reference_output() {
        for (file, contents) in render_all_thermal_fixtures() {
            let path = fixture_dir().join(&file);
            let on_disk = std::fs::read_to_string(&path).unwrap_or_else(|e| {
                panic!(
                    "missing fixture {}: {e}; run `cargo run -p flight_core --bin thermal_fixtures`",
                    path.display()
                )
            });
            assert!(
                on_disk == contents,
                "fixture {file} is stale; run `cargo run -p flight_core --bin thermal_fixtures`"
            );
        }
    }

    #[test]
    fn scenarios_cover_required_behaviour() {
        let rendered = render_all_thermal_fixtures();
        let get = |n: &str| {
            rendered
                .iter()
                .find(|(f, _)| f == &format!("{n}.json"))
                .map(|(_, c)| c.clone())
                .unwrap()
        };
        assert!(get("no_wind_thermal").contains("\"mode\":\"circling\""));
        assert!(get("drift_thermal_10ms").contains("\"speedKmh\""));
        assert!(!get("straight_glide").contains("\"mode\":\"circling\""));
        assert!(!get("erratic_reversals").contains("\"mode\":\"circling\""));
        assert!(get("stale_samples").contains("\"stale\":true"));
    }
}
