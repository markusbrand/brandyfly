pub fn normalize_heading(heading: f64) -> f64 {
    let mut normalized = heading % 360.0;
    if normalized < -180.0 {
        normalized += 360.0;
    } else if normalized >= 180.0 {
        normalized -= 360.0;
    }
    normalized
}

/// Normalizes the difference between two headings in degrees to the range [-180, 180).
/// This represents the shortest angular turn from heading1 to heading2.
pub fn heading_delta(heading1: f64, heading2: f64) -> f64 {
    normalize_heading(heading2 - heading1)
}

#[derive(Debug, Clone)]
pub struct HeadingSample {
    pub timestamp_ms: u64,
    pub heading_deg: f64,
}

#[derive(Debug, Clone, Default)]
pub struct HeadingTracker {
    /// Sliding window of heading samples, kept sorted by time.
    samples: Vec<HeadingSample>,
    /// Maximum age of samples to retain in the window (e.g., 25 seconds).
    window_duration_ms: u64,
}

impl HeadingTracker {
    pub fn new(window_duration_ms: u64) -> Self {
        Self {
            samples: Vec::new(),
            window_duration_ms,
        }
    }

    /// Add a new heading sample and prune old ones.
    pub fn push_sample(&mut self, timestamp_ms: u64, heading_deg: f64) {
        self.samples.push(HeadingSample {
            timestamp_ms,
            heading_deg: normalize_heading(heading_deg),
        });

        // Prune samples older than the window duration
        let cutoff_time = timestamp_ms.saturating_sub(self.window_duration_ms);
        self.samples.retain(|s| s.timestamp_ms >= cutoff_time);
    }

    /// Clears all samples from the tracker.
    pub fn clear(&mut self) {
        self.samples.clear();
    }

    /// Returns the number of samples in the current window.
    pub fn sample_count(&self) -> usize {
        self.samples.len()
    }

    /// Calculate the cumulative continuous heading change in the current window.
    /// It iterates through the samples, accumulating the angular delta between consecutive points.
    /// If the turn reverses direction significantly, the cumulative sum might be reduced.
    pub fn cumulative_heading_change(&self) -> f64 {
        if self.samples.len() < 2 {
            return 0.0;
        }

        let mut total_change = 0.0;
        let mut prev_heading = self.samples[0].heading_deg;

        for sample in self.samples.iter().skip(1) {
            let delta = heading_delta(prev_heading, sample.heading_deg);
            total_change += delta;
            prev_heading = sample.heading_deg;
        }

        total_change
    }

