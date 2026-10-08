//! OpenAir Abstract Syntax Tree (AST) and core data models.

/// Classification of airspace according to ICAO standards and local regulatory extensions.
#[derive(Clone, Debug, PartialEq, Eq, Hash)]
pub enum AirspaceClass {
    /// ICAO Class A (IFR only)
    A,
    /// ICAO Class B
    B,
    /// ICAO Class C
    C,
    /// ICAO Class D
    D,
    /// ICAO Class E
    E,
    /// ICAO Class F
    F,
    /// ICAO Class G (uncontrolled)
    G,
    /// Control Zone
    Ctr,
    /// Prohibited Area (P)
    Prohibited,
    /// Restricted Area (R)
    Restricted,
    /// Danger Area (D)
    Danger,
    /// Warning Area (W)
    Warning,
    /// Glider Sector / Paragliding zone (GP)
    GliderSector,
    /// Transponder Mandatory Zone (TMZ)
    Tmz,
    /// Radio Mandatory Zone (RMZ)
    Rmz,
    /// Military Aerodrome Traffic Zone (MATZ)
    Matz,
    /// Aerodrome Traffic Zone (ATZ)
    Atz,
    /// Wave window
    Wave,
    /// Other / Custom classification
    Other(String),
}

impl AirspaceClass {
    /// Parses an airspace class token from OpenAir format.
    #[must_use]
    pub fn parse_code(code: &str) -> Self {
        let trimmed = code.trim().to_uppercase();
        match trimmed.as_str() {
            "A" => Self::A,
            "B" => Self::B,
            "C" => Self::C,
            "D" => Self::D,
            "E" => Self::E,
            "F" => Self::F,
            "G" => Self::G,
            "CTR" => Self::Ctr,
            "P" | "PROHIBITED" => Self::Prohibited,
            "R" | "RESTRICTED" => Self::Restricted,
            "Q" | "DANGER" => Self::Danger, // Q is danger in some international OpenAir files
            "W" | "WARNING" => Self::Warning,
            "GP" | "GLIDER" | "GLIDER_SECTOR" | "GLIDERSECTOR" => Self::GliderSector,
            "TMZ" => Self::Tmz,
            "RMZ" => Self::Rmz,
            "MATZ" => Self::Matz,
            "ATZ" => Self::Atz,
            "WAVE" => Self::Wave,
            other => Self::Other(other.to_string()),
        }
    }

    /// Returns canonical display string for the airspace class.
    #[must_use]
    pub fn as_str(&self) -> &str {
        match self {
            Self::A => "Class A",
            Self::B => "Class B",
            Self::C => "Class C",
            Self::D => "Class D",
            Self::E => "Class E",
            Self::F => "Class F",
            Self::G => "Class G",
            Self::Ctr => "CTR",
            Self::Prohibited => "Prohibited",
            Self::Restricted => "Restricted",
            Self::Danger => "Danger",
            Self::Warning => "Warning",
            Self::GliderSector => "Glider Sector",
            Self::Tmz => "TMZ",
            Self::Rmz => "RMZ",
            Self::Matz => "MATZ",
            Self::Atz => "ATZ",
            Self::Wave => "Wave",
            Self::Other(name) => name.as_str(),
        }
    }
}

/// Vertical boundary definition for an airspace floor or ceiling.
#[derive(Clone, Copy, Debug, PartialEq)]
pub enum VerticalLimit {
    /// Flight Level standard pressure altitude (e.g., FL 100 = 10,000 ft standard)
    FlightLevel(u32),
    /// Altitude in feet above Mean Sea Level (MSL / AMSL / ALT)
    FeetMsl(f64),
    /// Altitude in meters above Mean Sea Level (MSL / AMSL)
    MetersMsl(f64),
    /// Height in feet Above Ground Level (AGL)
    FeetAgl(f64),
    /// Height in meters Above Ground Level (AGL)
    MetersAgl(f64),
    /// Surface / Ground level (GND, SFC)
    Surface,
    /// Unlimited vertical limit (UNL, UNLIMITED)
    Unlimited,
}

impl VerticalLimit {
    /// Returns true if this limit references the ground/surface.
    #[must_use]
    pub const fn is_surface(&self) -> bool {
        matches!(self, Self::Surface)
    }

    /// Returns true if this limit is unlimited.
    #[must_use]
    pub const fn is_unlimited(&self) -> bool {
        matches!(self, Self::Unlimited)
    }

    /// Returns true if this limit depends on local terrain elevation (AGL).
    #[must_use]
    pub const fn is_terrain_relative(&self) -> bool {
        matches!(self, Self::FeetAgl(_) | Self::MetersAgl(_))
    }

    /// Returns true if this limit is a standard Flight Level requiring QNH offset.
    #[must_use]
    pub const fn is_flight_level(&self) -> bool {
        matches!(self, Self::FlightLevel(_))
    }
}

