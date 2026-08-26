#![forbid(unsafe_code)]

mod data_source_governance;
mod native_flight_pipeline;
mod skydrop1_protocol;

pub use data_source_governance::{
    DataPackageManifest, DataPackageManifestInput, DataPackageManifestValidationError,
    DataSourceCategory, EvidenceRecord, GovernanceDecision, GovernanceDecisionState,
    LicenceConstraints, OperationalConstraints, PrivacyConstraints, ProviderDatasetRecord,
    ProviderDatasetRecordInput, ProviderDatasetRecordValidationError, ReviewRecord,
    audited_provider_inventory, check_category_coverage, fixtures,
};

pub use native_flight_pipeline::{
    BenchmarkResult, EventRejectionReason, LatencySummary, MAX_ALLOWED_AUDIO_P95_LATENCY_MS,
    MAX_ALLOWED_CORE_P95_LATENCY_MS, MAX_ALLOWED_KPI_P95_LATENCY_MS,
    NATIVE_PIPELINE_SCHEMA_VERSION, PipelineCounters, RejectionReasonCounters, SensorEvent,
    SensorPayload, SensorQualityFlags, SensorSourceId, StageTimestampTrace, validate_sensor_event,
};

pub use skydrop1_protocol::{
    PlatformSupportStatus, SKYDROP1_BT_SPP_UUID, SKYDROP1_PROTOCOL_SCHEMA_VERSION,
    SKYDROP1_VERIFICATION_DATE, SKYDROP1_VERIFIED_FIRMWARE_SCOPE, SkyDrop1IntegrityCounters,
    SkyDrop1ParseError, SkyDrop1ParsedSample, SkyDrop1PlatformSupportRecord, SkyDrop1RawFrame,
    SkyDrop1StageTrace, SkyDrop1TransportEvent, SkyDrop1ValidationReport, calculate_nmea_checksum,
    parse_skydrop1_frame, sanitize_skydrop_payload,
};
