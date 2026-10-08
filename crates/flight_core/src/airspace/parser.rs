//! Deterministic OpenAir format text parser and geometry compiler.

use std::f64::consts::PI;

use super::ast::{
    Airspace, AirspaceClass, AirspaceDefinition, ArcDirection, Coordinate, GeometryRecord,
    VerticalLimit,
};

/// Earth radius in meters used for geodesic computations.
pub const EARTH_RADIUS_METERS: f64 = 6_371_000.0;

/// Conversion factor from Nautical Miles to meters (1 NM = 1852 m).
pub const METERS_PER_NAUTICAL_MILE: f64 = 1852.0;

/// Conversion factor from feet to meters (1 ft = 0.3048 m).
pub const METERS_PER_FOOT: f64 = 0.3048;

/// Diagnostic parse warning emitted when encountering unrecognized or malformed records.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ParseWarning {
    pub line_number: usize,
    pub message: String,
}

/// Result of parsing an OpenAir input string.
#[derive(Clone, Debug, PartialEq)]
pub struct ParseResult {
    pub airspaces: Vec<Airspace>,
    pub warnings: Vec<ParseWarning>,
}

/// Parses an OpenAir formatted string into compiled Airspace models.
#[must_use]
pub fn parse_openair(input: &str) -> ParseResult {
    let mut warnings = Vec::new();
    let mut current_def: Option<AirspaceDefinition> = None;
    let mut definitions = Vec::new();

    let mut current_center: Option<Coordinate> = None;
    let mut current_direction = ArcDirection::Clockwise;

    for (line_idx, raw_line) in input.lines().enumerate() {
        let line_number = line_idx + 1;
        let line = raw_line.trim();

        // Skip blank lines and comments
        if line.is_empty() || line.starts_with('*') {
            continue;
        }

        // Split record token and payload
        let mut parts = line.splitn(2, char::is_whitespace);
        let record_tag = parts.next().unwrap_or("").to_uppercase();
        let payload = parts.next().unwrap_or("").trim();

        match record_tag.as_str() {
            "AC" => {
                // New airspace block starts
                if let Some(def) = current_def.take() {
                    if !def.geometry_records.is_empty() || !def.name.is_empty() {
                        definitions.push(def);
                    }
                }
                let mut def = AirspaceDefinition::default();
                def.class = AirspaceClass::parse_code(payload);
                def.center_variable = current_center;
                def.direction_variable = current_direction;
                current_def = Some(def);
            }
            "AN" => {
                if let Some(ref mut def) = current_def {
                    def.name = payload.to_string();
                } else {
                    let mut def = AirspaceDefinition::default();
                    def.name = payload.to_string();
                    def.center_variable = current_center;
                    def.direction_variable = current_direction;
                    current_def = Some(def);
                }
            }
            "AH" => {
                if let Some(ref mut def) = current_def {
                    match parse_vertical_limit(payload) {
                        Ok(limit) => def.ceiling = limit,
                        Err(err) => warnings.push(ParseWarning {
                            line_number,
                            message: format!("Failed to parse ceiling '{payload}': {err}"),
                        }),
                    }
                }
            }
            "AL" => {
                if let Some(ref mut def) = current_def {
                    match parse_vertical_limit(payload) {
                        Ok(limit) => def.floor = limit,
                        Err(err) => warnings.push(ParseWarning {
                            line_number,
                            message: format!("Failed to parse floor '{payload}': {err}"),
                        }),
                    }
                }
            }
            "DP" => {
                match parse_coordinate(payload) {
                    Ok(coord) => {
                        let def = current_def.get_or_insert_with(AirspaceDefinition::default);
                        def.geometry_records.push(GeometryRecord::Point(coord));
                    }
                    Err(err) => warnings.push(ParseWarning {
                        line_number,
                        message: format!("Failed to parse point coordinate '{payload}': {err}"),
                    }),
                }
            }
            "DC" => {
                match payload.parse::<f64>() {
                    Ok(radius_nm) if radius_nm > 0.0 => {
                        let def = current_def.get_or_insert_with(AirspaceDefinition::default);
                        def.geometry_records
                            .push(GeometryRecord::Circle { radius_nm });
                    }
                    _ => warnings.push(ParseWarning {
                        line_number,
                        message: format!("Invalid circle radius '{payload}'"),
                    }),
                }
            }
            "DA" => {
                match parse_arc_angle_params(payload) {
                    Ok((radius_nm, start_deg, end_deg)) => {
                        let def = current_def.get_or_insert_with(AirspaceDefinition::default);
                        def.geometry_records.push(GeometryRecord::ArcByAngle {
                            radius_nm,
                            start_angle_deg: start_deg,
                            end_angle_deg: end_deg,
                        });
                    }
                    Err(err) => warnings.push(ParseWarning {
                        line_number,
                        message: format!("Failed to parse arc DA parameters '{payload}': {err}"),
                    }),
                }
            }
            "DB" => {
                match parse_arc_points_params(payload) {
                    Ok((start, end)) => {
                        let def = current_def.get_or_insert_with(AirspaceDefinition::default);
                        def.geometry_records
                            .push(GeometryRecord::ArcByPoints { start, end });
                    }
                    Err(err) => warnings.push(ParseWarning {
                        line_number,
                        message: format!("Failed to parse arc DB parameters '{payload}': {err}"),
                    }),
                }
            }
            "V" => {
                // Variable assignments: V X=..., V D=+|-
                let upper_payload = payload.to_uppercase();
                if let Some(x_coord_str) = upper_payload.strip_prefix("X=") {
                    match parse_coordinate(x_coord_str.trim()) {
                        Ok(center) => {
                            current_center = Some(center);
                            if let Some(ref mut def) = current_def {
                                def.center_variable = Some(center);
                            }
                        }
                        Err(err) => warnings.push(ParseWarning {
                            line_number,
                            message: format!("Failed to parse variable center 'V {payload}': {err}"),
                        }),
                    }
                } else if upper_payload.contains("D=+") {
                    current_direction = ArcDirection::Clockwise;
                    if let Some(ref mut def) = current_def {
                        def.direction_variable = ArcDirection::Clockwise;
                    }
                } else if upper_payload.contains("D=-") {
                    current_direction = ArcDirection::CounterClockwise;
                    if let Some(ref mut def) = current_def {
                        def.direction_variable = ArcDirection::CounterClockwise;
                    }
                }
            }
            "SP" => {
                if let Some(ref mut def) = current_def {
                    def.pen_style = Some(payload.to_string());
                }
            }
            "SB" => {
                if let Some(ref mut def) = current_def {
                    def.brush_style = Some(payload.to_string());
                }
            }
            _ => {
                // Skip unrecognized or future records gracefully
            }
        }
    }

    if let Some(def) = current_def {
        if !def.geometry_records.is_empty() || !def.name.is_empty() {
            definitions.push(def);
        }
    }

    // Discretize and compile raw definitions into Airspace instances
    let mut airspaces = Vec::new();
    for (idx, def) in definitions.into_iter().enumerate() {
        let id = format!(
            "{}-{}",
            if def.name.is_empty() { "airspace" } else { &def.name }
                .to_lowercase()
                .replace(|c: char| !c.is_alphanumeric(), "_")
                .trim_matches('_'),
            idx + 1
        );

        let polygon = discretize_geometry(
            &def.geometry_records,
            def.center_variable,
            def.direction_variable,
            10.0, // 10m chord tolerance
        );

        if polygon.len() >= 3 {
            if let Some(airspace) = Airspace::new(
                id,
                if def.name.is_empty() {
                    format!("Airspace {}", idx + 1)
                } else {
                    def.name
                },
                def.class,
                def.floor,
                def.ceiling,
                polygon,
            ) {
                airspaces.push(airspace);
            }
        }
    }

    ParseResult {
        airspaces,
        warnings,
    }
}

