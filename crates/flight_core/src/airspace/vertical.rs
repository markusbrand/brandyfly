//! Vertical reference calculation, QNH barometric adjustment, and DEM terrain elevation resolution.

use super::ast::{Coordinate, VerticalLimit};
use super::parser::METERS_PER_FOOT;

/// Standard atmospheric pressure at sea level in hPa.
pub const STANDARD_PRESSURE_HPA: f64 = 1013.25;

/// Barometric pressure height factor near sea level in meters per hPa.
pub const METERS_PER_HPA: f64 = 8.43;

/// Trait providing terrain elevation lookup in meters MSL for coordinate locations.
pub trait TerrainElevationProvider {
    /// Returns ground elevation above MSL in meters for `coord`, or `None` if data is unavailable.
    fn get_elevation_msl(&self, coord: Coordinate) -> Option<f64>;
}

/// Fallback terrain elevation provider with a constant elevation value.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct ConstantTerrainElevation(pub f64);

impl TerrainElevationProvider for ConstantTerrainElevation {
    fn get_elevation_msl(&self, _coord: Coordinate) -> Option<f64> {
        Some(self.0)
    }
}

/// Dynamic elevation resolver wrapping a closure.
pub struct ClosureTerrainElevation<F>(pub F)
where
    F: Fn(Coordinate) -> Option<f64>;

impl<F> TerrainElevationProvider for ClosureTerrainElevation<F>
where
    F: Fn(Coordinate) -> Option<f64>,
{
    fn get_elevation_msl(&self, coord: Coordinate) -> Option<f64> {
        (self.0)(coord)
    }
}

/// Computes barometric pressure altitude adjustment in meters based on QNH offset from standard atmosphere (1013.25 hPa).
/// Formula: Delta h = (QNH - 1013.25) * 8.43 m/hPa
#[must_use]
pub fn barometric_qnh_altitude_offset_meters(qnh_hpa: f64) -> f64 {
    (qnh_hpa - STANDARD_PRESSURE_HPA) * METERS_PER_HPA
}

/// Resolves a `VerticalLimit` to absolute meters MSL given active QNH and ground terrain elevation.
#[must_use]
pub fn resolve_vertical_limit_meters(
    limit: VerticalLimit,
    qnh_hpa: f64,
    terrain_elevation_msl: f64,
) -> f64 {
    match limit {
        VerticalLimit::FlightLevel(fl) => {
            let standard_altitude_meters = (fl as f64) * 100.0 * METERS_PER_FOOT;
            let qnh_offset_meters = barometric_qnh_altitude_offset_meters(qnh_hpa);
            standard_altitude_meters + qnh_offset_meters
        }
        VerticalLimit::FeetMsl(feet) => feet * METERS_PER_FOOT,
        VerticalLimit::MetersMsl(meters) => meters,
        VerticalLimit::FeetAgl(feet) => terrain_elevation_msl + feet * METERS_PER_FOOT,
        VerticalLimit::MetersAgl(meters) => terrain_elevation_msl + meters,
        VerticalLimit::Surface => terrain_elevation_msl,
        VerticalLimit::Unlimited => f64::INFINITY,
    }
}

/// Resolves floor and ceiling limits of an airspace into absolute meters MSL `(floor_m, ceiling_m)`.
#[must_use]
pub fn resolve_airspace_vertical_bounds_meters(
    floor: VerticalLimit,
    ceiling: VerticalLimit,
    qnh_hpa: f64,
    terrain_elevation_msl: f64,
) -> (f64, f64) {
    let floor_m = resolve_vertical_limit_meters(floor, qnh_hpa, terrain_elevation_msl);
    let ceiling_m = resolve_vertical_limit_meters(ceiling, qnh_hpa, terrain_elevation_msl);
    (floor_m, ceiling_m)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_flight_level_conversion_with_qnh_offset() {
        // FL 100 under QNH 1023 hPa
        // Standard altitude: 100 * 100 * 0.3048 = 3048.0 m
        // QNH offset: (1023 - 1013.25) * 8.43 = 9.75 * 8.43 = 82.1925 m
        // Total = 3048.0 + 82.1925 = 3130.1925 m MSL
        let res = resolve_vertical_limit_meters(VerticalLimit::FlightLevel(100), 1023.0, 500.0);
        assert!((res - 3130.1925).abs() < 0.1);

        // FL 65 under standard QNH 1013.25 hPa
        let std_res =
            resolve_vertical_limit_meters(VerticalLimit::FlightLevel(65), 1013.25, 1000.0);
        assert!((std_res - (6500.0 * METERS_PER_FOOT)).abs() < 1e-4);

        // Low pressure QNH 990 hPa (FL lower than standard in absolute terms)
        let low_qnh = resolve_vertical_limit_meters(VerticalLimit::FlightLevel(100), 990.0, 0.0);
        assert!(low_qnh < 3048.0);
    }

    #[test]
    fn test_agl_conversion_with_terrain_elevation() {
        // 1500ft AGL over 1200m terrain
        // 1200 + 1500 * 0.3048 = 1200 + 457.2 = 1657.2m MSL
        let res = resolve_vertical_limit_meters(VerticalLimit::FeetAgl(1500.0), 1013.25, 1200.0);
        assert!((res - 1657.2).abs() < 1e-4);

        // 300m AGL over 800m terrain = 1100m MSL
        let res_m = resolve_vertical_limit_meters(VerticalLimit::MetersAgl(300.0), 1013.25, 800.0);
        assert_eq!(res_m, 1100.0);
    }

    #[test]
    fn test_surface_and_msl_conversion() {
        let gnd = resolve_vertical_limit_meters(VerticalLimit::Surface, 1013.25, 950.0);
        assert_eq!(gnd, 950.0);

        let msl_ft = resolve_vertical_limit_meters(VerticalLimit::FeetMsl(5000.0), 1013.25, 950.0);
        assert_eq!(msl_ft, 5000.0 * METERS_PER_FOOT);

        let unl = resolve_vertical_limit_meters(VerticalLimit::Unlimited, 1013.25, 950.0);
        assert_eq!(unl, f64::INFINITY);
    }

    #[test]
    fn test_airspace_bounds_resolution() {
        let (floor_m, ceil_m) = resolve_airspace_vertical_bounds_meters(
            VerticalLimit::Surface,
            VerticalLimit::FeetMsl(4500.0),
            1013.25,
            600.0,
        );
        assert_eq!(floor_m, 600.0);
        assert_eq!(ceil_m, 4500.0 * METERS_PER_FOOT);
    }

    #[test]
    fn test_terrain_elevation_providers() {
        let const_provider = ConstantTerrainElevation(750.0);
        assert_eq!(
            const_provider.get_elevation_msl(Coordinate::new(47.0, 11.0)),
            Some(750.0)
        );

        let closure_provider = ClosureTerrainElevation(|c| Some(c.latitude * 20.0));
        assert_eq!(
            closure_provider.get_elevation_msl(Coordinate::new(47.0, 11.0)),
            Some(940.0)
        );
    }
}
