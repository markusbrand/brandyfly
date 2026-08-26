#![forbid(unsafe_code)]

use brandyfly_contracts::{
    NATIVE_PIPELINE_SCHEMA_VERSION, SensorEvent, SensorPayload, SensorQualityFlags, SensorSourceId,
};

/// Abstract trait for telemetry and sensor event providers in the native core.
pub trait TelemetrySource {
    /// Produces the next sensor event for the given timestamp in nanoseconds, or `None` if exhausted/idle.
    fn next_event(&mut self, timestamp_ns: u64) -> Option<SensorEvent>;

    /// Returns a human-readable name of the telemetry source.
    fn name(&self) -> &'static str {
        "TelemetrySource"
    }

    /// Resets the source to its initial state.
    fn reset(&mut self) {}
}

/// Paragliding flight maneuver scenario types.
#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash)]
pub enum ProceduralManeuver {
    /// Steady glide: constant heading, forward speed 35-42 km/h, sink rate 1.0-1.4 m/s.
    SteadyGlide,
    /// 360-degree thermaling turn: circular 360-degree arc, +2.5 m/s climb rate, baro pressure decrease.
    ThermalClimb360,
    /// Sink recovery: heavy sink (-3.0 to -3.5 m/s or steeper) transitioning back to level glide.
    SinkRecovery,
}

/// Procedural synthetic paragliding flight generator for deterministic telemetry streams.
#[derive(Clone, Debug)]
pub struct ProceduralFlightGenerator {
    seed: u64,
    base_timestamp_ns: u64,
    current_timestamp_ns: u64,
    sequence: u64,
    maneuver: ProceduralManeuver,
    current_altitude_m: f64,
    current_lat_deg: f64,
    current_lon_deg: f64,
    current_bearing_deg: f64,
    phase_elapsed_s: f64,
    step_interval_ns: u64,
    emit_gps_next: bool,
}

impl ProceduralFlightGenerator {
    /// Creates a new generator starting at base_timestamp_ns with default SteadyGlide.
    #[must_use]
    pub fn new(seed: u64, base_timestamp_ns: u64) -> Self {
        Self::with_maneuver(seed, base_timestamp_ns, ProceduralManeuver::SteadyGlide)
    }

    /// Creates a new generator configured for a specific maneuver scenario.
    #[must_use]
    pub fn with_maneuver(seed: u64, base_timestamp_ns: u64, maneuver: ProceduralManeuver) -> Self {
        let initial_alt = 1500.0 + ((seed % 50) as f64) * 2.0;
        let initial_lat = 47.5246 + ((seed % 10) as f64) * 0.001;
        let initial_lon = 13.6917 + ((seed % 10) as f64) * 0.001;
        let initial_bearing = 120.0 + ((seed % 30) as f64);

        Self {
            seed,
            base_timestamp_ns,
            current_timestamp_ns: base_timestamp_ns,
            sequence: 0,
            maneuver,
            current_altitude_m: initial_alt,
            current_lat_deg: initial_lat,
            current_lon_deg: initial_lon,
            current_bearing_deg: initial_bearing,
            phase_elapsed_s: 0.0,
            step_interval_ns: 20_000_000, // 50 Hz default step
            emit_gps_next: false,
        }
    }

    #[must_use]
    pub const fn seed(&self) -> u64 {
        self.seed
    }

    #[must_use]
    pub const fn maneuver(&self) -> ProceduralManeuver {
        self.maneuver
    }

    pub fn set_maneuver(&mut self, maneuver: ProceduralManeuver) {
        self.maneuver = maneuver;
        self.phase_elapsed_s = 0.0;
    }

    #[must_use]
    pub const fn current_altitude_m(&self) -> f64 {
        self.current_altitude_m
    }

    #[must_use]
    pub const fn current_lat_deg(&self) -> f64 {
        self.current_lat_deg
    }

    #[must_use]
    pub const fn current_lon_deg(&self) -> f64 {
        self.current_lon_deg
    }