/// Parses vertical limits from text tokens like `FL 100`, `5000ft MSL`, `1500m AGL`, `GND`, `SFC`, `UNL`.
pub fn parse_vertical_limit(input: &str) -> Result<VerticalLimit, String> {
    let raw = input.trim();
    let upper = raw.to_uppercase();

    if upper == "GND" || upper == "SFC" || upper == "GROUND" || upper == "SURFACE" {
        return Ok(VerticalLimit::Surface);
    }
    if upper == "UNL" || upper == "UNLIMITED" {
        return Ok(VerticalLimit::Unlimited);
    }

    // Flight Level: FL 100 or FL100 or FL065
    if let Some(fl_str) = upper.strip_prefix("FL") {
        let fl_num: u32 = fl_str
            .trim()
            .parse()
            .map_err(|e| format!("Invalid Flight Level '{fl_str}': {e}"))?;
        return Ok(VerticalLimit::FlightLevel(fl_num));
    }

    // Extract numeric portion and unit/reference tokens
    // Examples: "5000FT AGL", "5000 FT MSL", "1500M AMSL", "1000 AGL", "3000 MSL", "4500 FT"
    let mut number_chars = String::new();
    let mut remainder = String::new();
    let mut parsing_number = true;

    for ch in upper.chars() {
        if parsing_number && (ch.is_ascii_digit() || ch == '.') {
            number_chars.push(ch);
        } else {
            parsing_number = false;
            remainder.push(ch);
        }
    }

    let val: f64 = number_chars
        .parse()
        .map_err(|e| format!("Invalid numeric altitude in '{input}': {e}"))?;

    let rem = remainder.trim();
    let is_meters = rem.starts_with('M') && !rem.starts_with("MSL");
    let is_agl = rem.contains("AGL");

    if is_agl {
        if is_meters {
            Ok(VerticalLimit::MetersAgl(val))
        } else {
            Ok(VerticalLimit::FeetAgl(val))
        }
    } else if is_meters {
        Ok(VerticalLimit::MetersMsl(val))
    } else {
        // Default is Feet MSL
        Ok(VerticalLimit::FeetMsl(val))
    }
}

