#!/usr/bin/env python3
"""
Downloads Copernicus GLO-30 30m DEM GeoTIFF tiles from AWS Open Data / Copernicus
covering a region's expanded bounding box (with overlap margin).
"""

import argparse
import math
import os
import sys
import urllib.request
import urllib.error
from yaml_loader import load_yaml

COPERNICUS_AWS_BASE = "https://copernicus-dem-30m.s3.eu-central-1.amazonaws.com"


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

    return (exp_west, exp_south, exp_east, exp_north)


def format_tile_name(lat: int, lon: int) -> str:
    lat_str = f"N{lat:02d}" if lat >= 0 else f"S{abs(lat):02d}"
    lon_str = f"E{lon:03d}" if lon >= 0 else f"W{abs(lon):03d}"
    return f"Copernicus_DSM_COG_10_{lat_str}_00_{lon_str}_00_DEM"


def get_required_dem_tiles(bounds: dict, overlap_km: float) -> list[tuple[int, int]]:
    min_lon, min_lat, max_lon, max_lat = calculate_expanded_bounds(bounds, overlap_km)
    
    lat_min = int(math.floor(min_lat))
    lat_max = int(math.floor(max_lat))
    lon_min = int(math.floor(min_lon))
    lon_max = int(math.floor(max_lon))

    tiles = []
    for lat in range(lat_min, lat_max + 1):
        for lon in range(lon_min, lon_max + 1):
            tiles.append((lat, lon))
    return tiles


def download_copernicus_tile(lat: int, lon: int, output_dir: str) -> str | None:
    os.makedirs(output_dir, exist_ok=True)
    tile_name = format_tile_name(lat, lon)
    filename = f"{tile_name}.tif"
    local_path = os.path.join(output_dir, filename)

    if os.path.exists(local_path) and os.path.getsize(local_path) > 1000:
        print(f"Tile {filename} already exists. Skipping.")
        return local_path

    url = f"{COPERNICUS_AWS_BASE}/{tile_name}/{filename}"
    print(f"Downloading DEM tile: {url} -> {local_path}")
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "BrandyFly-MapPipeline/1.0"})
        with urllib.request.urlopen(req, timeout=30) as resp, open(local_path, "wb") as f:
            while chunk := resp.read(1024 * 1024):
                f.write(chunk)
        return local_path
    except urllib.error.HTTPError as e:
        if e.code == 404:
            # Ocean/sea tiles might not exist in Copernicus DEM (pure water)
            print(f"Notice: Tile {tile_name} not found on AWS (likely sea/ocean coverage).")
            if os.path.exists(local_path):
                os.remove(local_path)
            return None
        raise


def main():
    parser = argparse.ArgumentParser(description="Download Copernicus GLO-30 DEM GeoTIFF tiles for regions")
    parser.add_argument("--config", default=os.path.join(os.path.dirname(__file__), "regions.yaml"), help="Path to regions.yaml")
    parser.add_argument("--region", required=True, help="Region ID")
    parser.add_argument("--output-dir", default="./cache/dem", help="Directory to save downloaded GeoTIFFs")
    args = parser.parse_args()

    with open(args.config, "r", encoding="utf-8") as f:
        config = load_yaml(f)

    target_region = next((r for r in config.get("regions", []) if r["id"] == args.region), None)
    if not target_region:
        print(f"Error: Region '{args.region}' not found in {args.config}", file=sys.stderr)
        sys.exit(1)

    bounds = target_region["bounds"]
    overlap_km = float(target_region.get("overlapKm", 20.0))
    tiles = get_required_dem_tiles(bounds, overlap_km)

    print(f"Region {args.region}: downloading up to {len(tiles)} 1x1 DEM tile(s)...")
    region_dem_dir = os.path.join(args.output_dir, args.region)
    downloaded = 0
    for lat, lon in tiles:
        result = download_copernicus_tile(lat, lon, region_dem_dir)
        if result:
            downloaded += 1

    print(f"\nCompleted: {downloaded} DEM tiles available in {region_dem_dir}")


if __name__ == "__main__":
    main()