/// Geographic coordinate in decimal degrees.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Coordinate {
    /// Latitude in decimal degrees (-90.0 ..= +90.0)
    pub latitude: f64,
    /// Longitude in decimal degrees (-180.0 ..= +180.0)
    pub longitude: f64,
}

impl Coordinate {
    /// Constructs a validated coordinate, clamping to valid ranges.
    #[must_use]
    pub fn new(latitude: f64, longitude: f64) -> Self {
        Self {
            latitude: latitude.clamp(-90.0, 90.0),
            longitude: if (-180.0..=180.0).contains(&longitude) {
                longitude
            } else {
                // Normalize longitude to -180..180
                ((longitude + 180.0).rem_euclid(360.0)) - 180.0
            },
        }
    }
}

/// Direction of an arc rotation in OpenAir syntax (`V D=+` or `V D=-`).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ArcDirection {
    /// Clockwise (`+`)
    Clockwise,
    /// Counter-clockwise (`-`)
    CounterClockwise,
}

/// Axis-aligned bounding box in geographic coordinates.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct BoundingBox {
    pub min_lat: f64,
    pub max_lat: f64,
    pub min_lon: f64,
    pub max_lon: f64,
}

impl BoundingBox {
    /// Creates a bounding box spanning the given coordinates.
    #[must_use]
    pub fn from_coordinates(coordinates: &[Coordinate]) -> Option<Self> {
        let first = coordinates.first()?;
        let mut min_lat = first.latitude;
        let mut max_lat = first.latitude;
        let mut min_lon = first.longitude;
        let mut max_lon = first.longitude;

        for coord in coordinates.iter().skip(1) {
            if coord.latitude < min_lat {
                min_lat = coord.latitude;
            }
            if coord.latitude > max_lat {
                max_lat = coord.latitude;
            }
            if coord.longitude < min_lon {
                min_lon = coord.longitude;
            }
            if coord.longitude > max_lon {
                max_lon = coord.longitude;
            }
        }

        Some(Self {
            min_lat,
            max_lat,
            min_lon,
            max_lon,
        })
    }

    /// Returns true if the bounding box contains the specified coordinate.
    #[must_use]
    pub fn contains(&self, coord: Coordinate) -> bool {
        coord.latitude >= self.min_lat
            && coord.latitude <= self.max_lat
            && coord.longitude >= self.min_lon
            && coord.longitude <= self.max_lon
    }

    /// Returns true if this bounding box intersects another bounding box.
    #[must_use]
    pub fn intersects(&self, other: &Self) -> bool {
        self.min_lat <= other.max_lat
            && self.max_lat >= other.min_lat
            && self.min_lon <= other.max_lon
            && self.max_lon >= other.min_lon
    }

    /// Expands the bounding box by a margin in degrees.
    #[must_use]
    pub fn expand(&self, margin_deg: f64) -> Self {
        Self {
            min_lat: (self.min_lat - margin_deg).max(-90.0),
            max_lat: (self.max_lat + margin_deg).min(90.0),
            min_lon: (self.min_lon - margin_deg).max(-180.0),
            max_lon: (self.max_lon + margin_deg).min(180.0),
        }
    }
}

/// Raw geometric element from an OpenAir file before polygon discretization.
#[derive(Clone, Debug, PartialEq)]
pub enum GeometryRecord {
    /// Single polygon point (`DP`)
    Point(Coordinate),
    /// Complete circle with radius in Nautical Miles around current center `V X` (`DC`)
    Circle { radius_nm: f64 },
    /// Arc with radius in Nautical Miles, start angle, and end angle around current center (`DA`)
    ArcByAngle {
        radius_nm: f64,
        start_angle_deg: f64,
        end_angle_deg: f64,
    },
    /// Arc between two endpoint coordinates around current center (`DB`)
    ArcByPoints { start: Coordinate, end: Coordinate },
}

/// Raw parsed airspace definition before discretization.
#[derive(Clone, Debug, PartialEq)]
pub struct AirspaceDefinition {
    pub class: AirspaceClass,
    pub name: String,
    pub floor: VerticalLimit,
    pub ceiling: VerticalLimit,
    pub center_variable: Option<Coordinate>,
    pub direction_variable: ArcDirection,
    pub geometry_records: Vec<GeometryRecord>,
    pub pen_style: Option<String>,
    pub brush_style: Option<String>,
}

impl Default for AirspaceDefinition {
    fn default() -> Self {
        Self {
            class: AirspaceClass::Other("UNKNOWN".to_string()),
            name: String::new(),
            floor: VerticalLimit::Surface,
            ceiling: VerticalLimit::Unlimited,
            center_variable: None,
            direction_variable: ArcDirection::Clockwise,
            geometry_records: Vec::new(),
            pen_style: None,
            brush_style: None,
        }
    }
}

