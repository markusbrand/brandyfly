use crate::circling::FlightState;
use crate::wind::{Position, WindVector};

#[derive(Debug, Clone, PartialEq)]
pub struct ThermalStateSnapshot {
    pub timestamp_ms: u64,
    pub state: FlightState,
    pub wind: Option<WindVector>,
    pub core_estimate: ThermalCoreEstimate,
}


#[derive(Debug, Clone, Copy, PartialEq)]
pub struct TrackPoint {
    pub timestamp_ms: u64,
    pub position: Position,
    pub climb_rate_ms: f64,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct ThermalCoreEstimate {
    pub center: Position,
    pub center_airmass: Position,
    pub valid: bool,
}

pub struct ThermalCoreCalculator {
    points: std::collections::VecDeque<TrackPoint>,
    window_duration_ms: u64,
}

impl ThermalCoreCalculator {
    pub fn new() -> Self {
        Self {
            points: std::collections::VecDeque::new(),
            window_duration_ms: 60_000, // 60 seconds history for core calculation
        }
    }
    
    pub fn reset(&mut self) {
        self.points.clear();
    }
    
    pub fn add_point(&mut self, point: TrackPoint) {
        self.points.push_back(point);
        
        let cutoff = point.timestamp_ms.saturating_sub(self.window_duration_ms);
        while let Some(front) = self.points.front() {
            if front.timestamp_ms < cutoff {
                self.points.pop_front();
            } else {
                break;
            }
        }
    }
    
    pub fn calculate(&self, current_time_ms: u64, wind: Option<WindVector>) -> ThermalCoreEstimate {
        if self.points.is_empty() {
            return ThermalCoreEstimate {
                center: Position { lat: 0.0, lon: 0.0 },
                center_airmass: Position { lat: 0.0, lon: 0.0 },
                valid: false,
            };
        }
        
        let wind_vx = wind.map_or(0.0, |w| w.velocity_x_ms);
        let wind_vy = wind.map_or(0.0, |w| w.velocity_y_ms);
        
        // Base coordinate transformation for airmass on the first point in the window
        // to keep values relatively small, or the current point.
        // We will do all calculations in local meters offset from the current position.
        let reference_pos = self.points.back().unwrap().position;
        let reference_time = current_time_ms;
        
        let r_earth = 6371000.0;
        let ref_lat_rad = reference_pos.lat * std::f64::consts::PI / 180.0;
        let deg_to_rad = std::f64::consts::PI / 180.0;
        let rad_to_deg = 180.0 / std::f64::consts::PI;
        
        let mut sum_w = 0.0;
        let mut sum_wx = 0.0;
        let mut sum_wy = 0.0;
        
        let mut sum_x = 0.0;
        let mut sum_y = 0.0;
        let n = self.points.len() as f64;
        
        for p in &self.points {
            let dt_s = (reference_time as f64 - p.timestamp_ms as f64) / 1000.0;
            
            // Ground coordinate offset from reference in meters
            let dx_gps = (p.position.lon - reference_pos.lon) * deg_to_rad * r_earth * ref_lat_rad.cos();
            let dy_gps = (p.position.lat - reference_pos.lat) * deg_to_rad * r_earth;
            
            // Airmass coordinate offset
            // P_air(t) = P_gps(t) - V_wind * (t - t0)
            // But dt_s here is reference_time - t.
            // If wind is V_wind, then over dt_s seconds, the airmass has moved V_wind * dt_s.
            // So to find where that airmass was AT REFERENCE TIME, we need to add the displacement.
            // P_air(ref_time) = P_gps(t) + V_wind * (ref_time - t)
            let x_air = dx_gps + wind_vx * dt_s;
            let y_air = dy_gps + wind_vy * dt_s;
            
            let climb = p.climb_rate_ms.max(0.0);
            let w = climb * climb;
            
            sum_w += w;
            sum_wx += w * x_air;
            sum_wy += w * y_air;
            
            sum_x += x_air;
            sum_y += y_air;
        }
        
        let (core_x, core_y) = if sum_w < 1e-6 {
            // Fallback to geometric center
            (sum_x / n, sum_y / n)
        } else {
            (sum_wx / sum_w, sum_wy / sum_w)
        };
        
        // Convert offset back to lat/lon for the airmass center
        let dlat_air = core_y / r_earth * rad_to_deg;
        let dlon_air = core_x / (r_earth * ref_lat_rad.cos()) * rad_to_deg;
        
        let center_airmass = Position {
            lat: reference_pos.lat + dlat_air,
            lon: reference_pos.lon + dlon_air,
        };
        
        // Convert the airmass center to a current ground center by drifting it back
        // The core is at center_airmass relative to the airmass now.
        // Wait, center_airmass IS the position of the core in the current airmass space
        // which maps directly to the current ground space because reference_time == current_time_ms.
        let center = center_airmass;
        
        ThermalCoreEstimate {
            center,
            center_airmass,
            valid: true,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_core_centroid() {
        let mut calc = ThermalCoreCalculator::new();
        
        // Add points in a circle
        calc.add_point(TrackPoint { timestamp_ms: 1000, position: Position { lat: 0.001, lon: 0.0 }, climb_rate_ms: 2.0 }); // North, strong lift
        calc.add_point(TrackPoint { timestamp_ms: 2000, position: Position { lat: 0.0, lon: 0.001 }, climb_rate_ms: 1.0 }); // East, weak lift
        calc.add_point(TrackPoint { timestamp_ms: 3000, position: Position { lat: -0.001, lon: 0.0 }, climb_rate_ms: -1.0 }); // South, sink
        calc.add_point(TrackPoint { timestamp_ms: 4000, position: Position { lat: 0.0, lon: -0.001 }, climb_rate_ms: -2.0 }); // West, strong sink
        
        let est = calc.calculate(4000, None);
        assert!(est.valid);
        
        // Lift weighted should pull strongly towards North, slightly towards East
        assert!(est.center.lat > 0.0);
        assert!(est.center.lon > 0.0);
        assert!(est.center.lat > est.center.lon); // Stronger lift north
    }
}
