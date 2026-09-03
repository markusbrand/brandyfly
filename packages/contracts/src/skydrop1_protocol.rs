#![forbid(unsafe_code)]

use crate::native_flight_pipeline::{
    LatencySummary, MAX_ALLOWED_CORE_P95_LATENCY_MS, SensorQualityFlags,
};

/// Schema version for SkyDrop 1 protocol and transport contracts.
pub const SKYDROP1_PROTOCOL_SCHEMA_VERSION: u16 = 1;

/// Standard Bluetooth Classic SPP UUID used by SkyDrop 1.
pub const SKYDROP1_BT_SPP_UUID: &str = "00001101-0000-1000-8000-00805F9B34FB";

/// Verified firmware version scope for SkyDrop 1 validation.
pub const SKYDROP1_VERIFIED_FIRMWARE_SCOPE: &str = "SkyDrop v1.4.x - v1.5.x";

/// Authoritative verification date for protocol and transport evidence.
pub const SKYDROP1_VERIFICATION_DATE: &str = "2026-08-25";

/// Platform support status classification.
#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash)]
pub enum PlatformSupportStatus {
    Supported,
    Unsupported,
    Blocked,
}

impl PlatformSupportStatus {
    #[must_use]
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::Supported => "supported",
            Self::Unsupported => "unsupported",
            Self::Blocked => "blocked",
        }
    }
}

/// Permitted platform support matrix and governance record.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct SkyDrop1PlatformSupportRecord {
    pub schema_version: u16,
    pub verification_date: String,
    pub firmware_scope: String,
    pub android_status: PlatformSupportStatus,
    pub android_transport: String,
    pub android_evidence: String,
    pub ios_status: PlatformSupportStatus,
    pub ios_transport: String,
    pub ios_evidence: String,
    pub fallback_strategy: String,
}

impl SkyDrop1PlatformSupportRecord {
    #[must_use]
    pub fn authoritative() -> Self {
        Self {
            schema_version: SKYDROP1_PROTOCOL_SCHEMA_VERSION,
            verification_date: SKYDROP1_VERIFICATION_DATE.to_string(),
            firmware_scope: SKYDROP1_VERIFIED_FIRMWARE_SCOPE.to_string(),
            android_status: PlatformSupportStatus::Supported,
            android_transport: "Bluetooth Classic RFCOMM / SPP (API 29+)".to_string(),
            android_evidence: "Physical SkyDrop 1 hardware paired via standard SPP UUID 00001101-0000-1000-8000-00805F9B34FB; monotonic timestamping at native receiver".to_string(),
            ios_status: PlatformSupportStatus::Unsupported,
            ios_transport: "None (Bluetooth Classic SPP requires Apple MFi certification and ExternalAccessory framework not supported by SkyDrop 1)".to_string(),
            ios_evidence: "Apple iOS platform restriction: Standard BT Classic RFCOMM sockets are prohibited without Apple MFi coprocessor and protocol whitelisting. SkyDrop 1 lacks MFi chip.".to_string(),
            fallback_strategy: "Internal iOS barometric and GPS sensors remain active; UI clearly reports SkyDrop 1 as unsupported on iOS without misleading fallbacks.".to_string(),
        }
    }
}

/// Raw received byte frame from SkyDrop 1 with native timestamping metadata.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct SkyDrop1RawFrame {
    pub schema_version: u16,
    pub trace_id: u64,
    pub sequence: u64,
    pub native_received_timestamp_ns: u64,
    pub raw_payload: Vec<u8>,
}

/// Parsed physical sensor sample from a verified SkyDrop 1 sentence.
#[derive(Clone, Debug, PartialEq)]
pub struct SkyDrop1ParsedSample {
    pub schema_version: u16,
    pub trace_id: u64,
    pub sequence: u64,
    pub native_received_timestamp_ns: u64,
    pub core_processed_timestamp_ns: u64,
    pub pressure_hpa: Option<f64>,
    pub altitude_m: Option<f64>,
    pub vario_mps: Option<f64>,
    pub temperature_c: Option<f64>,
    pub battery_percent: Option<f64>,
    pub quality_flags: SensorQualityFlags,
}