    #[must_use]
    pub const fn current_bearing_deg(&self) -> f64 {
        self.current_bearing_deg
    }

    /// Generates a batch of sensor events for a specific maneuver over a given duration.
    #[must_use]
    pub fn generate_maneuver_events(
        &mut self,
        maneuver: ProceduralManeuver,
        duration_s: f64,
        hz: f64,
    ) -> Vec<SensorEvent> {
        self.set_maneuver(maneuver);
        let total_steps = (duration_s * hz).round() as usize;
        let interval_ns = (1_000_000_000.0 / hz).round() as u64;
        self.step_interval_ns = interval_ns;

        let mut events = Vec::with_capacity(total_steps);
        for _ in 0..total_steps {
            let next_ts = self.current_timestamp_ns + interval_ns;
            if let Some(event) = self.next_event(next_ts) {
                events.push(event);
            }
        }
        events
    }

    /// Converts altitude in meters to standard barometric pressure in hPa.
    #[must_use]
    pub fn altitude_to_pressure_hpa(altitude_m: f64) -> f64 {
        let base_p = 1013.25;
        base_p * (1.0 - (altitude_m / 44330.0)).powf(5.25588)
    }

    /// Advances kinematic state based on active maneuver.
    fn advance_kinematics(&mut self, dt_s: f64) -> (f64, f64, f64) {
        self.phase_elapsed_s += dt_s;

        let (climb_rate_mps, speed_mps, turn_rate_deg_per_s) = match self.maneuver {
            ProceduralManeuver::SteadyGlide => {
                // Forward speed between 35-42 km/h (9.72 - 11.67 m/s), e.g. 38 km/h = 10.55 m/s
                let speed_kmh = 38.0 + ((self.seed % 5) as f64) * 0.8;
                let speed_mps = speed_kmh / 3.6;
                // Steady sink between 1.0 - 1.4 m/s
                let sink_mps = -1.2 - ((self.seed % 3) as f64) * 0.1;
                (sink_mps, speed_mps, 0.0)
            }
            ProceduralManeuver::ThermalClimb360 => {
                // 360 degree turn in 20 seconds = 18 deg/s
                let turn_rate = 18.0;
                // Thermal climb rate averaging +2.5 m/s
                let climb_rate = 2.5 + 0.1 * ((self.phase_elapsed_s * 2.0).sin());
                // Thermaling speed approx 36 km/h = 10 m/s
                let speed_mps = 10.0;
                (climb_rate, speed_mps, turn_rate)
            }
            ProceduralManeuver::SinkRecovery => {
                // First 5 seconds: heavy sink (-3.5 m/s)
                // Next 5 seconds: recovery ramp back to -1.2 m/s
                let (climb_rate, speed_mps) = if self.phase_elapsed_s < 5.0 {
                    (-3.5, 12.0)
                } else if self.phase_elapsed_s < 10.0 {
                    let progress = (self.phase_elapsed_s - 5.0) / 5.0;
                    let sink = -3.5 + progress * 2.3; // -3.5 -> -1.2
                    let spd = 12.0 - progress * 1.5;
                    (sink, spd)
                } else {
                    (-1.2, 10.5)
                };
                (climb_rate, speed_mps, 0.0)
            }
        };

        self.current_altitude_m += climb_rate_mps * dt_s;
        self.current_bearing_deg = (self.current_bearing_deg + turn_rate_deg_per_s * dt_s) % 360.0;
        if self.current_bearing_deg < 0.0 {
            self.current_bearing_deg += 360.0;
        }

        // Project coordinate movement: distance = speed * dt
        let dist_m = speed_mps * dt_s;
        let bearing_rad = self.current_bearing_deg.to_radians();
        let delta_lat = (dist_m * bearing_rad.cos()) / 111_139.0;
        let delta_lon = (dist_m * bearing_rad.sin())
            / (111_139.0 * self.current_lat_deg.to_radians().cos().max(0.1));

        self.current_lat_deg += delta_lat;
        self.current_lon_deg += delta_lon;

        (climb_rate_mps, speed_mps, self.current_bearing_deg)
    }
}