/// Parses a geographic coordinate from diverse OpenAir representations:
/// - DMS: `47:30:00 N 013:00:00 E` or `47:30:00N 013:00:00E`
/// - DM: `47:30.500 N 013:00.250 E`
/// - Space DMS: `47 30 00 N 013 00 00 E`
/// - Decimal degrees: `47.5000 N 13.0000 E` or `47.5000, 13.0000` or `47.5000 13.0000`
pub fn parse_coordinate(input: &str) -> Result<Coordinate, String> {
    let trimmed = input.trim();

    // Check for comma or whitespace separated signed decimal degrees
    if !trimmed.contains('N')
        && !trimmed.contains('S')
        && !trimmed.contains('E')
        && !trimmed.contains('W')
    {
        let parts: Vec<&str> = trimmed
            .split([',', ';', ' '])
            .filter(|s| !s.is_empty())
            .collect();
        if parts.len() == 2 {
            let lat: f64 = parts[0]
                .parse()
                .map_err(|e| format!("Failed to parse decimal lat: {e}"))?;
            let lon: f64 = parts[1]
                .parse()
                .map_err(|e| format!("Failed to parse decimal lon: {e}"))?;
            return Ok(Coordinate::new(lat, lon));
        }
    }

    // Split into latitude and longitude components by finding hemisphere indicators
    let upper = trimmed.to_uppercase();

    let n_pos = upper.find('N');
    let s_pos = upper.find('S');
    let lat_hemi_pos = match (n_pos, s_pos) {
        (Some(n), Some(s)) => Some(n.min(s)),
        (Some(n), None) => Some(n),
        (None, Some(s)) => Some(s),
        (None, None) => None,
    };

    let lat_pos = lat_hemi_pos.ok_or_else(|| format!("Missing N/S in coordinate '{input}'"))?;

    let lat_str = upper[..=lat_pos].trim();
    let lon_str = upper[lat_pos + 1..].trim();

    let lat = parse_single_dms_or_decimal(lat_str, true)?;
    let lon = parse_single_dms_or_decimal(lon_str, false)?;

    Ok(Coordinate::new(lat, lon))
}

