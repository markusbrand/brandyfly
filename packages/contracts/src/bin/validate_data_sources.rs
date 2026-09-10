use brandyfly_contracts::{
    DataPackageManifest, DataPackageManifestInput, GovernanceDecisionState,
    audited_provider_inventory, check_category_coverage,
};
use std::env;
use std::fs;
use std::process;

fn main() {
    let mut manifest_path: Option<String> = None;
    let mut current_date: Option<String> = None;

    let mut args = env::args().skip(1);
    while let Some(arg) = args.next() {
        match arg.as_str() {
            "--manifest" => {
                if let Some(val) = args.next() {
                    manifest_path = Some(val);
                } else {
                    eprintln!("Error: --manifest requires a file path argument");
                    process::exit(2);
                }
            }
            "--current-date" => {
                if let Some(val) = args.next() {
                    current_date = Some(val);
                } else {
                    eprintln!("Error: --current-date requires YYYY-MM-DD");
                    process::exit(2);
                }
            }
            "--help" | "-h" => {
                println!(
                    "Usage: validate_data_sources [--manifest <file>] [--current-date <YYYY-MM-DD>]"
                );
                println!();
                println!(
                    "Validates provider dataset governance records and data package manifests."
                );
                process::exit(0);
            }
            other => {
                eprintln!("Unknown argument: {}", other);
                process::exit(2);
            }
        }
    }

    let today = current_date.unwrap_or_else(|| {
        // Fallback or default date
        "2026-08-25".to_string()
    });

    println!("============================================================");
    println!("BrandyFly Data Source Governance & License Audit Validator");
    println!("Validation Date: {}", today);
    println!("============================================================");

    let inventory = audited_provider_inventory();
    println!(
        "Auditing {} registered candidate records...\n",
        inventory.len()
    );

    let mut errors: Vec<String> = Vec::new();

    for record in &inventory {
        let status_str = match record.decision.state {
            GovernanceDecisionState::Approved => "[APPROVED]",
            GovernanceDecisionState::Rejected => "[REJECTED]",
            GovernanceDecisionState::Blocked => "[BLOCKED ]",
        };

        println!(
            "{} Category: {:<10} | Dataset: {:<30} | Provider: {}",
            status_str,
            record.category.display_name(),
            record.dataset_id,
            record.provider_id
        );

        if let Err(e) = record.validate_with_date(&today) {
            let msg = format!(
                "Validation failure on dataset '{}' (provider '{}'): {:?}",
                record.dataset_id, record.provider_id, e
            );
            eprintln!("  -> ERROR: {}", msg);
            errors.push(msg);
        }
    }

    println!("\nChecking category coverage across all required categories...");
    match check_category_coverage(&inventory) {
        Ok(()) => {
            println!("✓ All 6 required categories have an approved provider.");
        }
        Err(missing) => {
            let missing_names: Vec<&str> = missing.iter().map(|c| c.display_name()).collect();
            let msg = format!(
                "Missing approved provider for categories: {:?}",
                missing_names
            );
            eprintln!("✗ ERROR: {}", msg);
            errors.push(msg);
        }
    }

    if let Some(path) = manifest_path {
        println!("\nValidating package manifest at: {}", path);
        match fs::read_to_string(&path) {
            Ok(content) => {
                // Parse simple key-value or JSON fields
                let manifest = parse_manifest_simple(&content);
                match manifest.validate_with_date(&today) {
                    Ok(()) => {
                        println!("✓ Package manifest is valid and unexpired.");
                    }
                    Err(e) => {
                        let msg = format!("Package manifest '{}' validation failed: {:?}", path, e);
                        eprintln!("✗ ERROR: {}", msg);
                        errors.push(msg);
                    }
                }
            }
            Err(err) => {
                let msg = format!("Failed to read package manifest file '{}': {}", path, err);
                eprintln!("✗ ERROR: {}", msg);
                errors.push(msg);
            }
        }
    }

    println!("\n------------------------------------------------------------");
    if errors.is_empty() {
        println!("RESULT: All data governance and license checks PASSED ✓");
        println!("------------------------------------------------------------");
        process::exit(0);
    } else {
        eprintln!(
            "RESULT: {} error(s) found during governance validation ✗",
            errors.len()
        );
        println!("------------------------------------------------------------");
        process::exit(1);
    }
}