impl TelemetrySource for ProceduralFlightGenerator {
    fn next_event(&mut self, timestamp_ns: u64) -> Option<SensorEvent> {
        let dt_ns = timestamp_ns.saturating_sub(self.current_timestamp_ns);
        let dt_s = if dt_ns > 0 {
            dt_ns as f64 / 1_000_000_000.0
        } else {
            self.step_interval_ns as f64 / 1_000_000_000.0
        };

        self.current_timestamp_ns = timestamp_ns;
        self.sequence += 1;

        let (_climb_rate_mps, speed_mps, bearing_deg) = self.advance_kinematics(dt_s);
        let is_baro = !self.emit_gps_next;
        self.emit_gps_next = !self.emit_gps_next;

        if is_baro {
            // Emit Barometer event
            let pressure_hpa = Self::altitude_to_pressure_hpa(self.current_altitude_m);
            Some(SensorEvent {
                schema_version: NATIVE_PIPELINE_SCHEMA_VERSION,
                source_id: SensorSourceId::Barometer,
                source_timestamp_ns: Some(timestamp_ns.saturating_sub(1_000_000)),
                native_received_timestamp_ns: timestamp_ns,
                sequence: self.sequence,
                quality_flags: SensorQualityFlags::nominal(),
                payload: SensorPayload::Barometer {
                    pressure_hpa,
                    temperature_c: Some(21.5),
                },
            })
        } else {
            // Emit GPS event
            Some(SensorEvent {
                schema_version: NATIVE_PIPELINE_SCHEMA_VERSION,
                source_id: SensorSourceId::Gps,
                source_timestamp_ns: Some(timestamp_ns.saturating_sub(2_000_000)),
                native_received_timestamp_ns: timestamp_ns,
                sequence: self.sequence,
                quality_flags: SensorQualityFlags::nominal(),
                payload: SensorPayload::Gps {
                    latitude_deg: self.current_lat_deg,
                    longitude_deg: self.current_lon_deg,
                    altitude_m: self.current_altitude_m as f32,
                    ground_speed_mps: speed_mps as f32,
                    bearing_deg: bearing_deg as f32,
                    accuracy_m: 1.5,
                },
            })
        }
    }

