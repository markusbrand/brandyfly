#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash)]
pub enum DataSourceCategory {
    BaseMap,
    Elevation,
    Airspace,
    Geocoding,
    LivePilot,
    Thermal,
}

impl DataSourceCategory {
    pub const ALL: [DataSourceCategory; 6] = [
        DataSourceCategory::BaseMap,
        DataSourceCategory::Elevation,
        DataSourceCategory::Airspace,
        DataSourceCategory::Geocoding,
        DataSourceCategory::LivePilot,
        DataSourceCategory::Thermal,
    ];

    pub fn display_name(&self) -> &'static str {
        match self {
            Self::BaseMap => "Base Map",
            Self::Elevation => "Elevation",
            Self::Airspace => "Airspace",
            Self::Geocoding => "Geocoding",
            Self::LivePilot => "Live Pilot",
            Self::Thermal => "Thermal",
        }
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum GovernanceDecisionState {
    Approved,
    Rejected,
    Blocked,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct EvidenceRecord {
    pub terms_url: Option<String>,
    pub written_permission_reference: Option<String>,
    pub evidence_date: String,
    pub reviewer: String,
    pub evidence_notes: Vec<String>,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct GovernanceDecision {
    pub state: GovernanceDecisionState,
    pub rationale: String,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct ReviewRecord {
    pub reviewed_at: String,
    pub revalidation_at: String,
    pub reviewer: String,
    pub notes: Vec<String>,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct LicenceConstraints {
    pub license_identifier_or_terms_url: String,
    pub attribution_text: String,
    pub attribution_url: Option<String>,
    pub redistribution: String,
    pub caching: String,
    pub derivation: String,
    pub review_expiry: String,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct PrivacyConstraints {
    pub contains_personal_data: bool,
    pub legal_basis: Option<String>,
    pub consent_expectations: Option<String>,
    pub retention: String,
    pub deletion: String,
    pub onward_sharing_limits: String,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct OperationalConstraints {
    pub update_cadence: String,
    pub caching_policy: String,
    pub rate_limit: Option<String>,
    pub availability_notes: String,
    pub incident_response: String,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct ProviderDatasetRecord {
    pub schema_version: u16,
    pub provider_id: String,
    pub dataset_id: String,
    pub dataset_name: String,
    pub category: DataSourceCategory,
    pub evidence: EvidenceRecord,
    pub decision: GovernanceDecision,
    pub review: ReviewRecord,
    pub licence: LicenceConstraints,
    pub privacy: PrivacyConstraints,
    pub operational: OperationalConstraints,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct ProviderDatasetRecordInput {
    pub provider_id: String,
    pub dataset_id: String,
    pub dataset_name: String,
    pub category: DataSourceCategory,
    pub evidence: EvidenceRecord,
    pub decision: GovernanceDecision,
    pub review: ReviewRecord,
    pub licence: LicenceConstraints,
    pub privacy: PrivacyConstraints,
    pub operational: OperationalConstraints,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum ProviderDatasetRecordValidationError {
    UnsupportedSchemaVersion {
        expected: u16,
        found: u16,
    },
    MissingField {
        field: &'static str,
    },
    MissingAuthoritativeEvidence {
        field: &'static str,
    },
    ReviewExpired {
        expired_at: String,
        current_date: String,
    },
    MissingPersonalDataGovernance {
        field: &'static str,
    },
}

impl ProviderDatasetRecord {
    pub const SCHEMA_VERSION: u16 = 1;

    pub fn new(input: ProviderDatasetRecordInput) -> Self {
        Self {
            schema_version: Self::SCHEMA_VERSION,
            provider_id: input.provider_id,
            dataset_id: input.dataset_id,
            dataset_name: input.dataset_name,
            category: input.category,
            evidence: input.evidence,
            decision: input.decision,
            review: input.review,
            licence: input.licence,
            privacy: input.privacy,
            operational: input.operational,
        }
    }

    pub fn validate(&self) -> Result<(), ProviderDatasetRecordValidationError> {
        if self.schema_version != Self::SCHEMA_VERSION {
            return Err(
                ProviderDatasetRecordValidationError::UnsupportedSchemaVersion {
                    expected: Self::SCHEMA_VERSION,
                    found: self.schema_version,
                },
            );
        }

        self.ensure_non_empty("provider_id", &self.provider_id)?;
        self.ensure_non_empty("dataset_id", &self.dataset_id)?;
        self.ensure_non_empty("dataset_name", &self.dataset_name)?;
        self.ensure_non_empty("evidence.evidence_date", &self.evidence.evidence_date)?;
        self.ensure_non_empty("evidence.reviewer", &self.evidence.reviewer)?;
        self.ensure_non_empty("decision.rationale", &self.decision.rationale)?;
        self.ensure_non_empty("review.reviewed_at", &self.review.reviewed_at)?;
        self.ensure_non_empty("review.revalidation_at", &self.review.revalidation_at)?;
        self.ensure_non_empty("review.reviewer", &self.review.reviewer)?;
        self.ensure_non_empty(
            "licence.license_identifier_or_terms_url",
            &self.licence.license_identifier_or_terms_url,
        )?;
        self.ensure_non_empty("licence.attribution_text", &self.licence.attribution_text)?;
        self.ensure_non_empty("licence.redistribution", &self.licence.redistribution)?;
        self.ensure_non_empty("licence.caching", &self.licence.caching)?;
        self.ensure_non_empty("licence.derivation", &self.licence.derivation)?;
        self.ensure_non_empty("licence.review_expiry", &self.licence.review_expiry)?;
        self.ensure_non_empty("privacy.retention", &self.privacy.retention)?;
        self.ensure_non_empty("privacy.deletion", &self.privacy.deletion)?;
        self.ensure_non_empty(
            "privacy.onward_sharing_limits",
            &self.privacy.onward_sharing_limits,
        )?;
        self.ensure_non_empty(
            "operational.update_cadence",
            &self.operational.update_cadence,
        )?;
        self.ensure_non_empty(
            "operational.caching_policy",
            &self.operational.caching_policy,
        )?;
        self.ensure_non_empty(
            "operational.availability_notes",
            &self.operational.availability_notes,
        )?;
        self.ensure_non_empty(
            "operational.incident_response",
            &self.operational.incident_response,
        )?;

        if self.decision.state == GovernanceDecisionState::Approved
            && self.evidence.terms_url.is_none()
            && self.evidence.written_permission_reference.is_none()
        {
            return Err(
                ProviderDatasetRecordValidationError::MissingAuthoritativeEvidence {
                    field: "evidence.terms_url or evidence.written_permission_reference",
                },
            );
        }

        if self.decision.state == GovernanceDecisionState::Approved
            && self.privacy.contains_personal_data
        {
            if self
                .privacy
                .legal_basis
                .as_ref()
                .is_none_or(|s| s.trim().is_empty())
            {
                return Err(
                    ProviderDatasetRecordValidationError::MissingPersonalDataGovernance {
                        field: "privacy.legal_basis",
                    },
                );
            }
            if self
                .privacy
                .consent_expectations
                .as_ref()
                .is_none_or(|s| s.trim().is_empty())
            {
                return Err(
                    ProviderDatasetRecordValidationError::MissingPersonalDataGovernance {
                        field: "privacy.consent_expectations",
                    },
                );
            }
        }

        Ok(())
    }

    pub fn is_review_expired(&self, current_date_ymd: &str) -> bool {
        self.review.revalidation_at.as_str() < current_date_ymd
            || self.licence.review_expiry.as_str() < current_date_ymd
    }

    pub fn validate_with_date(
        &self,
        current_date_ymd: &str,
    ) -> Result<(), ProviderDatasetRecordValidationError> {
        self.validate()?;
        if self.decision.state == GovernanceDecisionState::Approved
            && self.is_review_expired(current_date_ymd)
        {
            let earliest_expiry = if self.review.revalidation_at <= self.licence.review_expiry {
                &self.review.revalidation_at
            } else {
                &self.licence.review_expiry
            };
            return Err(ProviderDatasetRecordValidationError::ReviewExpired {
                expired_at: earliest_expiry.clone(),
                current_date: current_date_ymd.to_string(),
            });
        }
        Ok(())
    }

    fn ensure_non_empty(
        &self,
        field: &'static str,
        value: &str,
    ) -> Result<(), ProviderDatasetRecordValidationError> {
        if value.trim().is_empty() {
            Err(ProviderDatasetRecordValidationError::MissingField { field })
        } else {
            Ok(())
        }
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct DataPackageManifest {
    pub schema_version: u16,
    pub dataset_identifier: String,
    pub provider: String,
    pub source_version_or_date: String,
    pub build_time: String,
    pub license_identifier_or_terms_url: String,
    pub attribution_text: String,
    pub attribution_url: Option<String>,
    pub geographic_coverage: String,
    pub checksum: String,
    pub review_expiry: String,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct DataPackageManifestInput {
    pub dataset_identifier: String,
    pub provider: String,
    pub source_version_or_date: String,
    pub build_time: String,
    pub license_identifier_or_terms_url: String,
    pub attribution_text: String,
    pub attribution_url: Option<String>,
    pub geographic_coverage: String,
    pub checksum: String,
    pub review_expiry: String,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum DataPackageManifestValidationError {
    UnsupportedSchemaVersion {
        expected: u16,
        found: u16,
    },
    MissingField {
        field: &'static str,
    },
    ExpiredReview {
        expiry: String,
        current_date: String,
    },
}

impl DataPackageManifest {
    pub const SCHEMA_VERSION: u16 = 1;

    pub fn new(input: DataPackageManifestInput) -> Self {
        Self {
            schema_version: Self::SCHEMA_VERSION,
            dataset_identifier: input.dataset_identifier,
            provider: input.provider,
            source_version_or_date: input.source_version_or_date,
            build_time: input.build_time,
            license_identifier_or_terms_url: input.license_identifier_or_terms_url,
            attribution_text: input.attribution_text,
            attribution_url: input.attribution_url,
            geographic_coverage: input.geographic_coverage,
            checksum: input.checksum,
            review_expiry: input.review_expiry,
        }
    }

    pub fn validate(&self) -> Result<(), DataPackageManifestValidationError> {
        if self.schema_version != Self::SCHEMA_VERSION {
            return Err(
                DataPackageManifestValidationError::UnsupportedSchemaVersion {
                    expected: Self::SCHEMA_VERSION,
                    found: self.schema_version,
                },
            );
        }

        self.ensure_non_empty("dataset_identifier", &self.dataset_identifier)?;
        self.ensure_non_empty("provider", &self.provider)?;
        self.ensure_non_empty("source_version_or_date", &self.source_version_or_date)?;
        self.ensure_non_empty("build_time", &self.build_time)?;
        self.ensure_non_empty(
            "license_identifier_or_terms_url",
            &self.license_identifier_or_terms_url,
        )?;
        self.ensure_non_empty("attribution_text", &self.attribution_text)?;
        self.ensure_non_empty("geographic_coverage", &self.geographic_coverage)?;
        self.ensure_non_empty("checksum", &self.checksum)?;
        self.ensure_non_empty("review_expiry", &self.review_expiry)?;

        Ok(())
    }

    pub fn validate_with_date(
        &self,
        current_date_ymd: &str,
    ) -> Result<(), DataPackageManifestValidationError> {
        self.validate()?;
        if self.review_expiry.as_str() < current_date_ymd {
            return Err(DataPackageManifestValidationError::ExpiredReview {
                expiry: self.review_expiry.clone(),
                current_date: current_date_ymd.to_string(),
            });
        }
        Ok(())
    }

    fn ensure_non_empty(
        &self,
        field: &'static str,
        value: &str,
    ) -> Result<(), DataPackageManifestValidationError> {
        if value.trim().is_empty() {
            Err(DataPackageManifestValidationError::MissingField { field })
        } else {
            Ok(())
        }
    }
}

pub fn check_category_coverage(
    records: &[ProviderDatasetRecord],
) -> Result<(), Vec<DataSourceCategory>> {
    let mut missing = Vec::new();
    for category in DataSourceCategory::ALL {
        let has_approved = records.iter().any(|r| {
            r.category == category && r.decision.state == GovernanceDecisionState::Approved
        });
        if !has_approved {
            missing.push(category);
        }
    }

    if missing.is_empty() {
        Ok(())
    } else {
        Err(missing)
    }
}

pub fn audited_provider_inventory() -> Vec<ProviderDatasetRecord> {
    vec![
        // 1. Base Map Extracts
        ProviderDatasetRecord::new(ProviderDatasetRecordInput {
            provider_id: "osm-geofabrik".to_string(),
            dataset_id: "osm-regional-vector-extracts".to_string(),
            dataset_name: "OpenStreetMap Regional Extracts (Geofabrik)".to_string(),
            category: DataSourceCategory::BaseMap,
            evidence: EvidenceRecord {
                terms_url: Some("https://www.openstreetmap.org/copyright".to_string()),
                written_permission_reference: None,
                evidence_date: "2026-08-07".to_string(),
                reviewer: "markusbrand".to_string(),
                evidence_notes: vec![
                    "Open Database License (ODbL) 1.0 reviewed".to_string(),
                    "Planetiler PMTiles vector tile derivation produces Produced Work with attribution".to_string(),
                ],
            },
            decision: GovernanceDecision {
                state: GovernanceDecisionState::Approved,
                rationale: "ODbL permits extraction, transformation to PMTiles, and offline redistribution with attribution.".to_string(),
            },
            review: ReviewRecord {
                reviewed_at: "2026-08-07".to_string(),
                revalidation_at: "2027-08-07".to_string(),
                reviewer: "markusbrand".to_string(),
                notes: vec!["Review annually for changes to OSM or Geofabrik redistribution terms.".to_string()],
            },
            licence: LicenceConstraints {
                license_identifier_or_terms_url: "ODbL-1.0 (https://www.openstreetmap.org/copyright)".to_string(),
                attribution_text: "© OpenStreetMap contributors".to_string(),
                attribution_url: Some("https://www.openstreetmap.org/copyright".to_string()),
                redistribution: "Permitted for offline package distribution with ODbL attribution notice.".to_string(),
                caching: "Permanent offline caching permitted.".to_string(),
                derivation: "Permitted. Derived vector tiles require attribution.".to_string(),
                review_expiry: "2027-08-07".to_string(),
            },
            privacy: PrivacyConstraints {
                contains_personal_data: false,
                legal_basis: None,
                consent_expectations: None,
                retention: "No personal data.".to_string(),
                deletion: "Not applicable.".to_string(),
                onward_sharing_limits: "Standard open source attribution.".to_string(),
            },
            operational: OperationalConstraints {
                update_cadence: "Weekly / Monthly snapshot builds.".to_string(),
                caching_policy: "Bundled into downloadable region PMTiles packages.".to_string(),
                rate_limit: None,
                availability_notes: "Geofabrik download server with OSM planet mirrors as backup.".to_string(),
                incident_response: "Halt new package generation if mirror corrupted; existing offline packages remain valid with source date.".to_string(),
            },
        }),
        ProviderDatasetRecord::new(ProviderDatasetRecordInput {
            provider_id: "commercial-tile-scraper".to_string(),
            dataset_id: "commercial-raster-tiles".to_string(),
            dataset_name: "Commercial Tile Scraping Candidate".to_string(),
            category: DataSourceCategory::BaseMap,
            evidence: EvidenceRecord {
                terms_url: None,
                written_permission_reference: None,
                evidence_date: "2026-08-07".to_string(),
                reviewer: "markusbrand".to_string(),
                evidence_notes: vec!["Evaluated proprietary commercial raster tile services without enterprise redistribution license.".to_string()],
            },
            decision: GovernanceDecision {
                state: GovernanceDecisionState::Rejected,
                rationale: "Commercial web tile terms prohibit offline scraping, local storage, and non-licensed redistribution.".to_string(),
            },
            review: ReviewRecord {
                reviewed_at: "2026-08-07".to_string(),
                revalidation_at: "2027-08-07".to_string(),
                reviewer: "markusbrand".to_string(),
                notes: vec!["Permanent rejection of unlicensed commercial scraping.".to_string()],
            },
            licence: LicenceConstraints {
                license_identifier_or_terms_url: "PROPRIETARY-UNLICENSED".to_string(),
                attribution_text: "N/A".to_string(),
                attribution_url: None,
                redistribution: "Prohibited.".to_string(),
                caching: "Prohibited.".to_string(),
                derivation: "Prohibited.".to_string(),
                review_expiry: "2027-08-07".to_string(),
            },
            privacy: PrivacyConstraints {
                contains_personal_data: false,
                legal_basis: None,
                consent_expectations: None,
                retention: "N/A".to_string(),
                deletion: "N/A".to_string(),
                onward_sharing_limits: "N/A".to_string(),
            },
            operational: OperationalConstraints {
                update_cadence: "N/A".to_string(),
                caching_policy: "Prohibited.".to_string(),
                rate_limit: None,
                availability_notes: "N/A".to_string(),
                incident_response: "Do not implement.".to_string(),
            },
        }),

        // 2. Elevation / Contours / Hillshade
        ProviderDatasetRecord::new(ProviderDatasetRecordInput {
            provider_id: "copernicus-dem".to_string(),
            dataset_id: "copernicus-dem-glo-30".to_string(),
            dataset_name: "Copernicus Digital Elevation Model (GLO-30)".to_string(),
            category: DataSourceCategory::Elevation,
            evidence: EvidenceRecord {
                terms_url: Some("https://spacedata.copernicus.eu/collections/copernicus-digital-elevation-model".to_string()),
                written_permission_reference: None,
                evidence_date: "2026-08-07".to_string(),
                reviewer: "markusbrand".to_string(),
                evidence_notes: vec![
                    "Copernicus full, free and open data policy reviewed".to_string(),
                    "Permits worldwide derivative generation for hillshade, elevation contours, and terrain RGB tiles".to_string(),
                ],
            },
            decision: GovernanceDecision {
                state: GovernanceDecisionState::Approved,
                rationale: "Copernicus open licence permits processing, offline package derivation, and redistribution with attribution.".to_string(),
            },
            review: ReviewRecord {
                reviewed_at: "2026-08-07".to_string(),
                revalidation_at: "2027-08-07".to_string(),
                reviewer: "markusbrand".to_string(),
                notes: vec!["Annual check for European Space Agency policy updates.".to_string()],
            },
            licence: LicenceConstraints {
                license_identifier_or_terms_url: "CC-BY-4.0 / Copernicus-Open-Access (https://spacedata.copernicus.eu/)".to_string(),
                attribution_text: "© European Space Agency (ESA) Copernicus DEM (2021)".to_string(),
                attribution_url: Some("https://spacedata.copernicus.eu/".to_string()),
                redistribution: "Permitted in derived terrain raster/vector packages.".to_string(),
                caching: "Permanent offline caching permitted.".to_string(),
                derivation: "Permitted for contour lines, elevation queries, and terrain hillshade.".to_string(),
                review_expiry: "2027-08-07".to_string(),
            },
            privacy: PrivacyConstraints {
                contains_personal_data: false,
                legal_basis: None,
                consent_expectations: None,
                retention: "No personal data.".to_string(),
                deletion: "Not applicable.".to_string(),
                onward_sharing_limits: "Standard attribution.".to_string(),
            },
            operational: OperationalConstraints {
                update_cadence: "Static base dataset; periodic revisions by ESA.".to_string(),
                caching_policy: "Pre-rendered into offline package terrain tiles.".to_string(),
                rate_limit: None,
                availability_notes: "High reliability AWS / Copernicus Open Access Hub.".to_string(),
                incident_response: "Fallback to SRTM 30m if Copernicus tiles unavailable.".to_string(),
            },
        }),

        // 3. Airspace
        ProviderDatasetRecord::new(ProviderDatasetRecordInput {
            provider_id: "open-flightmaps".to_string(),
            dataset_id: "open-flightmaps-aixm".to_string(),
            dataset_name: "open flightmaps (OFM) Aeronautical Data".to_string(),
            category: DataSourceCategory::Airspace,
            evidence: EvidenceRecord {
                terms_url: Some("https://www.openflightmaps.org/terms-and-conditions/".to_string()),
                written_permission_reference: None,
                evidence_date: "2026-08-07".to_string(),
                reviewer: "markusbrand".to_string(),
                evidence_notes: vec![
                    "OFM open aeronautical data licence and AIRAC cycle publication terms reviewed".to_string(),
                    "Airspace data licensed under CC BY-NC-SA 4.0 for non-commercial flight preparation".to_string(),
                ],
            },
            decision: GovernanceDecision {
                state: GovernanceDecisionState::Approved,
                rationale: "OFM provides structured AIXM/GeoJSON airspace data with explicit non-commercial redistribution rights.".to_string(),
            },
            review: ReviewRecord {
                reviewed_at: "2026-08-07".to_string(),
                revalidation_at: "2027-08-07".to_string(),
                reviewer: "markusbrand".to_string(),
                notes: vec!["Enforce 28-day AIRAC validity checking in package metadata.".to_string()],
            },
            licence: LicenceConstraints {
                license_identifier_or_terms_url: "CC-BY-NC-SA-4.0 (https://www.openflightmaps.org/terms-and-conditions/)".to_string(),
                attribution_text: "Airspace data © open flightmaps contributors".to_string(),
                attribution_url: Some("https://www.openflightmaps.org/".to_string()),
                redistribution: "Permitted for non-commercial flight safety and offline packages.".to_string(),
                caching: "Offline caching permitted with AIRAC cycle timestamp.".to_string(),
                derivation: "Permitted with Share-Alike.".to_string(),
                review_expiry: "2027-08-07".to_string(),
            },
            privacy: PrivacyConstraints {
                contains_personal_data: false,
                legal_basis: None,
                consent_expectations: None,
                retention: "No personal data.".to_string(),
                deletion: "Not applicable.".to_string(),
                onward_sharing_limits: "Standard CC BY-NC-SA terms.".to_string(),
            },
            operational: OperationalConstraints {
                update_cadence: "28-day ICAO AIRAC cycle.".to_string(),
                caching_policy: "Bundled into offline airspace packages with cycle expiration banner.".to_string(),
                rate_limit: None,
                availability_notes: "OFM public distribution endpoints.".to_string(),
                incident_response: "Warn user if AIRAC cycle is expired; do not delete offline data in flight.".to_string(),
            },
        }),
        ProviderDatasetRecord::new(ProviderDatasetRecordInput {
            provider_id: "openaip".to_string(),
            dataset_id: "openaip-community-airspace".to_string(),
            dataset_name: "OpenAIP Community Airspace Data".to_string(),
            category: DataSourceCategory::Airspace,
            evidence: EvidenceRecord {
                terms_url: Some("https://www.openaip.net/terms-of-service".to_string()),
                written_permission_reference: None,
                evidence_date: "2026-08-07".to_string(),
                reviewer: "markusbrand".to_string(),
                evidence_notes: vec!["OpenAIP terms allow non-commercial access and redistribution with attribution under CC BY-NC-SA 4.0.".to_string()],
            },
            decision: GovernanceDecision {
                state: GovernanceDecisionState::Approved,
                rationale: "Approved as secondary / complementary airspace source under CC BY-NC-SA 4.0.".to_string(),
            },
            review: ReviewRecord {
                reviewed_at: "2026-08-07".to_string(),
                revalidation_at: "2027-08-07".to_string(),
                reviewer: "markusbrand".to_string(),
                notes: vec!["Review API access limits and terms periodically.".to_string()],
            },
            licence: LicenceConstraints {
                license_identifier_or_terms_url: "CC-BY-NC-SA-4.0 (https://www.openaip.net/)".to_string(),
                attribution_text: "Airspace data © openAIP.net contributors".to_string(),
                attribution_url: Some("https://www.openaip.net/".to_string()),
                redistribution: "Permitted for non-commercial offline packages.".to_string(),
                caching: "Offline caching permitted.".to_string(),
                derivation: "Permitted with Share-Alike.".to_string(),
                review_expiry: "2027-08-07".to_string(),
            },
            privacy: PrivacyConstraints {
                contains_personal_data: false,
                legal_basis: None,
                consent_expectations: None,
                retention: "No personal data.".to_string(),
                deletion: "Not applicable.".to_string(),
                onward_sharing_limits: "Standard CC BY-NC-SA terms.".to_string(),
            },
            operational: OperationalConstraints {
                update_cadence: "Continuous community updates / monthly snapshots.".to_string(),
                caching_policy: "Offline package bundle.".to_string(),
                rate_limit: Some("API requests subject to client rate limits during package builds.".to_string()),
                availability_notes: "OpenAIP API.".to_string(),
                incident_response: "Fallback to OFM if OpenAIP API is unreachable.".to_string(),
            },
        }),

        // 4. Geocoding
        ProviderDatasetRecord::new(ProviderDatasetRecordInput {
            provider_id: "komoot-photon".to_string(),
            dataset_id: "photon-offline-geocoding".to_string(),
            dataset_name: "Photon Offline Geocoding Index (OSM-based)".to_string(),
            category: DataSourceCategory::Geocoding,
            evidence: EvidenceRecord {
                terms_url: Some("https://photon.komoot.io/".to_string()),
                written_permission_reference: None,
                evidence_date: "2026-08-07".to_string(),
                reviewer: "markusbrand".to_string(),
                evidence_notes: vec![
                    "Photon software is Apache 2.0; underlying dataset is OpenStreetMap (ODbL 1.0)".to_string(),
                    "Allows offline embedded index creation and packaging for local search".to_string(),
                ],
            },
            decision: GovernanceDecision {
                state: GovernanceDecisionState::Approved,
                rationale: "ODbL and Apache 2.0 permit pre-building offline regional search indices bundled with map downloads.".to_string(),
            },
            review: ReviewRecord {
                reviewed_at: "2026-08-07".to_string(),
                revalidation_at: "2027-08-07".to_string(),
                reviewer: "markusbrand".to_string(),
                notes: vec!["Annual review alongside OSM base map cycle.".to_string()],
            },
            licence: LicenceConstraints {
                license_identifier_or_terms_url: "ODbL-1.0 / Apache-2.0 (https://photon.komoot.io/)".to_string(),
                attribution_text: "Geocoding data © OpenStreetMap contributors".to_string(),
                attribution_url: Some("https://www.openstreetmap.org/copyright".to_string()),
                redistribution: "Permitted in offline SQLite / search index packages.".to_string(),
                caching: "Permanent offline storage permitted.".to_string(),
                derivation: "Permitted with attribution.".to_string(),
                review_expiry: "2027-08-07".to_string(),
            },
            privacy: PrivacyConstraints {
                contains_personal_data: false,
                legal_basis: None,
                consent_expectations: None,
                retention: "No personal data.".to_string(),
                deletion: "Not applicable.".to_string(),
                onward_sharing_limits: "Standard attribution.".to_string(),
            },
            operational: OperationalConstraints {
                update_cadence: "Generated alongside regional map packages.".to_string(),
                caching_policy: "Local database on device.".to_string(),
                rate_limit: None,
                availability_notes: "Fully offline on client device; zero runtime network dependency.".to_string(),
                incident_response: "Degrade search gracefully if index is missing.".to_string(),
            },
        }),
        ProviderDatasetRecord::new(ProviderDatasetRecordInput {
            provider_id: "google-geocoding-api".to_string(),
            dataset_id: "google-maps-geocoding".to_string(),
            dataset_name: "Google Maps Geocoding API".to_string(),
            category: DataSourceCategory::Geocoding,
            evidence: EvidenceRecord {
                terms_url: Some("https://cloud.google.com/maps-platform/terms".to_string()),
                written_permission_reference: None,
                evidence_date: "2026-08-07".to_string(),
                reviewer: "markusbrand".to_string(),
                evidence_notes: vec!["Google Maps Platform Terms explicitly prohibit offline pre-fetching, bulk caching, and non-Google map display.".to_string()],
            },
            decision: GovernanceDecision {
                state: GovernanceDecisionState::Rejected,
                rationale: "Google terms strictly forbid permanent offline storage and coordinate extraction for third-party map renderers.".to_string(),
            },
            review: ReviewRecord {
                reviewed_at: "2026-08-07".to_string(),
                revalidation_at: "2027-08-07".to_string(),
                reviewer: "markusbrand".to_string(),
                notes: vec!["Permanent rejection for offline storage.".to_string()],
            },
            licence: LicenceConstraints {
                license_identifier_or_terms_url: "PROPRIETARY-GOOGLE-MAPS-TERMS".to_string(),
                attribution_text: "N/A".to_string(),
                attribution_url: None,
                redistribution: "Prohibited.".to_string(),
                caching: "Prohibited beyond transient 30-day client cache.".to_string(),
                derivation: "Prohibited.".to_string(),
                review_expiry: "2027-08-07".to_string(),
            },
            privacy: PrivacyConstraints {
                contains_personal_data: false,
                legal_basis: None,
                consent_expectations: None,
                retention: "N/A".to_string(),
                deletion: "N/A".to_string(),
                onward_sharing_limits: "N/A".to_string(),
            },
            operational: OperationalConstraints {
                update_cadence: "N/A".to_string(),
                caching_policy: "Prohibited.".to_string(),
                rate_limit: None,
                availability_notes: "N/A".to_string(),
                incident_response: "Do not use for offline or derived storage.".to_string(),
            },
        }),

        // 5. Live Pilots
        ProviderDatasetRecord::new(ProviderDatasetRecordInput {
            provider_id: "open-glider-network".to_string(),
            dataset_id: "ogn-live-aprs-traffic".to_string(),
            dataset_name: "Open Glider Network (OGN) Live Telemetry".to_string(),
            category: DataSourceCategory::LivePilot,
            evidence: EvidenceRecord {
                terms_url: Some("https://www.glidernet.org/".to_string()),
                written_permission_reference: None,
                evidence_date: "2026-08-07".to_string(),
                reviewer: "markusbrand".to_string(),
                evidence_notes: vec![
                    "OGN APRS gateway and privacy charter reviewed".to_string(),
                    "Requires strict adherence to OGN opt-out flags (no-track flags, private registration)".to_string(),
                ],
            },
            decision: GovernanceDecision {
                state: GovernanceDecisionState::Approved,
                rationale: "Approved for live in-flight proximity display provided pilot privacy opt-out flags are strictly honored and data is ephemeral.".to_string(),
            },
            review: ReviewRecord {
                reviewed_at: "2026-08-07".to_string(),
                revalidation_at: "2027-08-07".to_string(),
                reviewer: "markusbrand".to_string(),
                notes: vec!["Annual audit of OGN privacy guidelines and APRS gateway terms.".to_string()],
            },
            licence: LicenceConstraints {
                license_identifier_or_terms_url: "OGN-Terms-Of-Use (https://www.glidernet.org/)".to_string(),
                attribution_text: "Live traffic courtesy of Open Glider Network (OGN)".to_string(),
                attribution_url: Some("https://www.glidernet.org/".to_string()),
                redistribution: "Real-time ephemeral broadcast only; no mass archival redistribution.".to_string(),
                caching: "Transient memory cache only (< 5 minutes).".to_string(),
                derivation: "Permitted for local collision alert calculations.".to_string(),
                review_expiry: "2027-08-07".to_string(),
            },
            privacy: PrivacyConstraints {
                contains_personal_data: true,
                legal_basis: Some("Legitimate interest in flight safety / pilot collision avoidance (GDPR Art. 6(1)(f))".to_string()),
                consent_expectations: Some("Respect OGN privacy flag / DDB opt-out / stealth mode; drop flagged beacons immediately.".to_string()),
                retention: "Ephemeral in-memory ring buffer; flushed upon app exit or after 5 minutes.".to_string(),
                deletion: "Immediate drop upon beacon expiration or pilot opt-out signal.".to_string(),
                onward_sharing_limits: "Zero third-party telemetry sharing without explicit pilot consent.".to_string(),
            },
            operational: OperationalConstraints {
                update_cadence: "Real-time 1-5 second beacon updates via APRS/WebSockets.".to_string(),
                caching_policy: "Transient in-memory cache only.".to_string(),
                rate_limit: Some("Single pooled connection per client or server relay.".to_string()),
                availability_notes: "OGN APRS server network.".to_string(),
                incident_response: "Disconnect gracefully on server failure; display offline indicator to pilot.".to_string(),
            },
        }),
        ProviderDatasetRecord::new(ProviderDatasetRecordInput {
            provider_id: "brandyfly-live-network".to_string(),
            dataset_id: "brandyfly-pilot-group-sharing".to_string(),
            dataset_name: "BrandyFly First-Party Live Pilot Group Sharing".to_string(),
            category: DataSourceCategory::LivePilot,
            evidence: EvidenceRecord {
                terms_url: Some("https://github.com/markusbrand/brandyfly".to_string()),
                written_permission_reference: None,
                evidence_date: "2026-08-07".to_string(),
                reviewer: "markusbrand".to_string(),
                evidence_notes: vec![
                    "First-party backend live tracking service built on explicit user consent".to_string(),
                    "Pilot configures group sharing, ghosting/privacy radius, and sharing toggle".to_string(),
                ],
            },
            decision: GovernanceDecision {
                state: GovernanceDecisionState::Approved,
                rationale: "Approved under explicit user consent and GDPR-compliant privacy controls.".to_string(),
            },
            review: ReviewRecord {
                reviewed_at: "2026-08-07".to_string(),
                revalidation_at: "2027-08-07".to_string(),
                reviewer: "markusbrand".to_string(),
                notes: vec!["Ensure backend deletes expired location records every hour.".to_string()],
            },
            licence: LicenceConstraints {
                license_identifier_or_terms_url: "MIT / BrandyFly First-Party Terms".to_string(),
                attribution_text: "BrandyFly Live Sharing".to_string(),
                attribution_url: Some("https://github.com/markusbrand/brandyfly".to_string()),
                redistribution: "Shared only with explicitly joined flight group / buddies.".to_string(),
                caching: "Transient server cache; 24-hour max retention.".to_string(),
                derivation: "Permitted for group map display.".to_string(),
                review_expiry: "2027-08-07".to_string(),
            },
            privacy: PrivacyConstraints {
                contains_personal_data: true,
                legal_basis: Some("Explicit user consent (GDPR Art. 6(1)(a))".to_string()),
                consent_expectations: Some("Opt-in toggle in flight settings; pilot can revoke at any time.".to_string()),
                retention: "Max 24 hours on backend; purged automatically.".to_string(),
                deletion: "User can delete flight tracks immediately via app or API.".to_string(),
                onward_sharing_limits: "Never shared with third parties or advertising networks.".to_string(),
            },
            operational: OperationalConstraints {
                update_cadence: "Real-time 5-15s position reports when actively flying.".to_string(),
                caching_policy: "Transient cache.".to_string(),
                rate_limit: Some("Max 1 update per 3 seconds per pilot.".to_string()),
                availability_notes: "BrandyFly backend cluster / Raspberry Pi dev instance.".to_string(),
                incident_response: "App continues local flight recording without interruption if backend is unreachable.".to_string(),
            },
        }),

        // 6. Thermal
        ProviderDatasetRecord::new(ProviderDatasetRecordInput {
            provider_id: "thermal-kk7".to_string(),
            dataset_id: "thermal-kk7-hotspots".to_string(),
            dataset_name: "Thermal.kk7.ch Paragliding Thermal Database".to_string(),
            category: DataSourceCategory::Thermal,
            evidence: EvidenceRecord {
                terms_url: Some("http://thermal.kk7.ch/".to_string()),
                written_permission_reference: None,
                evidence_date: "2026-08-07".to_string(),
                reviewer: "markusbrand".to_string(),
                evidence_notes: vec![
                    "KK7 open thermal dataset terms reviewed".to_string(),
                    "Non-commercial paragliding use and offline layer packaging permitted with attribution".to_string(),
                ],
            },
            decision: GovernanceDecision {
                state: GovernanceDecisionState::Approved,
                rationale: "Approved for generating offline paragliding thermal overlay maps with attribution.".to_string(),
            },
            review: ReviewRecord {
                reviewed_at: "2026-08-07".to_string(),
                revalidation_at: "2027-08-07".to_string(),
                reviewer: "markusbrand".to_string(),
                notes: vec!["Annual review of KK7 portal licensing conditions.".to_string()],
            },
            licence: LicenceConstraints {
                license_identifier_or_terms_url: "KK7-Open-Thermal-Terms (http://thermal.kk7.ch/)".to_string(),
                attribution_text: "Thermal map © thermal.kk7.ch".to_string(),
                attribution_url: Some("http://thermal.kk7.ch/".to_string()),
                redistribution: "Permitted in non-commercial offline overlay packages.".to_string(),
                caching: "Offline caching permitted.".to_string(),
                derivation: "Permitted for vector / raster hotspot tiles.".to_string(),
                review_expiry: "2027-08-07".to_string(),
            },
            privacy: PrivacyConstraints {
                contains_personal_data: false,
                legal_basis: None,
                consent_expectations: None,
                retention: "No personal data (statistical climb aggregations only).".to_string(),
                deletion: "Not applicable.".to_string(),
                onward_sharing_limits: "Standard attribution.".to_string(),
            },
            operational: OperationalConstraints {
                update_cadence: "Annual / seasonal thermal model updates.".to_string(),
                caching_policy: "Pre-generated vector tile packages.".to_string(),
                rate_limit: None,
                availability_notes: "KK7 data extract archive.".to_string(),
                incident_response: "Thermal layer disabled if tile generation fails; base map unaffected.".to_string(),
            },
        }),
        ProviderDatasetRecord::new(ProviderDatasetRecordInput {
            provider_id: "unverified-flight-mining".to_string(),
            dataset_id: "raw-crowdsourced-igc-mining".to_string(),
            dataset_name: "Unverified Raw Pilot IGC Log Mining".to_string(),
            category: DataSourceCategory::Thermal,
            evidence: EvidenceRecord {
                terms_url: None,
                written_permission_reference: None,
                evidence_date: "2026-08-07".to_string(),
                reviewer: "markusbrand".to_string(),
                evidence_notes: vec!["Evaluating automated scraping of public contest portals without clear data sharing license.".to_string()],
            },
            decision: GovernanceDecision {
                state: GovernanceDecisionState::Blocked,
                rationale: "Blocked until explicit consent model, anonymization pipeline, and data-provider agreements are established.".to_string(),
            },
            review: ReviewRecord {
                reviewed_at: "2026-08-07".to_string(),
                revalidation_at: "2027-08-07".to_string(),
                reviewer: "markusbrand".to_string(),
                notes: vec!["Do not ingest raw pilot tracks without written agreement.".to_string()],
            },
            licence: LicenceConstraints {
                license_identifier_or_terms_url: "UNVERIFIED-CONTEST-DATA".to_string(),
                attribution_text: "Unverified".to_string(),
                attribution_url: None,
                redistribution: "Blocked pending legal review.".to_string(),
                caching: "Blocked.".to_string(),
                derivation: "Blocked.".to_string(),
                review_expiry: "2027-08-07".to_string(),
            },
            privacy: PrivacyConstraints {
                contains_personal_data: true,
                legal_basis: None,
                consent_expectations: Some("Individual pilot consent required for raw track log redistribution.".to_string()),
                retention: "Blocked.".to_string(),
                deletion: "Blocked.".to_string(),
                onward_sharing_limits: "Blocked.".to_string(),
            },
            operational: OperationalConstraints {
                update_cadence: "Blocked.".to_string(),
                caching_policy: "Blocked.".to_string(),
                rate_limit: None,
                availability_notes: "N/A".to_string(),
                incident_response: "Do not build or publish.".to_string(),
            },
        }),
    ]
}

pub mod fixtures {
    use super::*;

    pub fn approved_base_map_record() -> ProviderDatasetRecord {
        ProviderDatasetRecord::new(ProviderDatasetRecordInput {
            provider_id: "osm-base-map".to_string(),
            dataset_id: "osm-country-extract".to_string(),
            dataset_name: "OSM Country Extract".to_string(),
            category: DataSourceCategory::BaseMap,
            evidence: EvidenceRecord {
                terms_url: Some("https://www.openstreetmap.org/copyright".to_string()),
                written_permission_reference: None,
                evidence_date: "2026-08-07".to_string(),
                reviewer: "engineering-audit".to_string(),
                evidence_notes: vec!["Public attribution and sharing reviewed".to_string()],
            },
            decision: GovernanceDecision {
                state: GovernanceDecisionState::Approved,
                rationale:
                    "Offline redistribution is explicitly permitted under the reviewed terms."
                        .to_string(),
            },
            review: ReviewRecord {
                reviewed_at: "2026-08-07".to_string(),
                revalidation_at: "2027-08-07".to_string(),
                reviewer: "engineering-audit".to_string(),
                notes: vec!["Approval is tied to the published license text".to_string()],
            },
            licence: LicenceConstraints {
                license_identifier_or_terms_url: "https://www.openstreetmap.org/copyright"
                    .to_string(),
                attribution_text: "© OpenStreetMap contributors".to_string(),
                attribution_url: Some("https://www.openstreetmap.org/copyright".to_string()),
                redistribution: "Allowed for offline package generation".to_string(),
                caching: "Allowed for local/offline caching".to_string(),
                derivation: "Derived tiles require attribution".to_string(),
                review_expiry: "2027-08-07".to_string(),
            },
            privacy: PrivacyConstraints {
                contains_personal_data: false,
                legal_basis: None,
                consent_expectations: None,
                retention: "No personal data retained".to_string(),
                deletion: "Not applicable".to_string(),
                onward_sharing_limits: "None beyond source attribution".to_string(),
            },
            operational: OperationalConstraints {
                update_cadence: "Monthly".to_string(),
                caching_policy: "Allowed for offline package generation".to_string(),
                rate_limit: None,
                availability_notes: "Static extract".to_string(),
                incident_response: "Suspend new publication if attribution terms change"
                    .to_string(),
            },
        })
    }

    pub fn rejected_commercial_tiles_record() -> ProviderDatasetRecord {
        let mut r = approved_base_map_record();
        r.provider_id = "proprietary-tiles-co".to_string();
        r.dataset_id = "commercial-tiles".to_string();
        r.decision.state = GovernanceDecisionState::Rejected;
        r.decision.rationale = "Terms prohibit offline caching and scraping.".to_string();
        r.evidence.terms_url = None;
        r.evidence.written_permission_reference = None;
        r
    }

    pub fn blocked_unclear_license_record() -> ProviderDatasetRecord {
        let mut r = approved_base_map_record();
        r.provider_id = "unknown-aeronautical-source".to_string();
        r.dataset_id = "unclear-airspace".to_string();
        r.category = DataSourceCategory::Airspace;
        r.decision.state = GovernanceDecisionState::Blocked;
        r.decision.rationale =
            "Redistribution terms are ambiguous; awaiting written clarification.".to_string();
        r.evidence.terms_url = None;
        r.evidence.written_permission_reference = None;
        r
    }

    pub fn expired_review_record() -> ProviderDatasetRecord {
        let mut r = approved_base_map_record();
        r.review.revalidation_at = "2025-01-01".to_string();
        r.licence.review_expiry = "2025-01-01".to_string();
        r
    }

    pub fn revoked_permission_record() -> ProviderDatasetRecord {
        let mut r = approved_base_map_record();
        r.decision.state = GovernanceDecisionState::Rejected;
        r.decision.rationale =
            "Written redistribution permission was revoked by data owner on 2026-08-01."
                .to_string();
        r.operational.incident_response = "Disable new package builds; existing flight data remains installed with visible source date.".to_string();
        r
    }

    pub fn personal_data_live_pilot_record() -> ProviderDatasetRecord {
        ProviderDatasetRecord::new(ProviderDatasetRecordInput {
            provider_id: "live-tracking-service".to_string(),
            dataset_id: "pilot-telemetry-feed".to_string(),
            dataset_name: "Pilot Live Telemetry".to_string(),
            category: DataSourceCategory::LivePilot,
            evidence: EvidenceRecord {
                terms_url: Some("https://example.com/api-terms".to_string()),
                written_permission_reference: None,
                evidence_date: "2026-08-07".to_string(),
                reviewer: "security-audit".to_string(),
                evidence_notes: vec!["GDPR and opt-in consent compliance verified.".to_string()],
            },
            decision: GovernanceDecision {
                state: GovernanceDecisionState::Approved,
                rationale:
                    "Personal telemetry handled with explicit consent and ephemeral storage."
                        .to_string(),
            },
            review: ReviewRecord {
                reviewed_at: "2026-08-07".to_string(),
                revalidation_at: "2027-08-07".to_string(),
                reviewer: "security-audit".to_string(),
                notes: vec!["Verify retention purge routines annually.".to_string()],
            },
            licence: LicenceConstraints {
                license_identifier_or_terms_url: "https://example.com/api-terms".to_string(),
                attribution_text: "Live data © Example Tracking".to_string(),
                attribution_url: Some("https://example.com/".to_string()),
                redistribution: "Ephemeral streaming to authorized buddies only.".to_string(),
                caching: "In-memory ring buffer only.".to_string(),
                derivation: "Relative proximity calculation.".to_string(),
                review_expiry: "2027-08-07".to_string(),
            },
            privacy: PrivacyConstraints {
                contains_personal_data: true,
                legal_basis: Some("Explicit Consent (GDPR Art 6.1.a)".to_string()),
                consent_expectations: Some(
                    "Pilot must opt-in via settings before location is broadcast.".to_string(),
                ),
                retention: "Ephemeral in-memory cache; purged upon landing or after 1 hour."
                    .to_string(),
                deletion: "Immediate on-demand deletion supported.".to_string(),
                onward_sharing_limits: "Zero third-party sharing.".to_string(),
            },
            operational: OperationalConstraints {
                update_cadence: "10s beacon cadence.".to_string(),
                caching_policy: "Ephemeral.".to_string(),
                rate_limit: Some("6 requests/minute".to_string()),
                availability_notes: "WebSocket stream with reconnect backoff.".to_string(),
                incident_response: "Show offline indicator; flight core continues unaffected."
                    .to_string(),
            },
        })
    }

    pub fn valid_package_manifest() -> DataPackageManifest {
        DataPackageManifest::new(DataPackageManifestInput {
            dataset_identifier: "osm-alps-vector-v1".to_string(),
            provider: "osm-geofabrik".to_string(),
            source_version_or_date: "2026-08-01".to_string(),
            build_time: "2026-08-07T12:00:00Z".to_string(),
            license_identifier_or_terms_url: "ODbL-1.0".to_string(),
            attribution_text: "© OpenStreetMap contributors".to_string(),
            attribution_url: Some("https://www.openstreetmap.org/copyright".to_string()),
            geographic_coverage: "Alps (bbox: 5.8,43.7,16.5,48.2)".to_string(),
            checksum: "sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
                .to_string(),
            review_expiry: "2027-08-07".to_string(),
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn schema_version_is_bumped_in_one_place() {
        assert_eq!(ProviderDatasetRecord::SCHEMA_VERSION, 1);
        assert_eq!(DataPackageManifest::SCHEMA_VERSION, 1);
    }

    #[test]
    fn approved_record_validates() {
        let record = fixtures::approved_base_map_record();
        assert_eq!(record.decision.state, GovernanceDecisionState::Approved);
        assert_eq!(record.category, DataSourceCategory::BaseMap);
        assert!(record.validate().is_ok());
        assert!(record.validate_with_date("2026-08-15").is_ok());
    }

    #[test]
    fn validation_rejects_missing_provider_id() {
        let mut record = fixtures::approved_base_map_record();
        record.provider_id = String::new();

        assert_eq!(
            record.validate(),
            Err(ProviderDatasetRecordValidationError::MissingField {
                field: "provider_id"
            })
        );
    }

    #[test]
    fn validation_rejects_approved_records_without_authoritative_evidence() {
        let mut record = fixtures::approved_base_map_record();
        record.evidence.terms_url = None;

        assert_eq!(
            record.validate(),
            Err(
                ProviderDatasetRecordValidationError::MissingAuthoritativeEvidence {
                    field: "evidence.terms_url or evidence.written_permission_reference",
                }
            )
        );
    }

    #[test]
    fn validation_accepts_written_permission_reference() {
        let mut record = fixtures::approved_base_map_record();
        record.evidence.terms_url = None;
        record.evidence.written_permission_reference =
            Some("SIGNED-AGREEMENT-2026-001".to_string());

        assert!(record.validate().is_ok());
    }

    #[test]
    fn validation_rejects_unsupported_schema_version() {
        let mut record = fixtures::approved_base_map_record();
        record.schema_version = 99;

        assert_eq!(
            record.validate(),
            Err(
                ProviderDatasetRecordValidationError::UnsupportedSchemaVersion {
                    expected: 1,
                    found: 99,
                }
            )
        );
    }

    #[test]
    fn rejected_decision_does_not_require_terms_evidence() {
        let record = fixtures::rejected_commercial_tiles_record();
        assert_eq!(record.decision.state, GovernanceDecisionState::Rejected);
        assert!(record.validate().is_ok());
    }

    #[test]
    fn blocked_decision_validates() {
        let record = fixtures::blocked_unclear_license_record();
        assert_eq!(record.decision.state, GovernanceDecisionState::Blocked);
        assert!(record.validate().is_ok());
    }

    #[test]
    fn expired_record_detected() {
        let record = fixtures::expired_review_record();
        assert!(record.is_review_expired("2026-08-15"));
        let err = record.validate_with_date("2026-08-15");
        assert!(matches!(
            err,
            Err(ProviderDatasetRecordValidationError::ReviewExpired { .. })
        ));
    }

    #[test]
    fn revoked_record_validates() {
        let record = fixtures::revoked_permission_record();
        assert_eq!(record.decision.state, GovernanceDecisionState::Rejected);
        assert!(record.validate().is_ok());
    }

    #[test]
    fn personal_data_governance_validates() {
        let record = fixtures::personal_data_live_pilot_record();
        assert!(record.validate().is_ok());

        let mut invalid_record = record.clone();
        invalid_record.privacy.legal_basis = None;
        assert_eq!(
            invalid_record.validate(),
            Err(
                ProviderDatasetRecordValidationError::MissingPersonalDataGovernance {
                    field: "privacy.legal_basis",
                }
            )
        );

        let mut invalid_consent = record.clone();
        invalid_consent.privacy.consent_expectations = Some("  ".to_string());
        assert_eq!(
            invalid_consent.validate(),
            Err(
                ProviderDatasetRecordValidationError::MissingPersonalDataGovernance {
                    field: "privacy.consent_expectations",
                }
            )
        );
    }

    #[test]
    fn valid_package_manifest_passes_validation() {
        let manifest = fixtures::valid_package_manifest();
        assert!(manifest.validate().is_ok());
        assert!(manifest.validate_with_date("2026-08-15").is_ok());
    }

    #[test]
    fn package_manifest_rejects_missing_fields() {
        let mut manifest = fixtures::valid_package_manifest();
        manifest.checksum = String::new();
        assert_eq!(
            manifest.validate(),
            Err(DataPackageManifestValidationError::MissingField { field: "checksum" })
        );

        let mut manifest2 = fixtures::valid_package_manifest();
        manifest2.attribution_text = " ".to_string();
        assert_eq!(
            manifest2.validate(),
            Err(DataPackageManifestValidationError::MissingField {
                field: "attribution_text"
            })
        );

        let mut manifest3 = fixtures::valid_package_manifest();
        manifest3.geographic_coverage = "".to_string();
        assert_eq!(
            manifest3.validate(),
            Err(DataPackageManifestValidationError::MissingField {
                field: "geographic_coverage"
            })
        );
    }

    #[test]
    fn package_manifest_rejects_expired_review() {
        let mut manifest = fixtures::valid_package_manifest();
        manifest.review_expiry = "2025-01-01".to_string();
        assert_eq!(
            manifest.validate_with_date("2026-08-15"),
            Err(DataPackageManifestValidationError::ExpiredReview {
                expiry: "2025-01-01".to_string(),
                current_date: "2026-08-15".to_string(),
            })
        );
    }

    #[test]
    fn audited_inventory_is_complete_and_valid() {
        let inventory = audited_provider_inventory();
        assert!(!inventory.is_empty());

        for record in &inventory {
            assert!(
                record.validate().is_ok(),
                "Record {} ({}) failed validation: {:?}",
                record.dataset_id,
                record.provider_id,
                record.validate()
            );
        }

        // All 6 required categories must have an approved provider
        assert_eq!(check_category_coverage(&inventory), Ok(()));
    }
}