/// Fully compiled and discretized airspace entity ready for spatial indexing and proximity evaluation.
#[derive(Clone, Debug, PartialEq)]
pub struct Airspace {
    pub id: String,
    pub name: String,
    pub class: AirspaceClass,
    pub floor: VerticalLimit,
    pub ceiling: VerticalLimit,
    pub polygon: Vec<Coordinate>,
    pub bounding_box: BoundingBox,
}

impl Airspace {
    /// Creates a new compiled airspace from a closed polygon.
    #[must_use]
    pub fn new(
        id: String,
        name: String,
        class: AirspaceClass,
        floor: VerticalLimit,
        ceiling: VerticalLimit,
        polygon: Vec<Coordinate>,
    ) -> Option<Self> {
        let bounding_box = BoundingBox::from_coordinates(&polygon)?;
        Some(Self {
            id,
            name,
            class,
            floor,
            ceiling,
            polygon,
            bounding_box,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_airspace_class_parsing() {
        assert_eq!(AirspaceClass::parse_code("A"), AirspaceClass::A);
        assert_eq!(AirspaceClass::parse_code("ctr"), AirspaceClass::Ctr);
        assert_eq!(AirspaceClass::parse_code("P"), AirspaceClass::Prohibited);
        assert_eq!(AirspaceClass::parse_code("R"), AirspaceClass::Restricted);
        assert_eq!(AirspaceClass::parse_code("Q"), AirspaceClass::Danger);
        assert_eq!(AirspaceClass::parse_code("W"), AirspaceClass::Warning);
        assert_eq!(AirspaceClass::parse_code("GP"), AirspaceClass::GliderSector);
        assert_eq!(AirspaceClass::parse_code("TMZ"), AirspaceClass::Tmz);
        assert_eq!(AirspaceClass::parse_code("RMZ"), AirspaceClass::Rmz);
        assert_eq!(
            AirspaceClass::parse_code("CUSTOM_ZONE"),
            AirspaceClass::Other("CUSTOM_ZONE".to_string())
        );
    }

    #[test]
    fn test_vertical_limit_properties() {
        assert!(VerticalLimit::Surface.is_surface());
        assert!(!VerticalLimit::Unlimited.is_surface());
        assert!(VerticalLimit::Unlimited.is_unlimited());
        assert!(VerticalLimit::FlightLevel(100).is_flight_level());
        assert!(VerticalLimit::FeetAgl(1500.0).is_terrain_relative());
        assert!(VerticalLimit::MetersAgl(500.0).is_terrain_relative());
        assert!(!VerticalLimit::FeetMsl(5000.0).is_terrain_relative());
    }

    #[test]
    fn test_bounding_box_logic() {
        let coords = vec![
            Coordinate::new(47.0, 11.0),
            Coordinate::new(47.5, 11.0),
            Coordinate::new(47.5, 11.5),
            Coordinate::new(47.0, 11.5),
        ];

        let bbox = BoundingBox::from_coordinates(&coords).expect("Valid bbox");
        assert_eq!(bbox.min_lat, 47.0);
        assert_eq!(bbox.max_lat, 47.5);
        assert_eq!(bbox.min_lon, 11.0);
        assert_eq!(bbox.max_lon, 11.5);

        assert!(bbox.contains(Coordinate::new(47.2, 11.2)));
        assert!(!bbox.contains(Coordinate::new(46.9, 11.2)));

        let expanded = bbox.expand(0.1);
        assert!(expanded.contains(Coordinate::new(46.95, 11.2)));

        let overlapping = BoundingBox {
            min_lat: 47.4,
            max_lat: 48.0,
            min_lon: 11.4,
            max_lon: 12.0,
        };
        assert!(bbox.intersects(&overlapping));

        let disjoint = BoundingBox {
            min_lat: 48.0,
            max_lat: 49.0,
            min_lon: 12.0,
            max_lon: 13.0,
        };
        assert!(!bbox.intersects(&disjoint));
    }

    #[test]
    fn test_compiled_airspace_creation() {
        let coords = vec![
            Coordinate::new(47.0, 11.0),
            Coordinate::new(47.5, 11.0),
            Coordinate::new(47.5, 11.5),
            Coordinate::new(47.0, 11.0),
        ];

        let airspace = Airspace::new(
            "ed-r107".to_string(),
            "ED-R107".to_string(),
            AirspaceClass::Restricted,
            VerticalLimit::FeetAgl(1000.0),
            VerticalLimit::FlightLevel(100),
            coords,
        )
        .expect("compiled airspace");

        assert_eq!(airspace.name, "ED-R107");
        assert_eq!(airspace.class, AirspaceClass::Restricted);
        assert_eq!(airspace.bounding_box.min_lat, 47.0);
    }
}
