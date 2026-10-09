//! Thermal assistant orchestrator.
//!
//! Composes [`CirclingStateDetector`], [`WindEstimator`] and
//! [`ThermalCoreCalculator`] into one deterministic state machine that is the
//! reference implementation for the on-device (Dart) thermal assistant.
//!
//! Rules on top of the individual components:
//! - Samples flagged stale/invalid are ignored entirely.
//! - A gap of more than [`INTERRUPTION_GAP_MS`] between valid samples is an
//!   interruption: circling detection and the in-progress turn accumulation
//!   are reset, the core buffer is cleared, the last wind estimate is kept.
//! - On a `CIRCLING -> GLIDING` transition the core buffer is cleared.
//! - Output is produced for every valid sample (no barometer dependency).
//! - A thermal core estimate is only published while circling.

use crate::circling::{CirclingStateDetector, FlightState};
use crate::thermal::{ThermalCoreCalculator, ThermalCoreEstimate, TrackPoint};
use crate::wind::{Position, WindEstimator, WindVector};

/// Gap between consecutive valid samples treated as a telemetry interruption.
pub const INTERRUPTION_GAP_MS: u64 = 5_000;

/// One telemetry sample fed into the thermal assistant.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct ThermalSample {
    pub timestamp_ms: u64,
    pub position: Position,
    pub heading_deg: f64,
    pub climb_rate_ms: f64,
    /// Stale or invalid samples are ignored.
    pub stale: bool,
}

/// Output of the thermal assistant after a sample.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct ThermalAssistantOutput {
    pub timestamp_ms: u64,
    pub state: FlightState,
    pub wind: Option<WindVector>,
    /// Timestamp of the last wind refinement.
    pub wind_updated_ms: Option<u64>,
    /// Lift-weighted core estimate, only while circling.
    pub core: Option<ThermalCoreEstimate>,
}

impl Default for ThermalAssistantOutput {
    fn default() -> Self {
        Self {
            timestamp_ms: 0,
            state: FlightState::Gliding,
            wind: None,
            wind_updated_ms: None,
            core: None,
        }
    }
}

/// Deterministic thermal assistant state machine.
#[derive(Default)]
pub struct ThermalAssistant {
    detector: CirclingStateDetector,
    wind: WindEstimator,
    core: ThermalCoreCalculator,
    last_valid_ms: Option<u64>,
    output: ThermalAssistantOutput,
}

impl ThermalAssistant {
    #[must_use]
    pub fn new() -> Self {
        Self::default()
    }

    /// Latest output (unchanged by ignored samples).
    #[must_use]
    pub fn output(&self) -> ThermalAssistantOutput {
        self.output
    }

    /// Clears all state including the wind estimate.
    pub fn reset(&mut self) {
        *self = Self::new();
    }

