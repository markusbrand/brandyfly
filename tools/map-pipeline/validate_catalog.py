#!/usr/bin/env python3
"""
Validates catalog.json against the BrandyFly offline map catalog schema and checks
checksums/file integrity against local files if requested.
"""

import argparse
from datetime import datetime
import json
import os
import re
import sys

from checksums import compute_file_info

SHA256_REGEX = re.compile(r"^[a-f0-9]{64}$")


def validate_catalog_schema(catalog: dict) -> list[str]:
    errors = []

    # 1. Root checks
    if not isinstance(catalog.get("catalogVersion"), int) or catalog["catalogVersion"] < 1:
        errors.append("Invalid or missing 'catalogVersion' (must be integer >= 1)")

    if "generatedAt" not in catalog:
        errors.append("Missing 'generatedAt' in catalog")
    else:
        try:
            datetime.fromisoformat(catalog["generatedAt"].replace("Z", "+00:00"))
        except Exception:
            errors.append(f"Invalid ISO 8601 timestamp in 'generatedAt': {catalog['generatedAt']}")

    # 2. Attribution
    attr = catalog.get("attribution")
    if not isinstance(attr, dict):
        errors.append("Missing or invalid 'attribution' object")
    else:
        for key in ("osm", "copernicus", "naturalEarth"):
            if not attr.get(key):
                errors.append(f"Missing required attribution entry: '{key}'")

    # 3. Regions
    regions = catalog.get("regions")
    if not isinstance(regions, list) or len(regions) == 0:
        errors.append("'regions' must be a non-empty array")
    else:
        seen_ids = set()
        for idx, r in enumerate(regions):
            prefix = f"regions[{idx}]"
            rid = r.get("id")
            if not rid or not isinstance(rid, str):
                errors.append(f"{prefix}: Missing or invalid 'id'")
            elif rid in seen_ids:
                errors.append(f"{prefix}: Duplicate region id '{rid}'")
            else:
                seen_ids.add(rid)

            if not r.get("name") or not isinstance(r["name"], str):
                errors.append(f"{prefix}: Missing 'name'")
            if not r.get("description") or not isinstance(r["description"], str):
                errors.append(f"{prefix}: Missing 'description'")
            if not r.get("version") or not isinstance(r["version"], str):
                errors.append(f"{prefix}: Missing 'version'")

            bounds = r.get("bounds")
            if not isinstance(bounds, dict):
                errors.append(f"{prefix}: Missing 'bounds' object")
            else:
                for b_key in ("north", "south", "west", "east"):
                    if b_key not in bounds or not isinstance(bounds[b_key], (int, float)):
                        errors.append(f"{prefix}.bounds: Missing or non-numeric '{b_key}'")
                if all(k in bounds and isinstance(bounds[k], (int, float)) for k in ("north", "south", "west", "east")):
                    if bounds["south"] > bounds["north"]:
                        errors.append(f"{prefix}.bounds: south ({bounds['south']}) > north ({bounds['north']})")
                    if bounds["west"] > bounds["east"]:
                        errors.append(f"{prefix}.bounds: west ({bounds['west']}) > east ({bounds['east']})")

            files = r.get("files")
            if not isinstance(files, dict):
                errors.append(f"{prefix}: Missing 'files' object")
            else:
                for f_type in ("map", "terrain"):
                    file_info = files.get(f_type)
                    if not isinstance(file_info, dict):
                        errors.append(f"{prefix}.files: Missing '{f_type}' file entry")
                    else:
                        url = file_info.get("url")
                        if not url or not isinstance(url, str) or not url.startswith("http"):
                            errors.append(f"{prefix}.files.{f_type}: Invalid 'url': {url}")
                        size = file_info.get("sizeBytes")
                        if not isinstance(size, int) or size < 0:
                            errors.append(f"{prefix}.files.{f_type}: Invalid 'sizeBytes': {size}")
                        sha = file_info.get("sha256")
                        if not sha or not SHA256_REGEX.match(sha):
                            errors.append(f"{prefix}.files.{f_type}: Invalid 64-char hex 'sha256': {sha}")

    # 4. Fallback
    fallback = catalog.get("fallback")
    if not isinstance(fallback, dict) or "overview" not in fallback:
        errors.append("Missing 'fallback.overview' object")
    else:
        ov = fallback["overview"]
        if not ov.get("url") or not ov["url"].startswith("http"):
            errors.append("Invalid fallback overview URL")
        if not isinstance(ov.get("sizeBytes"), int) or ov["sizeBytes"] < 0:
            errors.append("Invalid fallback overview sizeBytes")
        if not ov.get("sha256") or not SHA256_REGEX.match(ov["sha256"]):
            errors.append("Invalid fallback overview sha256")

    return errors