    /// Checks if the heading has been stable within a certain tolerance for a given duration.
    pub fn is_heading_stable(
        &self,
        current_time_ms: u64,
        duration_ms: u64,
        tolerance_deg: f64,
    ) -> bool {
        if self.samples.is_empty() {
            return false;
        }

        let start_time = current_time_ms.saturating_sub(duration_ms);

        // Find the first sample within the stability duration window
        let relevant_samples: Vec<&HeadingSample> = self
            .samples
            .iter()
            .filter(|s| s.timestamp_ms >= start_time)
            .collect();

        if relevant_samples.is_empty()
            || relevant_samples.first().unwrap().timestamp_ms > start_time + 1000
        {
            // Not enough history to confirm stability for the full duration
            return false;
        }

        let base_heading = relevant_samples[0].heading_deg;

        for sample in relevant_samples {
            if heading_delta(base_heading, sample.heading_deg).abs() > tolerance_deg {
                return false;
            }
        }

        true
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TurnDirection {
    Left,
    Right,
    None,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FlightState {
    Gliding,
    Circling(TurnDirection),
}

#[derive(Debug, Clone)]
pub struct CirclingStateDetector {
    tracker: HeadingTracker,
    current_state: FlightState,

    // Configuration
    circling_threshold_deg: f64,

    gliding_stability_duration_ms: u64,
    gliding_tolerance_deg: f64,
}

impl Default for CirclingStateDetector {
    fn default() -> Self {
        Self::new()
    }
}

impl CirclingStateDetector {
    pub fn new() -> Self {
        let circling_window_ms = 25_000; // 25 seconds
        Self {
            tracker: HeadingTracker::new(circling_window_ms),
            current_state: FlightState::Gliding,

            circling_threshold_deg: 270.0,

            gliding_stability_duration_ms: 8_000, // 8 seconds
            gliding_tolerance_deg: 15.0,
        }
    }

    pub fn state(&self) -> FlightState {
        self.current_state
    }

    /// Processes a new heading sample and returns the new flight state (which might be unchanged).
    pub fn update(&mut self, timestamp_ms: u64, heading_deg: f64) -> FlightState {
        self.tracker.push_sample(timestamp_ms, heading_deg);

        match self.current_state {
            FlightState::Gliding => {
                let cumulative_change = self.tracker.cumulative_heading_change();

                if cumulative_change.abs() >= self.circling_threshold_deg {
                    let direction = if cumulative_change > 0.0 {
                        TurnDirection::Right // Positive angle is typically right turn in aviation heading (0 to 360)
                    } else {
                        TurnDirection::Left
                    };
                    self.current_state = FlightState::Circling(direction);
                    // When entering circling, we could optionally clear the tracker or keep it for wind estimation
                }
            }
            FlightState::Circling(_) => {
                if self.tracker.is_heading_stable(
                    timestamp_ms,
                    self.gliding_stability_duration_ms,
                    self.gliding_tolerance_deg,
                ) {
                    self.current_state = FlightState::Gliding;
                    // Reset the tracker upon returning to gliding
                    self.tracker.clear();
                    // Still push the current sample so we have a baseline
                    self.tracker.push_sample(timestamp_ms, heading_deg);
                }
            }
        }

        self.current_state
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_normalize_heading() {
        assert_eq!(normalize_heading(0.0), 0.0);
        assert_eq!(normalize_heading(180.0), -180.0);
        assert_eq!(normalize_heading(-180.0), -180.0);
        assert_eq!(normalize_heading(350.0), -10.0);
        assert_eq!(normalize_heading(400.0), 40.0);
        assert_eq!(normalize_heading(-10.0), -10.0);
        assert_eq!(normalize_heading(-400.0), -40.0);
    }

    #[test]
    fn test_heading_delta() {
        assert_eq!(heading_delta(10.0, 20.0), 10.0);
        assert_eq!(heading_delta(350.0, 10.0), 20.0);
        assert_eq!(heading_delta(10.0, 350.0), -20.0);
        assert_eq!(heading_delta(180.0, -170.0), 10.0);
    }

    #[test]
    fn test_circling_detection_right_turn() {
        let mut detector = CirclingStateDetector::new();
        let mut time_ms = 1000;
        let mut heading = 0.0;

        // Simulate a steady right turn at 20 deg/sec
        // Should trigger circling after 270 / 20 = 13.5 seconds
        for _ in 0..14 {
            assert_eq!(detector.update(time_ms, heading), FlightState::Gliding);
            time_ms += 1000;
            heading = (heading + 20.0) % 360.0;
        }

        // The 15th sample (after 14 seconds) should trigger circling
        assert_eq!(
            detector.update(time_ms, heading),
            FlightState::Circling(TurnDirection::Right)
        );
    }

    #[test]
    fn test_circling_detection_left_turn() {
        let mut detector = CirclingStateDetector::new();
        let mut time_ms = 1000;
        let mut heading = 0.0;

        // Simulate a steady left turn at -20 deg/sec
        for _ in 0..14 {
            assert_eq!(detector.update(time_ms, heading), FlightState::Gliding);
            time_ms += 1000;
            heading = (heading - 20.0 + 360.0) % 360.0;
        }

        assert_eq!(
            detector.update(time_ms, heading),
            FlightState::Circling(TurnDirection::Left)
        );
    }

    #[test]
    fn test_noise_rejection() {
        let mut detector = CirclingStateDetector::new();
        let mut time_ms = 1000;
        let mut heading = 0.0;

        // Simulate erratic heading changes that do not accumulate
        for _ in 0..30 {
            assert_eq!(detector.update(time_ms, heading), FlightState::Gliding);
            time_ms += 1000;
            heading = if heading == 0.0 { 45.0 } else { 0.0 };
        }

        assert_eq!(detector.state(), FlightState::Gliding);
    }

    #[test]
    fn test_transition_back_to_gliding() {
        let mut detector = CirclingStateDetector::new();
        let mut time_ms = 1000;
        let mut heading = 0.0;

        // 1. Enter circling
        for _ in 0..15 {
            detector.update(time_ms, heading);
            time_ms += 1000;
            heading = (heading + 20.0) % 360.0;
        }
        assert_eq!(
            detector.state(),
            FlightState::Circling(TurnDirection::Right)
        );

        // 2. Straight line to exit circling
        let exit_heading = heading;
        for _ in 0..8 {
            assert_eq!(
                detector.update(time_ms, exit_heading),
                FlightState::Circling(TurnDirection::Right)
            );
            time_ms += 1000;
        }

        // 9th second of steady heading should exit
        assert_eq!(detector.update(time_ms, exit_heading), FlightState::Gliding);
    }
}
