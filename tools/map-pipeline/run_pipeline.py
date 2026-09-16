#!/usr/bin/env python3
"""
Orchestrator script for the BrandyFly Offline Map Pipeline.
Coordinates downloading, vector tile generation, DEM processing, fallback creation,
checksum generation, catalog validation, and CDN upload.
"""

import argparse
import os
import subprocess
import sys
from yaml_loader import load_yaml

from checksums import compute_directory_checksums
from generate_catalog import generate_catalog
from validate_catalog import validate_catalog_schema, verify_local_files


def run_pipeline(
    config_path: str,
    workdir: str,
    region_id: str | None = None,
    skip_osm: bool = False,
    skip_vector: bool = False,
    skip_dem: bool = False,
    skip_terrain: bool = False,
    skip_fallback: bool = False,
    skip_upload: bool = False,
    dry_run: bool = False,
):
    workdir = os.path.abspath(workdir)
    tools_dir = os.path.join(workdir, "tools")
    osm_cache = os.path.join(workdir, "cache", "osm")
    dem_cache = os.path.join(workdir, "cache", "dem")
    processed_dem_cache = os.path.join(workdir, "cache", "processed_dem")
    output_dir = os.path.join(workdir, "output")
    output_regions = os.path.join(output_dir, "regions")
    output_fallback = os.path.join(output_dir, "fallback")
    manifest_path = os.path.join(output_dir, "checksums.sha256")
    catalog_path = os.path.join(output_dir, "catalog.json")

    os.makedirs(tools_dir, exist_ok=True)
    os.makedirs(output_regions, exist_ok=True)
    os.makedirs(output_fallback, exist_ok=True)

    with open(config_path, "r", encoding="utf-8") as f:
        config = load_yaml(f)

    regions = config.get("regions", [])
    if region_id:
        regions = [r for r in regions if r["id"] == region_id]
        if not regions:
            print(f"Error: Region '{region_id}' not found in configuration.", file=sys.stderr)
            sys.exit(1)

    print(f"============================================================")
    print(f"BrandyFly Map Pipeline Execution")
    print(f"Target Regions: {[r['id'] for r in regions]}")
    print(f"Work Directory: {workdir}")
    print(f"Dry Run: {dry_run}")
    print(f"============================================================")

    script_dir = os.path.dirname(os.path.abspath(__file__))

    # 1. Global Fallback
    if not skip_fallback:
        print("\n--- Generating Global Fallback Overview PMTiles ---")
        fallback_out = os.path.join(output_fallback, "overview.pmtiles")
        if not dry_run:
            cmd = [sys.executable, os.path.join(script_dir, "generate_fallback.py"), "--output", fallback_out]
            subprocess.run(cmd, check=True)

    # 2. Process each region
    for r in regions:
        rid = r["id"]
        region_out_dir = os.path.join(output_regions, rid)
        os.makedirs(region_out_dir, exist_ok=True)
        print(f"\n==================== Region: {rid} ====================")

        # OSM Download & Vector Generation
        if not skip_vector:
            if not skip_osm:
                print(f"[{rid}] Downloading OSM PBF extract...")
                if not dry_run:
                    cmd = [
                        sys.executable,
                        os.path.join(script_dir, "download_osm.py"),
                        "--config", config_path,
                        "--region", rid,
                        "--output-dir", osm_cache
                    ]
                    subprocess.run(cmd, check=True)

            print(f"[{rid}] Generating vector PMTiles (zoom 0-14)...")
            map_pmtiles = os.path.join(region_out_dir, "map.pmtiles")
            if not dry_run:
                cmd = [
                    sys.executable,
                    os.path.join(script_dir, "generate_vector_tiles.py"),
                    "--config", config_path,
                    "--region", rid,
                    "--osm-dir", osm_cache,
                    "--output-dir", output_regions,
                    "--tools-dir", tools_dir
                ]
                subprocess.run(cmd, check=True)

        # DEM Download & Terrain-RGB Generation
        if not skip_terrain:
            if not skip_dem:
                print(f"[{rid}] Downloading Copernicus GLO-30 DEM tiles...")
                if not dry_run:
                    cmd = [
                        sys.executable,
                        os.path.join(script_dir, "download_dem.py"),
                        "--config", config_path,
                        "--region", rid,
                        "--output-dir", dem_cache
                    ]
                    subprocess.run(cmd, check=True)

            print(f"[{rid}] Merging and cropping DEM to region bounds (+20km overlap)...")
            cropped_dem = os.path.join(processed_dem_cache, f"{rid}_dem.tif")
            if not dry_run:
                cmd = [
                    sys.executable,
                    os.path.join(script_dir, "process_dem.py"),
                    "--config", config_path,
                    "--region", rid,
                    "--input-dir", dem_cache,
                    "--output-dir", processed_dem_cache
                ]
                subprocess.run(cmd, check=True)

            print(f"[{rid}] Encoding Terrain-RGB PMTiles (zoom 0-12)...")
            terrain_pmtiles = os.path.join(region_out_dir, "terrain.pmtiles")
            if not dry_run:
                cmd = [
                    sys.executable,
                    os.path.join(script_dir, "encode_terrain_rgb.py"),
                    "--input-tif", cropped_dem,
                    "--output-pmtiles", terrain_pmtiles,
                    "--tools-dir", tools_dir
                ]
                subprocess.run(cmd, check=True)

    # 3. Checksums and Catalog Generation
    print("\n--- Generating Checksums and Catalog ---")
    if not dry_run:
        compute_directory_checksums(output_dir, output_manifest=manifest_path)
        catalog = generate_catalog(
            config_path,
            output_dir,
            catalog_path,
            region_filter=[r["id"] for r in regions] if region_id else None
        )

        # 4. Validation
        print("\n--- Validating Catalog and Output Integrity ---")
        schema_errors = validate_catalog_schema(catalog)
        if schema_errors:
            raise ValueError(f"Catalog schema errors: {schema_errors}")

        local_errors = verify_local_files(catalog, output_dir)
        if local_errors:
            print(f"Warning: Local file checks flagged issues: {local_errors}", file=sys.stderr)
        else:
            print("Integrity check PASSED: All generated files match catalog checksums.")

    # 5. CDN Upload
    if not skip_upload and not dry_run:
        print("\n--- Uploading to Cloudflare R2 ---")
        upload_sh = os.path.join(script_dir, "upload_r2.sh")
        subprocess.run(["bash", upload_sh, output_dir], check=True)

    print("\nPipeline execution complete.")


