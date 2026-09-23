#[derive(Debug, Clone, Copy, PartialEq)]
pub struct Position {
    pub lat: f64,
    pub lon: f64,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct WindVector {
    pub speed_kmh: f64,
    pub direction_deg: f64,
    pub velocity_x_ms: f64,
    pub velocity_y_ms: f64,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct TurnCompletion {
    pub timestamp_ms: u64,
    pub position: Position,
}

pub struct WindEstimator {
    /// Positions at which a full 360 turn was completed
    turn_completions: Vec<TurnCompletion>,
    /// Accumulated rotation angle since the last turn completion
    current_turn_rotation: f64,
    /// The last known heading
    last_heading: Option<f64>,
    /// The current wind estimate
    current_estimate: Option<WindVector>,

    // Config
    alpha: f64, // Exponential moving average weight for wind
}

impl Default for WindEstimator {
    fn default() -> Self {
        Self::new()
    }
}

impl WindEstimator {
    pub fn new() -> Self {
        Self {
            turn_completions: Vec::new(),
            current_turn_rotation: 0.0,
            last_heading: None,
            current_estimate: None,
            alpha: 0.6,
        }
    }

    pub fn estimate(&self) -> Option<WindVector> {
        self.current_estimate
    }

    pub fn reset(&mut self) {
        self.turn_completions.clear();
        self.current_turn_rotation = 0.0;
        self.last_heading = None;
        // Do not necessarily reset the current wind estimate, just the turn tracker.
        // We might want to retain the last known wind.
    }

    /// Returns the approximate distance in meters between two lat/lon points using Equirectangular approximation
    fn distance_xy(p1: Position, p2: Position) -> (f64, f64) {
        let r_earth = 6371000.0;
        let lat_mid = (p1.lat + p2.lat) / 2.0 * std::f64::consts::PI / 180.0;
        let dx = (p2.lon - p1.lon) * std::f64::consts::PI / 180.0 * r_earth * lat_mid.cos();
        let dy = (p2.lat - p1.lat) * std::f64::consts::PI / 180.0 * r_earth;
        (dx, dy)
    }

    pub fn update(
        &mut self,
        timestamp_ms: u64,
        heading_deg: f64,
        position: Position,
        is_circling: bool,
    ) {
        if !is_circling {
            self.reset();
            return;
        }

        if let Some(last) = self.last_heading {
            let delta = super::circling::heading_delta(last, heading_deg);
            self.current_turn_rotation += delta;

            // Have we completed a full 360 degree turn?
            // Allow for a bit of margin, but generally look for multiple of 360.
            if self.current_turn_rotation.abs() >= 360.0 {
                let completion = TurnCompletion {
                    timestamp_ms,
                    position,
                };

                // Keep the remainder for the next turn
                self.current_turn_rotation %= 360.0;

                if let Some(prev_completion) = self.turn_completions.last() {
                    let (dx, dy) = Self::distance_xy(prev_completion.position, completion.position);
                    let dt_s =
                        (completion.timestamp_ms - prev_completion.timestamp_ms) as f64 / 1000.0;

                    if dt_s > 0.0 {
                        let vx = dx / dt_s;
                        let vy = dy / dt_s;

                        let speed_ms = (vx * vx + vy * vy).sqrt();
                        let speed_kmh = speed_ms * 3.6;

                        // Meteorological wind direction (where it comes FROM)
                        // atan2(y, x) is math angle. Meteorological is clockwise from North.
                        // Wait, spec says: Dir = (atan2(-Vx, -Vy) * 180 / PI + 360) % 360
                        let mut dir_deg =
                            (f64::atan2(-vx, -vy) * 180.0 / std::f64::consts::PI + 360.0) % 360.0;
                        if dir_deg < 0.0 {
                            dir_deg += 360.0;
                        } // Should be handled by %, but be safe

                        let new_estimate = WindVector {
                            speed_kmh,
                            direction_deg: dir_deg,
                            velocity_x_ms: vx,
                            velocity_y_ms: vy,
                        };

                        self.current_estimate = match self.current_estimate {
                            Some(old) => {
                                // Exponential moving average
                                Some(WindVector {
                                    speed_kmh: old.speed_kmh * (1.0 - self.alpha)
                                        + new_estimate.speed_kmh * self.alpha,
                                    // Properly averaging angles requires vector addition, but for now we'll average the components.
                                    velocity_x_ms: old.velocity_x_ms * (1.0 - self.alpha)
                                        + new_estimate.velocity_x_ms * self.alpha,
                                    velocity_y_ms: old.velocity_y_ms * (1.0 - self.alpha)
                                        + new_estimate.velocity_y_ms * self.alpha,
                                    direction_deg: {
                                        let vx_avg = old.velocity_x_ms * (1.0 - self.alpha)
                                            + new_estimate.velocity_x_ms * self.alpha;
                                        let vy_avg = old.velocity_y_ms * (1.0 - self.alpha)
                                            + new_estimate.velocity_y_ms * self.alpha;
                                        (f64::atan2(-vx_avg, -vy_avg) * 180.0
                                            / std::f64::consts::PI
                                            + 360.0)
                                            % 360.0
                                    },
                                })
                            }
                            None => Some(new_estimate),
                        };
                    }
                }

                self.turn_completions.push(completion);
            }
        }

        self.last_heading = Some(heading_deg);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_distance_xy() {
        let p1 = Position { lat: 0.0, lon: 0.0 };
        let p2 = Position { lat: 0.0, lon: 1.0 };
        let (dx, dy) = WindEstimator::distance_xy(p1, p2);
        assert!((dx - 111194.9).abs() < 10.0);
        assert_eq!(dy, 0.0);

        let p3 = Position { lat: 1.0, lon: 0.0 };
        let (dx2, dy2) = WindEstimator::distance_xy(p1, p3);
        assert_eq!(dx2, 0.0);
        assert!((dy2 - 111194.9).abs() < 10.0);
    }

    #[test]
    fn test_wind_estimation() {
        let mut estimator = WindEstimator::new();
        let mut time_ms = 1000;
        let mut heading = 0.0;
        let lat = 0.0;
        // Move east at approx 10 m/s
        let mut lon = 0.0;

        for _i in 0..80 {
            let h = heading;
            estimator.update(time_ms, h, Position { lat, lon }, true);
            time_ms += 1000;
            heading += 10.0;
            if heading >= 360.0 {
                heading -= 360.0;
            }
            let r_earth = 6371000.0;
            let deg_to_rad = std::f64::consts::PI / 180.0;
            let d_lon = 10.0 / (r_earth * deg_to_rad); // 10 m/s east
            lon += d_lon;
        }

        let wind = estimator.estimate().expect("Should have estimated wind");
        // Drifting east means wind comes from West (270 deg)
        assert!(
            (wind.direction_deg - 270.0).abs() < 5.0,
            "Expected ~270, got {}",
            wind.direction_deg
        );
        assert!(
            (wind.speed_kmh - 36.0).abs() < 1.0,
            "Expected ~36 kmh (10m/s), got {}",
            wind.speed_kmh
        );
    }
}