fn parse_single_dms_or_decimal(token: &str, is_latitude: bool) -> Result<f64, String> {
    let trimmed = token.trim();
    if trimmed.is_empty() {
        return Err("Empty coordinate component".to_string());
    }

    let (sign, clean_token) = if is_latitude {
        if trimmed.ends_with('S') {
            (-1.0, trimmed.trim_end_matches('S').trim())
        } else if trimmed.ends_with('N') {
            (1.0, trimmed.trim_end_matches('N').trim())
        } else {
            (1.0, trimmed)
        }
    } else if trimmed.ends_with('W') {
        (-1.0, trimmed.trim_end_matches('W').trim())
    } else if trimmed.ends_with('E') {
        (1.0, trimmed.trim_end_matches('E').trim())
    } else {
        (1.0, trimmed)
    };

    // Check if separated by colons: DD:MM:SS or DD:MM.MMM
    let colon_parts: Vec<&str> = clean_token.split(':').collect();
    if colon_parts.len() == 3 {
        let deg: f64 = colon_parts[0]
            .trim()
            .parse()
            .map_err(|e| format!("Invalid degrees '{token}': {e}"))?;
        let min: f64 = colon_parts[1]
            .trim()
            .parse()
            .map_err(|e| format!("Invalid minutes '{token}': {e}"))?;
        let sec: f64 = colon_parts[2]
            .trim()
            .parse()
            .map_err(|e| format!("Invalid seconds '{token}': {e}"))?;
        return Ok(sign * (deg + min / 60.0 + sec / 3600.0));
    } else if colon_parts.len() == 2 {
        let deg: f64 = colon_parts[0]
            .trim()
            .parse()
            .map_err(|e| format!("Invalid degrees '{token}': {e}"))?;
        let min: f64 = colon_parts[1]
            .trim()
            .parse()
            .map_err(|e| format!("Invalid minutes '{token}': {e}"))?;
        return Ok(sign * (deg + min / 60.0));
    }

    // Check space-separated: DD MM SS or DD MM.MMM
    let space_parts: Vec<&str> = clean_token.split_whitespace().collect();
    if space_parts.len() == 3 {
        let deg: f64 = space_parts[0]
            .parse()
            .map_err(|e| format!("Invalid degrees: {e}"))?;
        let min: f64 = space_parts[1]
            .parse()
            .map_err(|e| format!("Invalid minutes: {e}"))?;
        let sec: f64 = space_parts[2]
            .parse()
            .map_err(|e| format!("Invalid seconds: {e}"))?;
        return Ok(sign * (deg + min / 60.0 + sec / 3600.0));
    } else if space_parts.len() == 2 {
        let deg: f64 = space_parts[0]
            .parse()
            .map_err(|e| format!("Invalid degrees: {e}"))?;
        let min: f64 = space_parts[1]
            .parse()
            .map_err(|e| format!("Invalid minutes: {e}"))?;
        return Ok(sign * (deg + min / 60.0));
    }

    // Decimal degrees fallback
    let val: f64 = clean_token
        .parse()
        .map_err(|e| format!("Cannot parse coordinate value '{clean_token}': {e}"))?;
    Ok(sign * val)
}

fn parse_arc_angle_params(payload: &str) -> Result<(f64, f64, f64), String> {
    let parts: Vec<&str> = payload.split(',').collect();
    if parts.len() != 3 {
        return Err(format!("Expected 3 parameters for DA, got {}", parts.len()));
    }
    let radius: f64 = parts[0]
        .trim()
        .parse()
        .map_err(|e| format!("Invalid radius: {e}"))?;
    let start_deg: f64 = parts[1]
        .trim()
        .parse()
        .map_err(|e| format!("Invalid start angle: {e}"))?;
    let end_deg: f64 = parts[2]
        .trim()
        .parse()
        .map_err(|e| format!("Invalid end angle: {e}"))?;
    Ok((radius, start_deg, end_deg))
}

fn parse_arc_points_params(payload: &str) -> Result<(Coordinate, Coordinate), String> {
    let parts: Vec<&str> = payload.split(',').collect();
    if parts.len() != 2 {
        return Err(format!("Expected 2 points for DB, got {}", parts.len()));
    }
    let p1 = parse_coordinate(parts[0].trim())?;
    let p2 = parse_coordinate(parts[1].trim())?;
    Ok((p1, p2))
}

/// Discretizes a sequence of geometry records into a closed planar polygon.
#[must_use]
pub fn discretize_geometry(
    records: &[GeometryRecord],
    default_center: Option<Coordinate>,
    default_direction: ArcDirection,
    chord_tolerance_m: f64,
) -> Vec<Coordinate> {
    let mut vertices = Vec::new();

    for record in records {
        match record {
            GeometryRecord::Point(coord) => {
                vertices.push(*coord);
            }
            GeometryRecord::Circle { radius_nm } => {
                if let Some(center) = default_center {
                    let circle_pts = discretize_circle(center, *radius_nm, chord_tolerance_m);
                    vertices.extend(circle_pts);
                }
            }
            GeometryRecord::ArcByAngle {
                radius_nm,
                start_angle_deg,
                end_angle_deg,
            } => {
                if let Some(center) = default_center {
                    let arc_pts = discretize_arc_by_angle(
                        center,
                        *radius_nm,
                        *start_angle_deg,
                        *end_angle_deg,
                        default_direction,
                        chord_tolerance_m,
                    );
                    vertices.extend(arc_pts);
                }
            }
            GeometryRecord::ArcByPoints { start, end } => {
                if let Some(center) = default_center {
                    let arc_pts = discretize_arc_by_points(
                        center,
                        *start,
                        *end,
                        default_direction,
                        chord_tolerance_m,
                    );
                    vertices.extend(arc_pts);
                }
            }
        }
    }

    // Ensure polygon is closed
    if let (Some(first), Some(last)) = (vertices.first(), vertices.last()) {
        if (first.latitude - last.latitude).abs() > 1e-7
            || (first.longitude - last.longitude).abs() > 1e-7
        {
            vertices.push(*first);
        }
    }

    vertices
}