def main():
    parser = argparse.ArgumentParser(description="BrandyFly Offline Map Pipeline Runner")
    parser.add_argument("--config", default=os.path.join(os.path.dirname(__file__), "regions.yaml"), help="Path to regions.yaml")
    parser.add_argument("--workdir", default="./map_pipeline_work", help="Working directory for cache and output")
    parser.add_argument("--region", help="Specific region ID to process (default: all)")
    parser.add_argument("--skip-osm", action="store_true", help="Skip downloading OSM extracts")
    parser.add_argument("--skip-vector", action="store_true", help="Skip vector tile generation")
    parser.add_argument("--skip-dem", action="store_true", help="Skip downloading DEM tiles")
    parser.add_argument("--skip-terrain", action="store_true", help="Skip terrain DEM processing")
    parser.add_argument("--skip-fallback", action="store_true", help="Skip fallback generation")
    parser.add_argument("--skip-upload", action="store_true", help="Skip R2 upload")
    parser.add_argument("--dry-run", action="store_true", help="Perform a dry run without downloading or processing")
    args = parser.parse_args()

    run_pipeline(
        config_path=args.config,
        workdir=args.workdir,
        region_id=args.region,
        skip_osm=args.skip_osm,
        skip_vector=args.skip_vector,
        skip_dem=args.skip_dem,
        skip_terrain=args.skip_terrain,
        skip_fallback=args.skip_fallback,
        skip_upload=args.skip_upload,
        dry_run=args.dry_run,
    )


if __name__ == "__main__":
    main()