def verify_local_files(catalog: dict, output_base_dir: str) -> list[str]:
    errors = []
    for r in catalog.get("regions", []):
        rid = r["id"]
        for f_type in ("map", "terrain"):
            expected = r["files"][f_type]
            expected_size = expected["sizeBytes"]
            expected_sha = expected["sha256"]
            
            local_path = os.path.join(output_base_dir, "regions", rid, f"{f_type}.pmtiles")
            if not os.path.exists(local_path):
                errors.append(f"Local file missing for region {rid} ({f_type}): {local_path}")
                continue

            info = compute_file_info(local_path)
            if info["sizeBytes"] != expected_size:
                errors.append(f"Size mismatch for {local_path}: local {info['sizeBytes']} != catalog {expected_size}")
            if info["sha256"] != expected_sha:
                errors.append(f"SHA-256 mismatch for {local_path}: local {info['sha256']} != catalog {expected_sha}")

    # Verify fallback
    fb = catalog.get("fallback", {}).get("overview")
    if fb:
        fb_path = os.path.join(output_base_dir, "fallback", "overview.pmtiles")
        if not os.path.exists(fb_path):
            errors.append(f"Local fallback file missing: {fb_path}")
        else:
            fb_info = compute_file_info(fb_path)
            if fb_info["sizeBytes"] != fb["sizeBytes"]:
                errors.append(f"Fallback size mismatch: {fb_info['sizeBytes']} != {fb['sizeBytes']}")
            if fb_info["sha256"] != fb["sha256"]:
                errors.append(f"Fallback SHA-256 mismatch: {fb_info['sha256']} != {fb['sha256']}")

    return errors


def main():
    parser = argparse.ArgumentParser(description="Validate catalog.json against BrandyFly schema")
    parser.add_argument("--catalog", default="./output/catalog.json", help="Path to catalog.json")
    parser.add_argument("--verify-local", help="Optional output base dir to verify actual file sizes and checksums")
    args = parser.parse_args()

    if not os.path.exists(args.catalog):
        print(f"Error: Catalog file not found: {args.catalog}", file=sys.stderr)
        sys.exit(1)

    with open(args.catalog, "r", encoding="utf-8") as f:
        catalog = json.load(f)

    schema_errors = validate_catalog_schema(catalog)
    if schema_errors:
        print(f"Schema validation FAILED ({len(schema_errors)} errors):", file=sys.stderr)
        for err in schema_errors:
            print(f"  - {err}", file=sys.stderr)
        sys.exit(1)

    print("Schema validation PASSED: catalog.json matches BrandyFly specifications.")

    if args.verify_local:
        local_errors = verify_local_files(catalog, args.verify_local)
        if local_errors:
            print(f"Local file integrity FAILED ({len(local_errors)} errors):", file=sys.stderr)
            for err in local_errors:
                print(f"  - {err}", file=sys.stderr)
            sys.exit(1)
        print("Local file integrity PASSED: all files exist, sizes match, and SHA-256 checksums verified.")


if __name__ == "__main__":
    main()