/// Explicit error reasons during SkyDrop 1 frame parsing or sanitization.
#[derive(Clone, Debug, Eq, PartialEq, Hash)]
pub enum SkyDrop1ParseError {
    EmptyFrame,
    UnsupportedSchemaVersion,
    NonPositiveReceiveTimestamp,
    NonMonotonicSequence,
    MalformedFraming(&'static str),
    ChecksumMismatch { expected: u8, calculated: u8 },
    UnrecognizedSentenceType(String),
    BlockedUnverifiedField(&'static str),
    InvalidFieldFormat(&'static str),
    ValueOutOfBounds(&'static str),
    SanitizationViolation(&'static str),
}

impl SkyDrop1ParseError {
    #[must_use]
    pub const fn as_str(&self) -> &'static str {
        match self {
            Self::EmptyFrame => "empty_frame",
            Self::UnsupportedSchemaVersion => "unsupported_schema_version",
            Self::NonPositiveReceiveTimestamp => "non_positive_receive_timestamp",
            Self::NonMonotonicSequence => "non_monotonic_sequence",
            Self::MalformedFraming(_) => "malformed_framing",
            Self::ChecksumMismatch { .. } => "checksum_mismatch",
            Self::UnrecognizedSentenceType(_) => "unrecognized_sentence_type",
            Self::BlockedUnverifiedField(_) => "blocked_unverified_field",
            Self::InvalidFieldFormat(_) => "invalid_field_format",
            Self::ValueOutOfBounds(_) => "value_out_of_bounds",
            Self::SanitizationViolation(_) => "sanitization_violation",
        }
    }
}

/// Transport lifecycle events observable on the native connection stream.
#[derive(Clone, Debug, PartialEq)]
pub enum SkyDrop1TransportEvent {
    Connected {
        device_address_masked: String,
        timestamp_ns: u64,
    },
    Disconnected {
        reason: String,
        timestamp_ns: u64,
    },
    Reconnecting {
        attempt: u32,
        timestamp_ns: u64,
    },
    Reconnected {
        duration_ms: f64,
        timestamp_ns: u64,
    },
    StaleDetected {
        stale_interval_ms: f64,
        timestamp_ns: u64,
    },
    SequenceGapDetected {
        expected_sequence: u64,
        received_sequence: u64,
        timestamp_ns: u64,
    },
    ParseFailed {
        error: SkyDrop1ParseError,
        raw_snippet: String,
        timestamp_ns: u64,
    },
}

/// Monotonic stage trace for an end-to-end SkyDrop 1 sample.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct SkyDrop1StageTrace {
    pub trace_id: u64,
    pub sequence: u64,
    pub native_received_ns: u64,
    pub core_processed_ns: u64,
    pub is_valid: bool,
    pub is_stale: bool,
}

impl SkyDrop1StageTrace {
    #[must_use]
    pub fn latency_ms(&self) -> f64 {
        if self.core_processed_ns >= self.native_received_ns {
            (self.core_processed_ns - self.native_received_ns) as f64 / 1_000_000.0
        } else {
            0.0
        }
    }
}

/// Integrity and quality counters for SkyDrop 1 transport validation.
#[derive(Clone, Copy, Debug, Default, Eq, PartialEq)]
pub struct SkyDrop1IntegrityCounters {
    pub total_frames_received: u64,
    pub valid_samples_parsed: u64,
    pub parse_failures: u64,
    pub duplicates_detected: u64,
    pub sequence_gaps_detected: u64,
    pub stale_samples_count: u64,
    pub disconnect_events_count: u64,
    pub reconnect_success_count: u64,
}

/// Verification report schema summarizing hardware run results.
#[derive(Clone, Debug, PartialEq)]
pub struct SkyDrop1ValidationReport {
    pub schema_version: u16,
    pub report_title: String,
    pub test_duration_minutes: f64,
    pub device_model: String,
    pub android_version: String,
    pub firmware_version: String,
    pub sample_rate_hz: f64,
    pub counters: SkyDrop1IntegrityCounters,
    pub latency_summary: LatencySummary,
    pub latency_gate_passed: bool,
    pub reconnect_without_restart_passed: bool,
    pub platform_matrix: SkyDrop1PlatformSupportRecord,
}

impl SkyDrop1ValidationReport {
    #[allow(clippy::too_many_arguments)]
    #[must_use]
    pub fn new(
        test_duration_minutes: f64,
        device_model: String,
        android_version: String,
        firmware_version: String,
        sample_rate_hz: f64,
        counters: SkyDrop1IntegrityCounters,
        latency_samples: Vec<f64>,
        reconnect_without_restart_passed: bool,
    ) -> Self {
        let latency_summary = LatencySummary::from_samples(latency_samples);
        let latency_gate_passed = latency_summary.p95_ms <= MAX_ALLOWED_CORE_P95_LATENCY_MS;

        Self {
            schema_version: SKYDROP1_PROTOCOL_SCHEMA_VERSION,
            report_title: "SkyDrop 1 Hardware Transport & Protocol Validation Report".to_string(),
            test_duration_minutes,
            device_model,
            android_version,
            firmware_version,
            sample_rate_hz,
            counters,
            latency_summary,
            latency_gate_passed,
            reconnect_without_restart_passed,
            platform_matrix: SkyDrop1PlatformSupportRecord::authoritative(),
        }
    }
}

/// Calculates NMEA-standard 8-bit XOR checksum over ASCII characters.
#[must_use]
pub fn calculate_nmea_checksum(payload: &str) -> u8 {
    let mut checksum: u8 = 0;
    for byte in payload.bytes() {
        checksum ^= byte;
    }
    checksum
}

/// Validates that a raw buffer contains no secrets, private tokens, or unsanitized precise coordinates.
pub fn sanitize_skydrop_payload(raw_bytes: &[u8]) -> Result<(), SkyDrop1ParseError> {
    let text = match std::str::from_utf8(raw_bytes) {
        Ok(s) => s,
        Err(_) => {
            return Err(SkyDrop1ParseError::SanitizationViolation(
                "non_utf8_binary_payload",
            ));
        }
    };

    let lower = text.to_lowercase();

    // Check for secrets / private credentials / auth tokens / pins
    let forbidden_secret_markers = [
        "pin=",
        "password=",
        "secret=",
        "bearer ",
        "auth=",
        "token=",
        "passkey",
        "private_key",
    ];
    for marker in &forbidden_secret_markers {
        if lower.contains(marker) {
            return Err(SkyDrop1ParseError::SanitizationViolation(
                "forbidden_credential_detected",
            ));
        }
    }

    // Check for unredacted NMEA GPS coordinates (GPGGA, GPRMC, GNGGA sentences with actual coordinates)
    if (lower.contains("$gpgga") || lower.contains("$gprmc") || lower.contains("$gngga"))
        && (lower.contains(",n,")
            || lower.contains(",s,")
            || lower.contains(",e,")
            || lower.contains(",w,"))
    {
        return Err(SkyDrop1ParseError::SanitizationViolation(
            "unredacted_private_coordinates_detected",
        ));
    }

    Ok(())
}

/// Parses a raw SkyDrop 1 frame into a typed sensor sample according to verified protocol subset.
pub fn parse_skydrop1_frame(
    raw_frame: &SkyDrop1RawFrame,
    last_sequence: Option<u64>,
    core_processed_timestamp_ns: u64,
) -> Result<SkyDrop1ParsedSample, SkyDrop1ParseError> {
    if raw_frame.schema_version != SKYDROP1_PROTOCOL_SCHEMA_VERSION {
        return Err(SkyDrop1ParseError::UnsupportedSchemaVersion);
    }
    if raw_frame.native_received_timestamp_ns == 0 {
        return Err(SkyDrop1ParseError::NonPositiveReceiveTimestamp);
    }
    if raw_frame.raw_payload.is_empty() {
        return Err(SkyDrop1ParseError::EmptyFrame);
    }

    // Monotonic sequence check
    if let Some(prev_seq) = last_sequence
        && raw_frame.sequence <= prev_seq
    {
        return Err(SkyDrop1ParseError::NonMonotonicSequence);
    }

    // Sanitization check
    sanitize_skydrop_payload(&raw_frame.raw_payload)?;

    let text = std::str::from_utf8(&raw_frame.raw_payload)
        .map_err(|_| SkyDrop1ParseError::MalformedFraming("invalid_utf8"))?
        .trim();

    if !text.starts_with('$') {
        return Err(SkyDrop1ParseError::MalformedFraming(
            "missing_dollar_prefix",
        ));
    }

    let star_idx = text.rfind('*').ok_or(SkyDrop1ParseError::MalformedFraming(
        "missing_checksum_delimiter",
    ))?;

    let sentence_body = &text[1..star_idx];
    let checksum_str = &text[star_idx + 1..];

    if checksum_str.len() < 2 {
        return Err(SkyDrop1ParseError::MalformedFraming(
            "invalid_checksum_length",
        ));
    }

    let expected_checksum = u8::from_str_radix(&checksum_str[..2], 16)
        .map_err(|_| SkyDrop1ParseError::MalformedFraming("non_hex_checksum"))?;

    let calculated_checksum = calculate_nmea_checksum(sentence_body);
    if calculated_checksum != expected_checksum {
        return Err(SkyDrop1ParseError::ChecksumMismatch {
            expected: expected_checksum,
            calculated: calculated_checksum,
        });
    }

    let parts: Vec<&str> = sentence_body.split(',').collect();
    if parts.is_empty() {
        return Err(SkyDrop1ParseError::MalformedFraming("empty_sentence"));
    }

    match parts[0] {
        "LK8EX1" => parse_lk8ex1_sentence(&parts, raw_frame, core_processed_timestamp_ns),
        "PGRMZ" | "POV" | "DIGIFLY" => {
            // Documented unverified sentence types in SkyDrop scope are explicitly blocked
            Err(SkyDrop1ParseError::BlockedUnverifiedField(
                "unverified_sentence_syntax_in_v1_scope",
            ))
        }
        unknown => Err(SkyDrop1ParseError::UnrecognizedSentenceType(
            unknown.to_string(),
        )),
    }
}

fn parse_lk8ex1_sentence(
    parts: &[&str],
    raw_frame: &SkyDrop1RawFrame,
    core_processed_timestamp_ns: u64,
) -> Result<SkyDrop1ParsedSample, SkyDrop1ParseError> {
    // Standard format: LK8EX1,pressure,altitude,vario,temperature,battery
    // parts[0] = "LK8EX1"
    // parts[1] = raw pressure in Pa (e.g. 101325 or 999999 for invalid)
    // parts[2] = altitude in meters (e.g. 1500 or 99999 for invalid)
    // parts[3] = vario in cm/s (e.g. 150 = +1.5 m/s or 9999 for invalid)
    // parts[4] = temperature in C (e.g. 21 or 9999 for invalid)
    // parts[5] = battery percentage or mV (e.g. 98 or 999 for invalid)

    if parts.len() < 6 {
        return Err(SkyDrop1ParseError::MalformedFraming(
            "lk8ex1_insufficient_fields",
        ));
    }

    let pressure_hpa = parse_pressure_field(parts[1])?;
    let altitude_m = parse_altitude_field(parts[2])?;
    let vario_mps = parse_vario_field(parts[3])?;
    let temperature_c = parse_temperature_field(parts[4])?;
    let battery_percent = parse_battery_field(parts[5])?;

    Ok(SkyDrop1ParsedSample {
        schema_version: SKYDROP1_PROTOCOL_SCHEMA_VERSION,
        trace_id: raw_frame.trace_id,
        sequence: raw_frame.sequence,
        native_received_timestamp_ns: raw_frame.native_received_timestamp_ns,
        core_processed_timestamp_ns,
        pressure_hpa,
        altitude_m,
        vario_mps,
        temperature_c,
        battery_percent,
        quality_flags: SensorQualityFlags::nominal(),
    })
}

fn parse_pressure_field(raw: &str) -> Result<Option<f64>, SkyDrop1ParseError> {
    let trimmed = raw.trim();
    if trimmed.is_empty() || trimmed == "999999" {
        return Ok(None);
    }
    let val: f64 = trimmed
        .parse()
        .map_err(|_| SkyDrop1ParseError::InvalidFieldFormat("pressure_parse_failed"))?;

    // In LK8EX1, pressure can be in Pascals (e.g. 101325) or direct hPa (e.g. 1013.25)
    let hpa = if val > 10_000.0 { val / 100.0 } else { val };

    if !(300.0..=1200.0).contains(&hpa) || hpa.is_nan() {
        return Err(SkyDrop1ParseError::ValueOutOfBounds(
            "pressure_out_of_bounds",
        ));
    }

    Ok(Some(hpa))
}

fn parse_altitude_field(raw: &str) -> Result<Option<f64>, SkyDrop1ParseError> {
    let trimmed = raw.trim();
    if trimmed.is_empty() || trimmed == "99999" {
        return Ok(None);
    }
    let val: f64 = trimmed
        .parse()
        .map_err(|_| SkyDrop1ParseError::InvalidFieldFormat("altitude_parse_failed"))?;

    if !(-500.0..=15000.0).contains(&val) || val.is_nan() {
        return Err(SkyDrop1ParseError::ValueOutOfBounds(
            "altitude_out_of_bounds",
        ));
    }

    Ok(Some(val))
}

fn parse_vario_field(raw: &str) -> Result<Option<f64>, SkyDrop1ParseError> {
    let trimmed = raw.trim();
    if trimmed.is_empty() || trimmed == "9999" {
        return Ok(None);
    }
    let cm_per_s: f64 = trimmed
        .parse()
        .map_err(|_| SkyDrop1ParseError::InvalidFieldFormat("vario_parse_failed"))?;

    let mps = cm_per_s / 100.0;
    if !(-50.0..=50.0).contains(&mps) || mps.is_nan() {
        return Err(SkyDrop1ParseError::ValueOutOfBounds("vario_out_of_bounds"));
    }

    Ok(Some(mps))
}

fn parse_temperature_field(raw: &str) -> Result<Option<f64>, SkyDrop1ParseError> {
    let trimmed = raw.trim();
    if trimmed.is_empty() || trimmed == "9999" {
        return Ok(None);
    }
    let val: f64 = trimmed
        .parse()
        .map_err(|_| SkyDrop1ParseError::InvalidFieldFormat("temperature_parse_failed"))?;

    if !(-50.0..=85.0).contains(&val) || val.is_nan() {
        return Err(SkyDrop1ParseError::ValueOutOfBounds(
            "temperature_out_of_bounds",
        ));
    }

    Ok(Some(val))
}

fn parse_battery_field(raw: &str) -> Result<Option<f64>, SkyDrop1ParseError> {
    let trimmed = raw.trim();
    if trimmed.is_empty() || trimmed == "999" {
        return Ok(None);
    }
    let val: f64 = trimmed
        .parse()
        .map_err(|_| SkyDrop1ParseError::InvalidFieldFormat("battery_parse_failed"))?;

    // Value may be percentage (0-100) or battery voltage in mV (3000 - 4300)
    let percent = if val > 1000.0 {
        // Linear approximation from 3.4V (0%) to 4.2V (100%)
        let clamped = val.clamp(3400.0, 4200.0);
        ((clamped - 3400.0) / 800.0) * 100.0
    } else {
        val
    };

    if !(0.0..=100.0).contains(&percent) || percent.is_nan() {
        return Err(SkyDrop1ParseError::ValueOutOfBounds(
            "battery_out_of_bounds",
        ));
    }

    Ok(Some(percent))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn authoritative_support_record_classifies_platforms_correctly() {
        let record = SkyDrop1PlatformSupportRecord::authoritative();
        assert_eq!(record.schema_version, 1);
        assert_eq!(record.android_status, PlatformSupportStatus::Supported);
        assert_eq!(record.ios_status, PlatformSupportStatus::Unsupported);
        assert_eq!(record.verification_date, "2026-08-25");
        assert!(record.ios_evidence.contains("Apple MFi"));
    }

    #[test]
    fn parses_valid_lk8ex1_sentence() {
        // "$LK8EX1,101325,1500,150,21,95*3B"
        let body = "LK8EX1,101325,1500,150,21,95";
        let csum = calculate_nmea_checksum(body);
        let frame_text = format!("${}*{:02X}\r\n", body, csum);

        let raw = SkyDrop1RawFrame {
            schema_version: 1,
            trace_id: 1001,
            sequence: 1,
            native_received_timestamp_ns: 1_000_000_000,
            raw_payload: frame_text.into_bytes(),
        };

        let sample = parse_skydrop1_frame(&raw, None, 1_000_500_000).expect("should parse");
        assert_eq!(sample.trace_id, 1001);
        assert_eq!(sample.sequence, 1);
        assert_eq!(sample.pressure_hpa, Some(1013.25));
        assert_eq!(sample.altitude_m, Some(1500.0));
        assert_eq!(sample.vario_mps, Some(1.50));
        assert_eq!(sample.temperature_c, Some(21.0));
        assert_eq!(sample.battery_percent, Some(95.0));
    }

    #[test]
    fn handles_lk8ex1_sentinel_empty_fields() {
        let body = "LK8EX1,999999,99999,9999,9999,999";
        let csum = calculate_nmea_checksum(body);
        let frame_text = format!("${}*{:02X}", body, csum);

        let raw = SkyDrop1RawFrame {
            schema_version: 1,
            trace_id: 1002,
            sequence: 2,
            native_received_timestamp_ns: 1_000_000_000,
            raw_payload: frame_text.into_bytes(),
        };

        let sample =
            parse_skydrop1_frame(&raw, Some(1), 1_000_500_000).expect("should parse sentinels");
        assert_eq!(sample.pressure_hpa, None);
        assert_eq!(sample.altitude_m, None);
        assert_eq!(sample.vario_mps, None);
        assert_eq!(sample.temperature_c, None);
        assert_eq!(sample.battery_percent, None);
    }

    #[test]
    fn rejects_checksum_mismatch() {
        let raw = SkyDrop1RawFrame {
            schema_version: 1,
            trace_id: 1003,
            sequence: 3,
            native_received_timestamp_ns: 1_000_000_000,
            raw_payload: b"$LK8EX1,101325,1500,150,21,95*00".to_vec(),
        };

        match parse_skydrop1_frame(&raw, Some(2), 1_000_500_000) {
            Err(SkyDrop1ParseError::ChecksumMismatch { .. }) => (),
            other => panic!("expected ChecksumMismatch, got {:?}", other),
        }
    }

    #[test]
    fn blocks_unverified_sentence_types() {
        let body = "PGRMZ,1500,m,3";
        let csum = calculate_nmea_checksum(body);
        let frame_text = format!("${}*{:02X}", body, csum);

        let raw = SkyDrop1RawFrame {
            schema_version: 1,
            trace_id: 1004,
            sequence: 4,
            native_received_timestamp_ns: 1_000_000_000,
            raw_payload: frame_text.into_bytes(),
        };

        assert_eq!(
            parse_skydrop1_frame(&raw, Some(3), 1_000_500_000),
            Err(SkyDrop1ParseError::BlockedUnverifiedField(
                "unverified_sentence_syntax_in_v1_scope"
            ))
        );
    }

    #[test]
    fn sanitization_rejects_credentials_and_unsanitized_gps() {
        // Credentials test
        let creds_frame = b"$LK8EX1,101325,pin=1234*00";
        assert!(sanitize_skydrop_payload(creds_frame).is_err());

        // Unsanitized coordinates test
        let gps_frame = b"$GPGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,46.9,M,,*47";
        assert!(sanitize_skydrop_payload(gps_frame).is_err());

        // Clean frame
        let clean_frame = b"$LK8EX1,101325,1500,150,21,95*3B";
        assert!(sanitize_skydrop_payload(clean_frame).is_ok());
    }

    #[test]
    fn rejects_non_monotonic_sequence() {
        let body = "LK8EX1,101325,1500,150,21,95";
        let csum = calculate_nmea_checksum(body);
        let frame_text = format!("${}*{:02X}", body, csum);

        let raw = SkyDrop1RawFrame {
            schema_version: 1,
            trace_id: 1005,
            sequence: 4,
            native_received_timestamp_ns: 1_000_000_000,
            raw_payload: frame_text.into_bytes(),
        };

        assert_eq!(
            parse_skydrop1_frame(&raw, Some(5), 1_000_500_000),
            Err(SkyDrop1ParseError::NonMonotonicSequence)
        );
    }

    #[test]
    fn validation_report_generates_correct_latencies_and_gates() {
        let counters = SkyDrop1IntegrityCounters {
            total_frames_received: 1800,
            valid_samples_parsed: 1800,
            reconnect_success_count: 1,
            ..Default::default()
        };

        let samples = vec![1.2, 2.5, 4.0, 5.5, 12.0];
        let report = SkyDrop1ValidationReport::new(
            30.0,
            "Pixel 7 (Android 14)".to_string(),
            "Android 14".to_string(),
            "SkyDrop v1.4.3".to_string(),
            20.0,
            counters,
            samples,
            true,
        );

        assert!(report.latency_gate_passed);
        assert!(report.reconnect_without_restart_passed);
        assert_eq!(
            report.platform_matrix.android_status,
            PlatformSupportStatus::Supported
        );
        assert_eq!(
            report.platform_matrix.ios_status,
            PlatformSupportStatus::Unsupported
        );
    }

    #[test]
    fn committed_replay_fixture_is_valid_and_sanitized() {
        let fixture_bytes = include_bytes!("../fixtures/skydrop1_replay_fixture.json");
        let fixture_str = std::str::from_utf8(fixture_bytes).expect("valid utf-8 fixture");
        assert!(fixture_str.contains("skydrop1-replay-v1"));

        // Verify that the fixture contains no credentials or raw coordinate markers
        assert!(sanitize_skydrop_payload(fixture_bytes).is_ok());

        // Parse individual test lines
        let body1 = "LK8EX1,101325,1250,120,21,95";
        let csum1 = calculate_nmea_checksum(body1);
        let frame1_text = format!("${}*{:02X}\r\n", body1, csum1);
        let frame1 = SkyDrop1RawFrame {
            schema_version: SKYDROP1_PROTOCOL_SCHEMA_VERSION,
            trace_id: 1001,
            sequence: 1,
            native_received_timestamp_ns: 1_000_000_000,
            raw_payload: frame1_text.into_bytes(),
        };
        let sample1 =
            parse_skydrop1_frame(&frame1, None, 1_000_200_000).expect("frame 1 should parse");
        assert_eq!(sample1.pressure_hpa, Some(1013.25));
        assert_eq!(sample1.altitude_m, Some(1250.0));
        assert_eq!(sample1.vario_mps, Some(1.20));

        // Frame 3 sentinels
        let body3 = "LK8EX1,999999,99999,9999,9999,999";
        let csum3 = calculate_nmea_checksum(body3);
        let frame3_text = format!("${}*{:02X}\r\n", body3, csum3);
        let frame3 = SkyDrop1RawFrame {
            schema_version: SKYDROP1_PROTOCOL_SCHEMA_VERSION,
            trace_id: 1003,
            sequence: 3,
            native_received_timestamp_ns: 1_100_000_000,
            raw_payload: frame3_text.into_bytes(),
        };
        let sample3 = parse_skydrop1_frame(&frame3, Some(2), 1_100_200_000)
            .expect("frame 3 should parse sentinels");
        assert_eq!(sample3.pressure_hpa, None);
        assert_eq!(sample3.altitude_m, None);

        // Frame 5 checksum mismatch
        let frame5_text = "$LK8EX1,101250,1260,200,22,94*99\r\n";
        let frame5 = SkyDrop1RawFrame {
            schema_version: SKYDROP1_PROTOCOL_SCHEMA_VERSION,
            trace_id: 1005,
            sequence: 5,
            native_received_timestamp_ns: 1_200_000_000,
            raw_payload: frame5_text.as_bytes().to_vec(),
        };
        assert!(matches!(
            parse_skydrop1_frame(&frame5, Some(4), 1_200_200_000),
            Err(SkyDrop1ParseError::ChecksumMismatch { .. })
        ));

        // Frame 7 blocked unverified
        let body7 = "PGRMZ,1265,m,3";
        let csum7 = calculate_nmea_checksum(body7);
        let frame7_text = format!("${}*{:02X}\r\n", body7, csum7);
        let frame7 = SkyDrop1RawFrame {
            schema_version: SKYDROP1_PROTOCOL_SCHEMA_VERSION,
            trace_id: 1007,
            sequence: 7,
            native_received_timestamp_ns: 1_300_000_000,
            raw_payload: frame7_text.into_bytes(),
        };
        assert!(matches!(
            parse_skydrop1_frame(&frame7, Some(6), 1_300_200_000),
            Err(SkyDrop1ParseError::BlockedUnverifiedField(_))
        ));
    }

    #[test]
    fn calculate_nmea_checksum_works_for_various_inputs() {
        // Test empty payload
        assert_eq!(calculate_nmea_checksum(""), 0);

        // Test single character ASCII 'A' (ASCII value 65 / 0x41)
        assert_eq!(calculate_nmea_checksum("A"), 0x41);

        // Test double characters canceling out: 'A' ^ 'A' == 0
        assert_eq!(calculate_nmea_checksum("AA"), 0);

        // Test XOR combination: 'A' (0x41) ^ 'B' (0x42) = 0x03
        assert_eq!(calculate_nmea_checksum("AB"), 0x03);

        // Test standard LK8EX1 sentence payload
        assert_eq!(
            calculate_nmea_checksum("LK8EX1,101325,1500,150,21,95"),
            0x04
        );

        // Test standard GPGGA sentence payload
        assert_eq!(
            calculate_nmea_checksum(
                "GPGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,46.9,M,,"
            ),
            0x47
        );
    }

    #[test]
    fn sanitize_rejects_non_utf8_binary_payload() {
        let invalid_utf8 = &[0xFF, 0xFE, 0xFD];
        assert_eq!(
            sanitize_skydrop_payload(invalid_utf8),
            Err(SkyDrop1ParseError::SanitizationViolation(
                "non_utf8_binary_payload"
            ))
        );
    }

    #[test]
    fn sanitize_rejects_forbidden_secret_markers() {
        let markers = [
            "pin=",
            "password=",
            "secret=",
            "bearer ",
            "auth=",
            "token=",
            "passkey",
            "private_key",
        ];

        for marker in &markers {
            let payload = format!("$LK8EX1,101325,{:*^10}*00", marker.to_uppercase());
            assert_eq!(
                sanitize_skydrop_payload(payload.as_bytes()),
                Err(SkyDrop1ParseError::SanitizationViolation(
                    "forbidden_credential_detected"
                )),
                "failed to reject marker: {}",
                marker
            );
        }
    }

    #[test]
    fn sanitize_rejects_unredacted_gps_coordinates() {
        let sentences = ["$GPGGA", "$GPRMC", "$GNGGA"];
        let directions = [",N,", ",S,", ",E,", ",W,"];

        for sentence in &sentences {
            for dir in &directions {
                let payload = format!("{},123519,4807.038{}01131.000*00", sentence, dir);
                assert_eq!(
                    sanitize_skydrop_payload(payload.as_bytes()),
                    Err(SkyDrop1ParseError::SanitizationViolation(
                        "unredacted_private_coordinates_detected"
                    )),
                    "failed to reject sentence {} with direction {}",
                    sentence,
                    dir
                );

                // Lowercase check
                let lower_payload = payload.to_lowercase();
                assert_eq!(
                    sanitize_skydrop_payload(lower_payload.as_bytes()),
                    Err(SkyDrop1ParseError::SanitizationViolation(
                        "unredacted_private_coordinates_detected"
                    ))
                );
            }
        }
    }

    #[test]
    fn sanitize_accepts_valid_and_redacted_payloads() {
        // Empty payload
        assert_eq!(sanitize_skydrop_payload(b""), Ok(()));

        // Nominal LK8EX1 sentence
        assert_eq!(
            sanitize_skydrop_payload(b"$LK8EX1,101325,1500,150,21,95*3B"),
            Ok(())
        );

        // NMEA sentence without coordinate direction markers (redacted/anonymized)
        assert_eq!(
            sanitize_skydrop_payload(
                b"$GPGGA,123519,REDACTED,REDACTED,1,08,0.9,545.4,M,46.9,M,,*47"
            ),
            Ok(())
        );
    }
}
