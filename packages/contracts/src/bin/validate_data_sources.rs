use brandyfly_contracts::{
    DataPackageManifest, DataPackageManifestInput, GovernanceDecisionState,
    audited_provider_inventory, check_category_coverage,
};
use std::env;
use std::fs;
use std::process;

fn main() {
    let args: Vec<String> = env::args().collect();
    let mut manifest_path: Option<String> = None;
    let mut current_date: Option<String> = None;

    let mut i = 1;
    while i < args.len() {
        match args[i].as_str() {
            "--manifest" => {
                if i + 1 < args.len() {
                    manifest_path = Some(args[i + 1].clone());
                    i += 2;
                } else {
                    eprintln!("Error: --manifest requires a file path argument");
                    process::exit(2);
                }
            }
            "--current-date" => {
                if i + 1 < args.len() {
                    current_date = Some(args[i + 1].clone());
                    i += 2;
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
    let mut dataset_identifier = String::new();
    let mut provider = String::new();
    let mut source_version_or_date = String::new();
    let mut build_time = String::new();
    let mut license_identifier_or_terms_url = String::new();
    let mut attribution_text = String::new();
    let mut attribution_url = None;
    let mut geographic_coverage = String::new();
    let mut checksum = String::new();
    let mut review_expiry = String::new();

    for line in content.lines() {
        let line = line.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        if let Some((k, v)) = line.split_once(':') {
            let key = k.trim().trim_matches('"');
            let val = v
                .trim()
                .trim_matches('"')
                .trim_matches(',')
                .trim()
                .to_string();
            match key {
                "dataset_identifier" | "dataset_id" => dataset_identifier = val,
                "provider" | "provider_id" => provider = val,
                "source_version_or_date" | "source_date" => source_version_or_date = val,
                "build_time" | "built_at" => build_time = val,
                "license_identifier_or_terms_url" | "license" => {
                    license_identifier_or_terms_url = val
                }
                "attribution_text" | "attribution" => attribution_text = val,
                "attribution_url" => {
                    attribution_url = if val.is_empty() { None } else { Some(val) }
                }
                "geographic_coverage" | "coverage" => geographic_coverage = val,
                "checksum" | "sha256" => checksum = val,
                "review_expiry" | "expires" => review_expiry = val,
                _ => {}
            }
        }
    }

    DataPackageManifest::new(DataPackageManifestInput {
        dataset_identifier,
        provider,
        source_version_or_date,
        build_time,
        license_identifier_or_terms_url,
        attribution_text,
        attribution_url,
        geographic_coverage,
        checksum,
        review_expiry,
    })
}
