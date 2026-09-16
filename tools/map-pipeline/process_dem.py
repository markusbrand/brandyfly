#!/usr/bin/env python3
"""
Merges and crops Copernicus GLO-30 DEM GeoTIFF tiles to a region's expanded bounding box
(nominal bbox + overlap margin). Gaps and no-data pixels are filled with 0 (sea level).
"""

import argparse
import glob
import math
import os
import subprocess
import sys
from yaml_loader import load_yaml


def calculate_expanded_bounds(bounds: dict, overlap_km: float) -> tuple[float, float, float, float]:
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

    return (round(exp_west, 6), round(exp_south, 6), round(exp_east, 6), round(exp_north, 6))


def process_region_dem(region: dict, dem_input_dir: str, output_tif: str):
    os.makedirs(os.path.dirname(output_tif), exist_ok=True)
    bounds = region["bounds"]
    overlap_km = float(region.get("overlapKm", 20.0))
    min_lon, min_lat, max_lon, max_lat = calculate_expanded_bounds(bounds, overlap_km)

    tif_files = glob.glob(os.path.join(dem_input_dir, "*.tif"))
    if not tif_files:
        raise FileNotFoundError(f"No GeoTIFF tiles found in {dem_input_dir}")

    print(f"\nProcessing DEM for {region['id']}:")
    print(f"Input tiles: {len(tif_files)}")
    print(f"Target extent: [{min_lon}, {min_lat}, {max_lon}, {max_lat}]")
    print(f"Output TIF: {output_tif}")

    vrt_file = output_tif + ".vrt"

    # Step 1: Build virtual raster
    vrt_cmd = ["gdalbuildvrt", "-resolution", "highest", "-srcnodata", "-32767", vrt_file] + tif_files
    print(f"Executing: gdalbuildvrt -> {vrt_file}")
    res = subprocess.run(vrt_cmd, capture_output=True, text=True)
    if res.returncode != 0:
        raise RuntimeError(f"gdalbuildvrt failed: {res.stderr}")

    # Step 2: Warp and crop to exact extent with sentinel fill 0m
    # -te <xmin> <ymin> <xmax> <ymax>
    warp_cmd = [
        "gdalwarp",
        "-te", str(min_lon), str(min_lat), str(max_lon), str(max_lat),
        "-t_srs", "EPSG:4326",
        "-r", "bilinear",
        "-dstnodata", "0",
        "-co", "COMPRESS=DEFLATE",
        "-co", "PREDICTOR=2",
        "-co", "TILED=YES",
        vrt_file,
        output_tif,
        "-overwrite"
    ]
    print(f"Executing: gdalwarp -> {output_tif}")
    res = subprocess.run(warp_cmd, capture_output=True, text=True)
    if res.returncode != 0:
        raise RuntimeError(f"gdalwarp failed: {res.stderr}")

    # Clean up intermediate VRT
    if os.path.exists(vrt_file):
        os.remove(vrt_file)

    print(f"Processed DEM successfully created: {output_tif} ({os.path.getsize(output_tif) / (1024*1024):.2f} MB)")


def main():
    parser = argparse.ArgumentParser(description="Merge and crop DEM tiles with GDAL")
    parser.add_argument("--config", default=os.path.join(os.path.dirname(__file__), "regions.yaml"), help="Path to regions.yaml")
    parser.add_argument("--region", required=True, help="Region ID")
    parser.add_argument("--input-dir", default="./cache/dem", help="Directory containing raw DEM tiles")
    parser.add_argument("--output-dir", default="./cache/processed_dem", help="Directory for cropped GeoTIFF")
    args = parser.parse_args()

    with open(args.config, "r", encoding="utf-8") as f:
        config = load_yaml(f)

    target_region = next((r for r in config.get("regions", []) if r["id"] == args.region), None)
    if not target_region:
        print(f"Error: Region '{args.region}' not found in {args.config}", file=sys.stderr)
        sys.exit(1)

    dem_dir = os.path.join(args.input_dir, args.region)
    out_tif = os.path.join(args.output_dir, f"{args.region}_dem.tif")
    process_region_dem(target_region, dem_dir, out_tif)


if __name__ == "__main__":
    main()
