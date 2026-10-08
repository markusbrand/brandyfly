//! Airspace parsing, spatial indexing, vertical QNH resolution, and 3D proximity engine.

pub mod ast;
pub mod benchmark;
pub mod ffi;
pub mod fixtures;
pub mod parser;
pub mod proximity;
pub mod spatial;
pub mod vertical;

pub use ast::{
    Airspace, AirspaceClass, AirspaceDefinition, ArcDirection, BoundingBox, Coordinate,
    GeometryRecord, VerticalLimit,
};
pub use benchmark::{AirspaceBenchmarkResult, run_airspace_proximity_benchmark};
pub use ffi::{
    AirspaceEvaluationInput, AirspaceEvaluationOutput, AirspaceStore, airspace_clear_store,
    airspace_count, airspace_evaluate, airspace_init_store, airspace_load_dach_fixture,
};
pub use fixtures::DACH_OPENAIR_SAMPLE;
pub use parser::{
    ParseResult, ParseWarning, discretize_arc_by_angle, discretize_arc_by_points,
    discretize_circle, geodesic_bearing, geodesic_destination, geodesic_distance, parse_coordinate,
    parse_openair, parse_vertical_limit,
};
pub use proximity::{
    AirspaceHysteresisState, AirspaceProximity, AirspaceProximityEngine, AlertLevel,
    ForwardAirspaceIntersection, evaluate_airspace_proximity, project_glide_slope,
};
pub use spatial::{
    LocalProjection, RTree, distance_point_to_polygon_meters, point_in_polygon,
    point_to_segment_distance,
};
pub use vertical::{
    ClosureTerrainElevation, ConstantTerrainElevation, STANDARD_PRESSURE_HPA,
    TerrainElevationProvider, barometric_qnh_altitude_offset_meters,
    resolve_airspace_vertical_bounds_meters, resolve_vertical_limit_meters,
};
