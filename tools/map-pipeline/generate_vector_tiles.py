#!/usr/bin/env python3
"""
Runs Planetiler with OpenMapTiles profile to generate vector tile PMTiles (zoom 0-14)
for a region, clipped to region bbox + overlap margin.
"""

import argparse
import math
import os
import subprocess
import sys
import urllib.request
from yaml_loader import load_yaml

PLANETILER_VERSION = "0.8.4"
PLANETILER_JAR_URL = f"https://github.com/onthegomap/planetiler/releases/download/v{PLANETILER_VERSION}/planetiler.jar"


def calculate_expanded_bounds(bounds: dict, overlap_km: float) -> tuple[float, float, float, float]:
    """
    Expands bounding box by overlap_km to ensure seamless paragliding XC rendering at boundaries.
    Returns (min_lon, min_lat, max_lon, max_lat).
    """
    north = float(bounds["north"])
    south = float(bounds["south"])
    west = float(bounds["west"])
    east = float(bounds["east"])

    mid_lat = (north + south) / 2.0
    lat_deg_km = 111.32
    lon_deg_km = 111.32 * math.cos(math.radians(mid_lat))
    if lon_deg_km <= 0:
        lon_deg_km = 111.32

    delta_lat = overlap_km / lat_deg_km
    delta_lon = overlap_km / lon_deg_km

    exp_south = max(-85.05112878, south - delta_lat)
    exp_north = min(85.05112878, north + delta_lat)
    exp_west = max(-180.0, west - delta_lon)
    exp_east = min(180.0, east + delta_lon)

    return (round(exp_west, 4), round(exp_south, 4), round(exp_east, 4), round(exp_north, 4))


def ensure_planetiler_jar(target_dir: str) -> str:
    jar_path = os.path.join(target_dir, f"planetiler-{PLANETILER_VERSION}.jar")
    if os.path.exists(jar_path) and os.path.getsize(jar_path) > 1000000:
        return jar_path

    os.makedirs(target_dir, exist_ok=True)
    print(f"Downloading Planetiler v{PLANETILER_VERSION} from {PLANETILER_JAR_URL}...")
    req = urllib.request.Request(PLANETILER_JAR_URL, headers={"User-Agent": "BrandyFly-MapPipeline/1.0"})
    with urllib.request.urlopen(req) as resp, open(jar_path, "wb") as f:
        while chunk := resp.read(1024 * 1024):
            f.write(chunk)
    print(f"Downloaded Planetiler jar to {jar_path}")
    return jar_path


def generate_region_vector_tiles(region: dict, osm_pbf_path: str, output_pmtiles: str, tools_dir: str, memory: str = "4g"):
    os.makedirs(os.path.dirname(output_pmtiles), exist_ok=True)
    bounds = region["bounds"]
    overlap_km = float(region.get("overlapKm", 20.0))
    min_lon, min_lat, max_lon, max_lat = calculate_expanded_bounds(bounds, overlap_km)

    jar_path = ensure_planetiler_jar(tools_dir)

    print(f"\n==========================================")
    print(f"Generating Vector PMTiles for: {region['id']}")
    print(f"Nominal bounds: {bounds}")
    print(f"Expanded bounds (+{overlap_km} km): [{min_lon}, {min_lat}, {max_lon}, {max_lat}]")
    print(f"Input OSM PBF: {osm_pbf_path}")
    print(f"Output PMTiles: {output_pmtiles}")
    print(f"==========================================")

    bounds_arg = f"{min_lon},{min_lat},{max_lon},{max_lat}"

    cmd = [
        "java",
        f"-Xmx{memory}",
        "-jar",
        jar_path,
        f"--osm-path={osm_pbf_path}",
        f"--output={output_pmtiles}",
        f"--bounds={bounds_arg}",
        "--minzoom=0",
        "--maxzoom=14",
        "--noderefs=sparse",
        "--storage=ram",
    ]

    print(f"Executing: {' '.join(cmd)}")
    result = subprocess.run(cmd)
    if result.returncode != 0:
        raise RuntimeError(f"Planetiler failed with exit code {result.returncode}")

    print(f"Successfully generated {output_pmtiles} ({os.path.getsize(output_pmtiles) / (1024*1024):.2f} MB)")


def main():
    parser = argparse.ArgumentParser(description="Generate OpenMapTiles vector PMTiles for regions")
    parser.add_argument("--config", default=os.path.join(os.path.dirname(__file__), "regions.yaml"), help="Path to regions.yaml")
    parser.add_argument("--region", required=True, help="Region ID to generate")
    parser.add_argument("--osm-dir", default="./cache/osm", help="Directory containing downloaded OSM PBF extracts")
    parser.add_argument("--output-dir", default="./output/regions", help="Base output directory")
    parser.add_argument("--tools-dir", default="./cache/tools", help="Directory to cache Planetiler jar")
    parser.add_argument("--memory", default="4g", help="JVM heap allocation (e.g. 4g, 8g)")
    args = parser.parse_args()

    with open(args.config, "r", encoding="utf-8") as f:
        config = load_yaml(f)

    target_region = None
    for r in config.get("regions", []):
        if r["id"] == args.region:
            target_region = r
            break

    if not target_region:
        print(f"Error: Region '{args.region}' not found in {args.config}", file=sys.stderr)
        sys.exit(1)

    pbf_filename = os.path.basename(target_region["geofabrikUrl"])
    osm_pbf_path = os.path.join(args.osm_dir, pbf_filename)

    if not os.path.exists(osm_pbf_path):
        print(f"Error: OSM PBF file not found: {osm_pbf_path}", file=sys.stderr)
        print("Please run download_osm.py first.", file=sys.stderr)
        sys.exit(1)

    out_file = os.path.join(args.output_dir, target_region["id"], "map.pmtiles")
    generate_region_vector_tiles(target_region, osm_pbf_path, out_file, args.tools_dir, memory=args.memory)


if __name__ == "__main__":
    main()