    /// Processes one sample and returns the updated output.
    pub fn update(&mut self, sample: ThermalSample) -> ThermalAssistantOutput {
        if sample.stale {
            return self.output;
        }

        if let Some(last) = self.last_valid_ms
            && sample.timestamp_ms.saturating_sub(last) > INTERRUPTION_GAP_MS
        {
            self.detector = CirclingStateDetector::new();
            self.wind.reset();
            self.core.reset();
        }
        self.last_valid_ms = Some(sample.timestamp_ms);

        let previous = self.detector.state();
        let state = self
            .detector
            .update(sample.timestamp_ms, sample.heading_deg);
        let is_circling = matches!(state, FlightState::Circling(_));

        if matches!(previous, FlightState::Circling(_)) && !is_circling {
            self.core.reset();
        }

        let wind_before = self.wind.estimate();
        self.wind.update(
            sample.timestamp_ms,
            sample.heading_deg,
            sample.position,
            is_circling,
        );
        let wind = self.wind.estimate();
        let wind_updated_ms = if wind != wind_before {
            Some(sample.timestamp_ms)
        } else {
            self.output.wind_updated_ms
        };

        self.core.add_point(TrackPoint {
            timestamp_ms: sample.timestamp_ms,
            position: sample.position,
            climb_rate_ms: sample.climb_rate_ms,
        });
        let core = if is_circling {
            Some(self.core.calculate(sample.timestamp_ms, wind)).filter(|c| c.valid)
        } else {
            None
        };

        self.output = ThermalAssistantOutput {
            timestamp_ms: sample.timestamp_ms,
            state,
            wind,
            wind_updated_ms,
            core,
        };
        self.output
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::circling::TurnDirection;

    const R_EARTH: f64 = 6_371_000.0;

    /// Simple kinematic flyer used by the tests.
    struct Flyer {
        t_ms: u64,
        lat: f64,
        lon: f64,
        heading: f64,
    }

    impl Flyer {
        fn new() -> Self {
            Self {
                t_ms: 1_000,
                lat: 47.0,
                lon: 13.0,
                heading: 0.0,
            }
        }

        /// Advances 1 s with turn rate, airspeed and wind drift (m/s east/north).
        fn step(
            &mut self,
            turn_dps: f64,
            airspeed: f64,
            wind_e: f64,
            wind_n: f64,
        ) -> ThermalSample {
            self.heading = (self.heading + turn_dps).rem_euclid(360.0);
            let h = self.heading.to_radians();
            let ve = airspeed * h.sin() + wind_e;
            let vn = airspeed * h.cos() + wind_n;
            self.lat += vn / R_EARTH * 180.0 / std::f64::consts::PI;
            self.lon += ve / (R_EARTH * self.lat.to_radians().cos()) * 180.0 / std::f64::consts::PI;
            self.t_ms += 1_000;
            ThermalSample {
                timestamp_ms: self.t_ms,
                position: Position {
                    lat: self.lat,
                    lon: self.lon,
                },
                heading_deg: self.heading,
                climb_rate_ms: 2.0,
                stale: false,
            }
        }
    }

    #[test]
    fn enters_circling_and_estimates_wind() {
        let mut ta = ThermalAssistant::new();
        let mut f = Flyer::new();
        let mut out = ta.output();
        for _ in 0..90 {
            out = ta.update(f.step(18.0, 10.0, 10.0, 0.0));
        }
        assert_eq!(out.state, FlightState::Circling(TurnDirection::Right));
        let wind = out.wind.expect("wind estimated");
        assert!((wind.direction_deg - 270.0).abs() < 5.0, "{wind:?}");
        assert!((wind.speed_kmh - 36.0).abs() < 2.0, "{wind:?}");
        assert!(out.wind_updated_ms.is_some());
        assert!(out.core.is_some());
    }

    #[test]
    fn output_without_barometer_on_every_sample() {
        let mut ta = ThermalAssistant::new();
        let mut f = Flyer::new();
        let out = ta.update(f.step(0.0, 10.0, 0.0, 0.0));
        assert_eq!(out.timestamp_ms, f.t_ms);
        assert_eq!(out.state, FlightState::Gliding);
        assert!(out.core.is_none());
        assert!(out.wind.is_none());
    }

    #[test]
    fn glide_exit_clears_core_and_keeps_wind() {
        let mut ta = ThermalAssistant::new();
        let mut f = Flyer::new();
        for _ in 0..90 {
            ta.update(f.step(18.0, 10.0, 5.0, 0.0));
        }
        let wind = ta.output().wind;
        assert!(wind.is_some());
        let mut out = ta.output();
        for _ in 0..12 {
            out = ta.update(f.step(0.0, 10.0, 5.0, 0.0));
        }
        assert_eq!(out.state, FlightState::Gliding);
        assert!(out.core.is_none());
        assert_eq!(out.wind, wind);
    }

    #[test]
    fn stale_samples_are_ignored() {
        let mut ta = ThermalAssistant::new();
        let mut f = Flyer::new();
        let before = ta.update(f.step(0.0, 10.0, 0.0, 0.0));
        let mut s = f.step(90.0, 10.0, 0.0, 0.0);
        s.stale = true;
        assert_eq!(ta.update(s), before);
    }

    #[test]
    fn gap_interrupts_circling_but_keeps_wind() {
        let mut ta = ThermalAssistant::new();
        let mut f = Flyer::new();
        for _ in 0..90 {
            ta.update(f.step(18.0, 10.0, 5.0, 0.0));
        }
        let wind = ta.output().wind;
        assert!(matches!(ta.output().state, FlightState::Circling(_)));
        f.t_ms += 6_000;
        let out = ta.update(f.step(18.0, 10.0, 5.0, 0.0));
        assert_eq!(out.state, FlightState::Gliding);
        assert!(out.core.is_none());
        assert_eq!(out.wind, wind);
    }
}
