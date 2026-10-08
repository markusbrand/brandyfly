//! Real-world European and DACH (Germany, Austria, Switzerland) OpenAir test fixtures.

/// DACH and Alpine airspace test dataset containing CTRs, TMAs, Glider Sectors, Restricted,
/// and circular/arc zones.
pub const DACH_OPENAIR_SAMPLE: &str = r#"
* ==========================================
* DACH Free-Flight Airspace Test Fixture
* Region: Alps (Innsbruck, Salzburg, Munich, Zurich)
* ==========================================

* Innsbruck Control Zone (CTR)
AC CTR
AN INNSBRUCK CTR
AL GND
AH 5000ft MSL
DP 47:18:00 N 011:10:00 E
DP 47:18:00 N 011:35:00 E
DP 47:14:00 N 011:35:00 E
DP 47:14:00 N 011:10:00 E

* Salzburg Airport CTR with circle segment
AC CTR
AN LOWS SALZBURG CTR
AL GND
AH 4500 FT MSL
V X=47:47:35 N 013:00:15 E
V D=+
DC 4.3

* Munich Terminal Maneuvering Area (TMA) - Airspace C
AC C
AN MUENCHEN TMA 1
AL 4500ft MSL
AH FL 100
DP 48:20:00 N 011:40:00 E
DP 48:30:00 N 012:00:00 E
DP 48:15:00 N 012:15:00 E
DP 48:05:00 N 011:55:00 E

* Swiss Glider Sector (Engadin / Graubuenden)
AC GP
AN GLIDER SECTOR ENGADIN
AL 2500m MSL
AH FL 150
DP 46:30:00 N 009:50:00 E
DP 46:45:00 N 010:10:00 E
DP 46:35:00 N 010:25:00 E
DP 46:20:00 N 010:05:00 E

* Restricted Zone ED-R 107
AC R
AN ED-R 107 ALLGAEU
AL 1000 FT AGL
AH FL 65
DP 47:35:00 N 010:15:00 E
DP 47:45:00 N 010:25:00 E
DP 47:40:00 N 010:40:00 E
DP 47:30:00 N 010:30:00 E

* Arc airspace using DA
AC Q
AN DANGER AREA D-08 ALPINE ARC
AL GND
AH 12000 FT MSL
V X=47:10:00 N 012:00:00 E
V D=+
DA 5.0, 045, 225
DP 47:05:00 N 012:00:00 E

* Arc airspace using DB
AC TMZ
AN TMZ SALZBURG APPROACH
AL 1000ft AGL
AH 5000ft MSL
V X=47:50:00 N 013:10:00 E
V D=+
DB 47:55:00 N 013:10:00 E, 47:50:00 N 013:18:00 E
DP 47:48:00 N 013:10:00 E
"#;

#[cfg(test)]
mod tests {
    use super::*;
    use crate::airspace::ast::{AirspaceClass, VerticalLimit};
    use crate::airspace::parser::parse_openair;

    #[test]
    fn test_parse_dach_openair_fixtures() {
        let result = parse_openair(DACH_OPENAIR_SAMPLE);

        assert!(
            result.warnings.is_empty(),
            "Expected zero warnings, got: {:?}",
            result.warnings
        );
        assert_eq!(result.airspaces.len(), 7);

        // Verify Innsbruck CTR
        let innsbruck = &result.airspaces[0];
        assert_eq!(innsbruck.name, "INNSBRUCK CTR");
        assert_eq!(innsbruck.class, AirspaceClass::Ctr);
        assert_eq!(innsbruck.floor, VerticalLimit::Surface);
        assert_eq!(innsbruck.ceiling, VerticalLimit::FeetMsl(5000.0));

        // Verify Salzburg CTR circle
        let salzburg = &result.airspaces[1];
        assert_eq!(salzburg.name, "LOWS SALZBURG CTR");
        assert_eq!(salzburg.class, AirspaceClass::Ctr);
        assert_eq!(salzburg.floor, VerticalLimit::Surface);
        assert_eq!(salzburg.ceiling, VerticalLimit::FeetMsl(4500.0));
        assert!(salzburg.polygon.len() >= 30);

        // Verify Munich TMA Airspace C
        let munich = &result.airspaces[2];
        assert_eq!(munich.name, "MUENCHEN TMA 1");
        assert_eq!(munich.class, AirspaceClass::C);
        assert_eq!(munich.floor, VerticalLimit::FeetMsl(4500.0));
        assert_eq!(munich.ceiling, VerticalLimit::FlightLevel(100));

        // Verify Swiss Glider Sector
        let engadin = &result.airspaces[3];
        assert_eq!(engadin.name, "GLIDER SECTOR ENGADIN");
        assert_eq!(engadin.class, AirspaceClass::GliderSector);
        assert_eq!(engadin.floor, VerticalLimit::MetersMsl(2500.0));
        assert_eq!(engadin.ceiling, VerticalLimit::FlightLevel(150));

        // Verify Restricted Area
        let edr = &result.airspaces[4];
        assert_eq!(edr.name, "ED-R 107 ALLGAEU");
        assert_eq!(edr.class, AirspaceClass::Restricted);
        assert_eq!(edr.floor, VerticalLimit::FeetAgl(1000.0));
        assert_eq!(edr.ceiling, VerticalLimit::FlightLevel(65));

        // Verify Danger Arc DA
        let danger_arc = &result.airspaces[5];
        assert_eq!(danger_arc.name, "DANGER AREA D-08 ALPINE ARC");
        assert_eq!(danger_arc.class, AirspaceClass::Danger);
        assert!(danger_arc.polygon.len() >= 10);

        // Verify TMZ Arc DB
        let tmz = &result.airspaces[6];
        assert_eq!(tmz.name, "TMZ SALZBURG APPROACH");
        assert_eq!(tmz.class, AirspaceClass::Tmz);
        assert_eq!(tmz.floor, VerticalLimit::FeetAgl(1000.0));
        assert_eq!(tmz.ceiling, VerticalLimit::FeetMsl(5000.0));
        assert!(tmz.polygon.len() >= 5);
    }
}