/// Discretizes a full circle into polygonal vertices with chord distance tolerance <= `chord_tolerance_m`.
#[must_use]
pub fn discretize_circle(
    center: Coordinate,
    radius_nm: f64,
    chord_tolerance_m: f64,
) -> Vec<Coordinate> {
    let radius_m = radius_nm * METERS_PER_NAUTICAL_MILE;
    let step_rad = compute_angular_step_rad(radius_m, chord_tolerance_m);
    let num_steps = ((2.0 * PI / step_rad).ceil() as usize).max(16);

    let mut points = Vec::with_capacity(num_steps + 1);
    for i in 0..num_steps {
        let bearing_rad = (i as f64) * (2.0 * PI / (num_steps as f64));
        let pt = geodesic_destination(center, radius_m, bearing_rad);
        points.push(pt);
    }
    if let Some(first) = points.first().copied() {
        points.push(first);
    }
    points
}

/// Discretizes an arc specified by start and end angles (in degrees) around `center`.
#[must_use]
pub fn discretize_arc_by_angle(
    center: Coordinate,
    radius_nm: f64,
    start_deg: f64,
    end_deg: f64,
    direction: ArcDirection,
    chord_tolerance_m: f64,
) -> Vec<Coordinate> {
    let radius_m = radius_nm * METERS_PER_NAUTICAL_MILE;
    let step_rad = compute_angular_step_rad(radius_m, chord_tolerance_m);

    let start_rad = start_deg.to_radians();
    let mut end_rad = end_deg.to_radians();

    match direction {
        ArcDirection::Clockwise => {
            while end_rad <= start_rad {
                end_rad += 2.0 * PI;
            }
        }
        ArcDirection::CounterClockwise => {
            while end_rad >= start_rad {
                end_rad -= 2.0 * PI;
            }
        }
    }

    let total_delta = (end_rad - start_rad).abs();
    let num_steps = ((total_delta / step_rad).ceil() as usize).max(2);

    let mut points = Vec::with_capacity(num_steps + 1);
    for i in 0..=num_steps {
        let t = (i as f64) / (num_steps as f64);
        let bearing_rad = start_rad + t * (end_rad - start_rad);
        points.push(geodesic_destination(center, radius_m, bearing_rad));
    }
    points
}

/// Discretizes an arc specified by start and end coordinates around `center`.
#[must_use]
pub fn discretize_arc_by_points(
    center: Coordinate,
    start: Coordinate,
    end: Coordinate,
    direction: ArcDirection,
    chord_tolerance_m: f64,
) -> Vec<Coordinate> {
    let radius_m = geodesic_distance(center, start);
    let radius_nm = radius_m / METERS_PER_NAUTICAL_MILE;

    let start_bearing = geodesic_bearing(center, start);
    let end_bearing = geodesic_bearing(center, end);

    discretize_arc_by_angle(
        center,
        radius_nm,
        start_bearing.to_degrees(),
        end_bearing.to_degrees(),
        direction,
        chord_tolerance_m,
    )
}

/// Computes the angular step in radians required to guarantee chord error <= chord_tolerance_m.
/// Formula: Delta theta = 2 * arccos(1 - epsilon / R)
fn compute_angular_step_rad(radius_m: f64, chord_tolerance_m: f64) -> f64 {
    if radius_m <= chord_tolerance_m {
        return PI / 4.0; // 45 degrees
    }
    let ratio = (1.0 - chord_tolerance_m / radius_m).clamp(-1.0, 1.0);
    let step = 2.0 * ratio.acos();
    // Clamp between 1 degree and 30 degrees
    step.clamp(PI / 180.0, PI / 6.0)
}

