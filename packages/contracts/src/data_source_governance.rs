#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum DataSourceCategory {
    BaseMap,
    Elevation,
    Airspace,
    Geocoding,
    LivePilot,
    Thermal,
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
pub enum ProviderDatasetRecordValidationError {
    UnsupportedSchemaVersion { expected: u16, found: u16 },
    MissingField { field: &'static str },
    MissingAuthoritativeEvidence { field: &'static str },
}

impl ProviderDatasetRecord {
    pub const SCHEMA_VERSION: u16 = 1;

    #[must_use]
    pub fn new(
        provider_id: impl Into<String>,
        dataset_id: impl Into<String>,
        dataset_name: impl Into<String>,
        category: DataSourceCategory,
        evidence: EvidenceRecord,
        decision: GovernanceDecision,
        review: ReviewRecord,
        licence: LicenceConstraints,
        privacy: PrivacyConstraints,
        operational: OperationalConstraints,
    ) -> Self {
        Self {
            schema_version: Self::SCHEMA_VERSION,
            provider_id: provider_id.into(),
            dataset_id: dataset_id.into(),
            dataset_name: dataset_name.into(),
            category,
            evidence,
            decision,
            review,
            licence,
            privacy,
            operational,
        }
    }

    #[must_use]
    pub fn validate(&self) -> Result<(), ProviderDatasetRecordValidationError> {
        if self.schema_version != Self::SCHEMA_VERSION {
            return Err(ProviderDatasetRecordValidationError::UnsupportedSchemaVersion {
                expected: Self::SCHEMA_VERSION,
                found: self.schema_version,
            });
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
        self.ensure_non_empty("operational.update_cadence", &self.operational.update_cadence)?;
        self.ensure_non_empty("operational.caching_policy", &self.operational.caching_policy)?;
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
            return Err(ProviderDatasetRecordValidationError::MissingAuthoritativeEvidence {
                field: "evidence.terms_url or evidence.written_permission_reference",
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

#[cfg(test)]
mod tests {
    use super::*;

    fn approved_record() -> ProviderDatasetRecord {
        ProviderDatasetRecord::new(
            "osm-base-map",
            "osm-country-extract",
            "OSM Country Extract",
            DataSourceCategory::BaseMap,
            EvidenceRecord {
                terms_url: Some("https://www.openstreetmap.org/copyright".to_string()),
                written_permission_reference: None,
                evidence_date: "2026-08-07".to_string(),
                reviewer: "engineering-audit".to_string(),
                evidence_notes: vec!["Public attribution and sharing reviewed".to_string()],
            },
            GovernanceDecision {
                state: GovernanceDecisionState::Approved,
                rationale: "Offline redistribution is explicitly permitted under the reviewed terms."
                    .to_string(),
            },
            ReviewRecord {
                reviewed_at: "2026-08-07".to_string(),
                revalidation_at: "2026-11-07".to_string(),
                reviewer: "engineering-audit".to_string(),
                notes: vec!["Approval is tied to the published license text".to_string()],
            },
            LicenceConstraints {
                license_identifier_or_terms_url: "https://www.openstreetmap.org/copyright"
                    .to_string(),
                attribution_text: "© OpenStreetMap contributors".to_string(),
                attribution_url: Some("https://www.openstreetmap.org/copyright".to_string()),
                redistribution: "Allowed for offline package generation".to_string(),
                caching: "Allowed for local/offline caching".to_string(),
                derivation: "Derived tiles require attribution".to_string(),
                review_expiry: "2026-11-07".to_string(),
            },
            PrivacyConstraints {
                contains_personal_data: false,
                legal_basis: None,
                consent_expectations: None,
                retention: "No personal data retained".to_string(),
                deletion: "Not applicable".to_string(),
                onward_sharing_limits: "None beyond source attribution".to_string(),
            },
            OperationalConstraints {
                update_cadence: "Monthly".to_string(),
                caching_policy: "Allowed for offline package generation".to_string(),
                rate_limit: None,
                availability_notes: "Static extract".to_string(),
                incident_response: "Suspend new publication if attribution terms change".to_string(),
            },
        )
    }

    #[test]
    fn schema_version_is_bumped_in_one_place() {
        assert_eq!(ProviderDatasetRecord::SCHEMA_VERSION, 1);
    }

    #[test]
    fn approved_record_validates() {
        let record = approved_record();

        assert_eq!(record.decision.state, GovernanceDecisionState::Approved);
        assert_eq!(record.category, DataSourceCategory::BaseMap);
        assert!(record.validate().is_ok());
    }

    #[test]
    fn validation_rejects_missing_provider_id() {
        let mut record = approved_record();
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
        let mut record = approved_record();
        record.evidence.terms_url = None;

        assert_eq!(
            record.validate(),
            Err(ProviderDatasetRecordValidationError::MissingAuthoritativeEvidence {
                field: "evidence.terms_url or evidence.written_permission_reference",
            })
        );
    }
}