    fn name(&self) -> &'static str {
        match self.maneuver {
            ProceduralManeuver::SteadyGlide => "ProceduralFlightGenerator::SteadyGlide",
            ProceduralManeuver::ThermalClimb360 => "ProceduralFlightGenerator::ThermalClimb360",
            ProceduralManeuver::SinkRecovery => "ProceduralFlightGenerator::SinkRecovery",
        }
    }

    fn reset(&mut self) {
        let initial_alt = 1500.0 + ((self.seed % 50) as f64) * 2.0;
        let initial_lat = 47.5246 + ((self.seed % 10) as f64) * 0.001;
        let initial_lon = 13.6917 + ((self.seed % 10) as f64) * 0.001;
        let initial_bearing = 120.0 + ((self.seed % 30) as f64);

        self.current_timestamp_ns = self.base_timestamp_ns;
        self.sequence = 0;
        self.current_altitude_m = initial_alt;
        self.current_lat_deg = initial_lat;
        self.current_lon_deg = initial_lon;
        self.current_bearing_deg = initial_bearing;
        self.phase_elapsed_s = 0.0;
        self.emit_gps_next = false;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn procedural_generator_is_deterministic_across_repeated_runs() {
        let mut gen1 = ProceduralFlightGenerator::new(42, 1_000_000_000);
        let mut gen2 = ProceduralFlightGenerator::new(42, 1_000_000_000);
        let mut gen3 = ProceduralFlightGenerator::new(42, 1_000_000_000);

        let events1 = gen1.generate_maneuver_events(ProceduralManeuver::SteadyGlide, 10.0, 50.0);
        let events2 = gen2.generate_maneuver_events(ProceduralManeuver::SteadyGlide, 10.0, 50.0);
        let events3 = gen3.generate_maneuver_events(ProceduralManeuver::SteadyGlide, 10.0, 50.0);

        assert_eq!(events1.len(), 500);
        assert_eq!(events1, events2);
        assert_eq!(events2, events3);
    }

    #[test]
    fn steady_glide_generates_expected_speed_and_sink_profile() {
        let mut generator = ProceduralFlightGenerator::new(10, 1_000_000_000);
        let start_alt = generator.current_altitude_m();
        let events =
            generator.generate_maneuver_events(ProceduralManeuver::SteadyGlide, 10.0, 50.0);

        assert_eq!(events.len(), 500);
        let end_alt = generator.current_altitude_m();
        let alt_diff = start_alt - end_alt;
        let avg_sink = alt_diff / 10.0;

        // Sink rate must be between 1.0 and 1.4 m/s
        assert!(
            (1.0..=1.4).contains(&avg_sink),
            "Expected sink 1.0-1.4 m/s, got {avg_sink}"
        );

        // Check GPS event speeds
        for event in &events {
            if let SensorPayload::Gps {
                ground_speed_mps, ..
            } = &event.payload
            {
                let speed_kmh = ground_speed_mps * 3.6;
                assert!(
                    (35.0..=42.0).contains(&speed_kmh),
                    "Expected speed between 35 and 42 km/h, got {speed_kmh}"
                );
            }
        }
    }

    #[test]
    fn thermal_climb_360_generates_positive_climb_and_turn() {
        let mut generator = ProceduralFlightGenerator::new(7, 1_000_000_000);
        let start_alt = generator.current_altitude_m();
        let start_bearing = generator.current_bearing_deg();

        // 20 seconds at 18 deg/s = 360 deg turn
        let events =
            generator.generate_maneuver_events(ProceduralManeuver::ThermalClimb360, 20.0, 50.0);
        assert_eq!(events.len(), 1000);

        let end_alt = generator.current_altitude_m();
        let climb_gain = end_alt - start_alt;
        let avg_climb = climb_gain / 20.0;

        // Average climb rate around +2.5 m/s (+-0.2 m/s)
        assert!(
            (2.3..=2.7).contains(&avg_climb),
            "Expected avg climb ~2.5 m/s, got {avg_climb}"
        );

        let end_bearing = generator.current_bearing_deg();
        let bearing_diff = (end_bearing - start_bearing).abs();
        assert!(
            bearing_diff < 1.0 || (360.0 - bearing_diff) < 1.0,
            "Expected completed 360 degree circle, bearing delta {bearing_diff}"
        );
    }

    #[test]
    fn sink_recovery_transitions_through_heavy_sink_and_stabilizes() {
        let mut generator = ProceduralFlightGenerator::new(5, 1_000_000_000);
        let start_alt = generator.current_altitude_m();

        // 12 seconds: 5s heavy sink, 5s transition, 2s steady
        let events =
            generator.generate_maneuver_events(ProceduralManeuver::SinkRecovery, 12.0, 50.0);
        assert_eq!(events.len(), 600);

        let end_alt = generator.current_altitude_m();
        assert!(end_alt < start_alt, "Altitude should have decreased");

        let total_loss = start_alt - end_alt;
        assert!(
            (25.0..=40.0).contains(&total_loss),
            "Expected total loss 25-40m, got {total_loss}"
        );
    }

    #[test]
    fn telemetry_source_trait_integration_works() {
        let mut generator = ProceduralFlightGenerator::new(42, 1_000_000_000);
        assert_eq!(generator.name(), "ProceduralFlightGenerator::SteadyGlide");

        let event1 = generator.next_event(1_020_000_000).expect("event");
        assert_eq!(event1.sequence, 1);
        assert_eq!(event1.source_id, SensorSourceId::Barometer);

        let event2 = generator.next_event(1_040_000_000).expect("event");
        assert_eq!(event2.sequence, 2);
        assert_eq!(event2.source_id, SensorSourceId::Gps);

        generator.reset();
        assert_eq!(generator.current_altitude_m(), 1500.0 + 42.0 * 2.0);
    }
}