/// Great-circle geodesic forward calculation (destination point from start, distance, bearing).
pub fn geodesic_destination(start: Coordinate, distance_m: f64, bearing_rad: f64) -> Coordinate {
    let phi1 = start.latitude.to_radians();
    let lambda1 = start.longitude.to_radians();
    let delta = distance_m / EARTH_RADIUS_METERS;

    let sin_phi1 = phi1.sin();
    let cos_phi1 = phi1.cos();
    let sin_delta = delta.sin();
    let cos_delta = delta.cos();

    let sin_phi2 = sin_phi1 * cos_delta + cos_phi1 * sin_delta * bearing_rad.cos();
    let phi2 = sin_phi2.asin();

    let y = bearing_rad.sin() * sin_delta * cos_phi1;
    let x = cos_delta - sin_phi1 * sin_phi2;
    let lambda2 = lambda1 + y.atan2(x);

    let lat = phi2.to_degrees();
    let lon = lambda2.to_degrees();

    Coordinate::new(lat, lon)
}

/// Great-circle distance between two points using the Haversine formula.
pub fn geodesic_distance(p1: Coordinate, p2: Coordinate) -> f64 {
    let phi1 = p1.latitude.to_radians();
    let phi2 = p2.latitude.to_radians();
    let delta_phi = (p2.latitude - p1.latitude).to_radians();
    let delta_lambda = (p2.longitude - p1.longitude).to_radians();

    let a = (delta_phi / 2.0).sin().powi(2)
        + phi1.cos() * phi2.cos() * (delta_lambda / 2.0).sin().powi(2);
    let c = 2.0 * a.sqrt().atan2((1.0 - a).sqrt());

    EARTH_RADIUS_METERS * c
}

