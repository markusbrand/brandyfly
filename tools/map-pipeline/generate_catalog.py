#!/usr/bin/env python3
"""
Generates catalog.json containing metadata, bounding boxes, file URLs, sizes,
SHA-256 checksums, and dataset attributions for all regions and global fallback.
"""

import argparse
from datetime import datetime, timezone
import json
import os
import sys
from yaml_loader import load_yaml

from checksums import compute_file_info


def generate_catalog(config_path: str, output_base_dir: str, catalog_output_path: str, cdn_url_override: str | None = None, region_filter: list[str] | None = None) -> dict:
    with open(config_path, "r", encoding="utf-8") as f:
        config = load_yaml(f)

    cdn_base = cdn_url_override or config.get("cdn_base_url", "https://cdn.brandyfly.org/maps").rstrip("/")
    now = datetime.now(timezone.utc)
    current_version = now.strftime("%Y-%m")
    iso_now = now.isoformat()

    catalog = {
        "catalogVersion": int(config.get("catalog_version", 1)),
        "generatedAt": iso_now,
        "attribution": {
            "osm": config.get("attribution", {}).get("osm", "© OpenStreetMap contributors, licensed under ODbL 1.0"),
            "copernicus": config.get("attribution", {}).get("copernicus", "Contains modified Copernicus DEM data © ESA/Copernicus (2021) distributed under CC BY 4.0"),
            "naturalEarth": config.get("attribution", {}).get("natural_earth", "Made with Natural Earth. Free vector and raster map data @ naturalearthdata.com (public domain)")
        },
        "regions": []
    }

    # Process regions
    regions_dir = os.path.join(output_base_dir, "regions")
    target_regions = config.get("regions", [])
    if region_filter:
        target_regions = [r for r in target_regions if r["id"] in region_filter]

    for r in target_regions:
        region_id = r["id"]
        region_path = os.path.join(regions_dir, region_id)
        map_file = os.path.join(region_path, "map.pmtiles")
        terrain_file = os.path.join(region_path, "terrain.pmtiles")

        files_meta = {}
        if os.path.exists(map_file):
            map_info = compute_file_info(map_file)
            files_meta["map"] = {
                "url": f"{cdn_base}/regions/{region_id}/map.pmtiles",
                "sizeBytes": map_info["sizeBytes"],
                "sha256": map_info["sha256"]
            }
        else:
            print(f"Notice: {map_file} does not exist yet (placeholder metadata used)")
            files_meta["map"] = {
                "url": f"{cdn_base}/regions/{region_id}/map.pmtiles",
                "sizeBytes": 0,
                "sha256": "0" * 64
            }

        if os.path.exists(terrain_file):
            terrain_info = compute_file_info(terrain_file)
            files_meta["terrain"] = {
                "url": f"{cdn_base}/regions/{region_id}/terrain.pmtiles",
                "sizeBytes": terrain_info["sizeBytes"],
                "sha256": terrain_info["sha256"]
            }
        else:
            print(f"Notice: {terrain_file} does not exist yet (placeholder metadata used)")
            files_meta["terrain"] = {
                "url": f"{cdn_base}/regions/{region_id}/terrain.pmtiles",
                "sizeBytes": 0,
                "sha256": "0" * 64
            }

        catalog["regions"].append({
            "id": region_id,
            "name": r["name"],
            "description": r["description"],
            "bounds": {
                "north": float(r["bounds"]["north"]),
                "south": float(r["bounds"]["south"]),
                "west": float(r["bounds"]["west"]),
                "east": float(r["bounds"]["east"])
            },
            "version": current_version,
            "generatedAt": iso_now,
            "files": files_meta
        })

    # Process fallback
    fallback_file = os.path.join(output_base_dir, "fallback", "overview.pmtiles")
    if os.path.exists(fallback_file):
        fb_info = compute_file_info(fallback_file)
        catalog["fallback"] = {
            "overview": {
                "url": f"{cdn_base}/fallback/overview.pmtiles",
                "sizeBytes": fb_info["sizeBytes"],
                "sha256": fb_info["sha256"]
            }
        }
    else:
        catalog["fallback"] = {
            "overview": {
                "url": f"{cdn_base}/fallback/overview.pmtiles",
                "sizeBytes": 0,
                "sha256": "0" * 64
            }
        }

    os.makedirs(os.path.dirname(os.path.abspath(catalog_output_path)), exist_ok=True)
    with open(catalog_output_path, "w", encoding="utf-8") as f:
        json.dump(catalog, f, indent=2)

    print(f"Generated catalog.json with {len(catalog['regions'])} regions: {catalog_output_path}")
    return catalog


def main():
    parser = argparse.ArgumentParser(description="Generate catalog.json for BrandyFly offline maps")
    parser.add_argument("--config", default=os.path.join(os.path.dirname(__file__), "regions.yaml"), help="Path to regions.yaml")
    parser.add_argument("--output-dir", default="./output", help="Directory containing generated regions/ and fallback/")
    parser.add_argument("--catalog-output", default="./output/catalog.json", help="Path to write catalog.json")
    parser.add_argument("--cdn-url", help="Override CDN base URL")
    parser.add_argument("--region", help="Optional specific region ID to include")
    args = parser.parse_args()

    reg_filter = [args.region] if args.region else None
    generate_catalog(args.config, args.output_dir, args.catalog_output, cdn_url_override=args.cdn_url, region_filter=reg_filter)


if __name__ == "__main__":
    main()