fn parse_manifest_simple(content: &str) -> DataPackageManifest {
    let mut input = DataPackageManifestInput::default();

    for line in content.lines().map(str::trim) {
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        if let Some((k, v)) = line.split_once(':') {
            let key = k.trim().trim_matches(&['"', ' '][..]);
            let val = v.trim_matches(&['"', ',', ' '][..]);
            match key {
                "dataset_identifier" | "dataset_id" => input.dataset_identifier = val.to_string(),
                "provider" | "provider_id" => input.provider = val.to_string(),
                "source_version_or_date" | "source_date" => {
                    input.source_version_or_date = val.to_string();
                }
                "build_time" | "built_at" => input.build_time = val.to_string(),
                "license_identifier_or_terms_url" | "license" => {
                    input.license_identifier_or_terms_url = val.to_string();
                }
                "attribution_text" | "attribution" => input.attribution_text = val.to_string(),
                "attribution_url" => {
                    input.attribution_url = (!val.is_empty()).then(|| val.to_string());
                }
                "geographic_coverage" | "coverage" => input.geographic_coverage = val.to_string(),
                "checksum" | "sha256" => input.checksum = val.to_string(),
                "review_expiry" | "expires" => input.review_expiry = val.to_string(),
                _ => {}
            }
        }
    }

    DataPackageManifest::new(input)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_manifest_simple_canonical_keys() {
        let content = r#"
            # Manifest comment
            dataset_identifier: "osm-alps-vector-v1"
            provider: "osm-geofabrik"
            source_version_or_date: "2026-08-01"
            build_time: "2026-08-07T12:00:00Z"
            license_identifier_or_terms_url: "ODbL-1.0"
            attribution_text: "© OpenStreetMap contributors"
            attribution_url: "https://www.openstreetmap.org/copyright"
            geographic_coverage: "Alps (bbox: 5.8,43.7,16.5,48.2)"
            checksum: "sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
            review_expiry: "2027-08-07"
        "#;

        let manifest = parse_manifest_simple(content);
        assert_eq!(manifest.dataset_identifier, "osm-alps-vector-v1");
        assert_eq!(manifest.provider, "osm-geofabrik");
        assert_eq!(manifest.source_version_or_date, "2026-08-01");
        assert_eq!(manifest.build_time, "2026-08-07T12:00:00Z");
        assert_eq!(manifest.license_identifier_or_terms_url, "ODbL-1.0");
        assert_eq!(manifest.attribution_text, "© OpenStreetMap contributors");
        assert_eq!(
            manifest.attribution_url,
            Some("https://www.openstreetmap.org/copyright".to_string())
        );
        assert_eq!(
            manifest.geographic_coverage,
            "Alps (bbox: 5.8,43.7,16.5,48.2)"
        );
        assert_eq!(
            manifest.checksum,
            "sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        );
        assert_eq!(manifest.review_expiry, "2027-08-07");
    }

    #[test]
    fn parse_manifest_simple_alias_keys_and_formatting() {
        let content = r#"
            dataset_id: "dem-glo-30",
            provider_id: "copernicus",
            source_date: "2026-01-01",
            built_at: "2026-02-01",
            license: "CC-BY-4.0",
            attribution: "Copernicus DEM",
            coverage: "Global",
            sha256: "abc123hash",
            expires: "2027-01-01",
        "#;

        let manifest = parse_manifest_simple(content);
        assert_eq!(manifest.dataset_identifier, "dem-glo-30");
        assert_eq!(manifest.provider, "copernicus");
        assert_eq!(manifest.source_version_or_date, "2026-01-01");
        assert_eq!(manifest.build_time, "2026-02-01");
        assert_eq!(manifest.license_identifier_or_terms_url, "CC-BY-4.0");
        assert_eq!(manifest.attribution_text, "Copernicus DEM");
        assert_eq!(manifest.attribution_url, None);
        assert_eq!(manifest.geographic_coverage, "Global");
        assert_eq!(manifest.checksum, "abc123hash");
        assert_eq!(manifest.review_expiry, "2027-01-01");
    }
}