/// Great-circle initial bearing from p1 to p2 in radians [0, 2*PI).
pub fn geodesic_bearing(p1: Coordinate, p2: Coordinate) -> f64 {
    let phi1 = p1.latitude.to_radians();
    let phi2 = p2.latitude.to_radians();
    let delta_lambda = (p2.longitude - p1.longitude).to_radians();

    let y = delta_lambda.sin() * phi2.cos();
    let x = phi1.cos() * phi2.sin() - phi1.sin() * phi2.cos() * delta_lambda.cos();
    let bearing = y.atan2(x);

    (bearing + 2.0 * PI).rem_euclid(2.0 * PI)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_coordinate_formats() {
        // DMS with colons and hemisphere
        let c1 = parse_coordinate("47:30:00 N 013:00:00 E").expect("DMS");
        assert!((c1.latitude - 47.5).abs() < 1e-4);
        assert!((c1.longitude - 13.0).abs() < 1e-4);

        // DMS without spaces between seconds and hemisphere
        let c2 = parse_coordinate("47:15:30N 011:23:45E").expect("DMS compact");
        assert!((c2.latitude - (47.0 + 15.0 / 60.0 + 30.0 / 3600.0)).abs() < 1e-4);

        // Decimal minutes
        let c3 = parse_coordinate("47:30.500 N 013:00.250 E").expect("DM colons");
        assert!((c3.latitude - (47.0 + 30.5 / 60.0)).abs() < 1e-4);
        assert!((c3.longitude - (13.0 + 0.25 / 60.0)).abs() < 1e-4);

        // Space separated DMS
        let c4 = parse_coordinate("47 30 00 N 013 00 00 E").expect("Space DMS");
        assert!((c4.latitude - 47.5).abs() < 1e-4);

        // Signed decimal degrees
        let c5 = parse_coordinate("47.5000, 13.0000").expect("Decimal comma");
        assert_eq!(c5.latitude, 47.5);
        assert_eq!(c5.longitude, 13.0);

        let c6 = parse_coordinate("47.5000 13.0000").expect("Decimal space");
        assert_eq!(c6.latitude, 47.5);
        assert_eq!(c6.longitude, 13.0);

        // South and West
        let c7 = parse_coordinate("25:00:00 S 045:00:00 W").expect("South West");
        assert_eq!(c7.latitude, -25.0);
        assert_eq!(c7.longitude, -45.0);
    }

    #[test]
    fn test_parse_vertical_limits() {
        assert_eq!(
            parse_vertical_limit("FL 100").unwrap(),
            VerticalLimit::FlightLevel(100)
        );
        assert_eq!(
            parse_vertical_limit("FL065").unwrap(),
            VerticalLimit::FlightLevel(65)
        );
        assert_eq!(
            parse_vertical_limit("5000ft MSL").unwrap(),
            VerticalLimit::FeetMsl(5000.0)
        );
        assert_eq!(
            parse_vertical_limit("5000 FT AMSL").unwrap(),
            VerticalLimit::FeetMsl(5000.0)
        );
        assert_eq!(
            parse_vertical_limit("1500m MSL").unwrap(),
            VerticalLimit::MetersMsl(1500.0)
        );
        assert_eq!(
            parse_vertical_limit("1000ft AGL").unwrap(),
            VerticalLimit::FeetAgl(1000.0)
        );
        assert_eq!(
            parse_vertical_limit("300m AGL").unwrap(),
            VerticalLimit::MetersAgl(300.0)
        );
        assert_eq!(
            parse_vertical_limit("GND").unwrap(),
            VerticalLimit::Surface
        );
        assert_eq!(
            parse_vertical_limit("SFC").unwrap(),
            VerticalLimit::Surface
        );
        assert_eq!(
            parse_vertical_limit("UNL").unwrap(),
            VerticalLimit::Unlimited
        );
    }

    #[test]
    fn test_discretize_circle_chord_error() {
        let center = Coordinate::new(47.5, 13.0);
        let radius_nm = 5.0; // ~9260m
        let circle = discretize_circle(center, radius_nm, 10.0);

        assert!(circle.len() > 30);
        // Closed polygon
        assert_eq!(circle.first(), circle.last());

        // Check each chord sagitta (chord error)
        let radius_m = radius_nm * METERS_PER_NAUTICAL_MILE;
        for i in 0..circle.len() - 1 {
            let chord_len = geodesic_distance(circle[i], circle[i + 1]);
            let sagitta = radius_m - (radius_m.powi(2) - (chord_len / 2.0).powi(2)).sqrt();
            assert!(
                sagitta <= 10.5,
                "Chord error sagitta {sagitta} exceeds 10m tolerance"
            );
        }
    }

    #[test]
    fn test_parse_openair_polygonal_scenario() {
        let openair_data = r#"
* Sample OpenAir File - Austria / Germany Border
AC R
AN ED-R107
AL 1000ft AGL
AH FL 100
DP 47:30:00 N 013:00:00 E
DP 47:35:00 N 013:00:00 E
DP 47:35:00 N 013:10:00 E
DP 47:30:00 N 013:10:00 E

AC CTR
AN INNSBRUCK CTR
AL GND
AH 5000ft MSL
V X=47:15:36 N 011:20:38 E
DC 5.0
"#;

        let result = parse_openair(openair_data);
        assert!(result.warnings.is_empty(), "Warnings: {:?}", result.warnings);
        assert_eq!(result.airspaces.len(), 2);

        let edr = &result.airspaces[0];
        assert_eq!(edr.name, "ED-R107");
        assert_eq!(edr.class, AirspaceClass::Restricted);
        assert_eq!(edr.floor, VerticalLimit::FeetAgl(1000.0));
        assert_eq!(edr.ceiling, VerticalLimit::FlightLevel(100));
        assert!(edr.polygon.len() >= 4);

        let ctr = &result.airspaces[1];
        assert_eq!(ctr.name, "INNSBRUCK CTR");
        assert_eq!(ctr.class, AirspaceClass::Ctr);
        assert_eq!(ctr.floor, VerticalLimit::Surface);
        assert_eq!(ctr.ceiling, VerticalLimit::FeetMsl(5000.0));
        assert!(ctr.polygon.len() > 30);
    }

    #[test]
    fn test_parse_openair_comments_and_malformed_graceful() {
        let openair_data = r#"
* Comment at top
INVALID RECORD SOMETHING

AC D
AN DANGER ZONE
AL GND
AH UNL
DP 47:00:00 N 011:00:00 E
* Inside comment
DP 47:10:00 N 011:00:00 E
DP INVALID_COORDINATE
DP 47:10:00 N 011:10:00 E
DP 47:00:00 N 011:10:00 E
"#;

        let result = parse_openair(openair_data);
        assert_eq!(result.airspaces.len(), 1);
        assert_eq!(result.airspaces[0].name, "DANGER ZONE");
        assert_eq!(result.warnings.len(), 1);
        assert!(result.warnings[0].message.contains("INVALID_COORDINATE"));
    }
}
