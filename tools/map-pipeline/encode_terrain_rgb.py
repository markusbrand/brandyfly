#!/usr/bin/env python3
"""
Encodes processed DEM GeoTIFF into Mapbox Terrain-RGB raster tiles (zoom 0-12)
using rio-rgbify and packages them into PMTiles v3 using go-pmtiles.

Elevation encoding formula:
elevation = -10000 + ((R * 65536 + G * 256 + B) * 0.1)
"""

import argparse
import os
import platform
import shutil
import subprocess
import sys
import tarfile
import urllib.request

PMTILES_VERSION = "1.20.0"


def ensure_pmtiles_cli(tools_dir: str) -> str:
    """Finds or downloads go-pmtiles binary."""
    # Check if pmtiles is in PATH
    existing = shutil.which("pmtiles")
    if existing:
        return existing

    os.makedirs(tools_dir, exist_ok=True)
    local_bin = os.path.join(tools_dir, "pmtiles")
    if os.path.exists(local_bin) and os.access(local_bin, os.X_OK):
        return local_bin

    system = platform.system()
    machine = platform.machine().lower()

    if system == "Linux":
        os_name = "Linux"
    elif system == "Darwin":
        os_name = "Darwin"
    else:
        os_name = "Linux"

    if machine in ("x86_64", "amd64"):
        arch_name = "x86_64"
    elif machine in ("arm64", "aarch64"):
        arch_name = "arm64"
    else:
        arch_name = "x86_64"

    archive_url = (
        f"https://github.com/protomaps/go-pmtiles/releases/download/v{PMTILES_VERSION}/"
        f"go-pmtiles_{PMTILES_VERSION}_{os_name}_{arch_name}.tar.gz"
    )

    tar_path = os.path.join(tools_dir, f"go-pmtiles_{PMTILES_VERSION}.tar.gz")
    print(f"Downloading go-pmtiles from {archive_url}...")
    try:
        req = urllib.request.Request(archive_url, headers={"User-Agent": "BrandyFly-MapPipeline/1.0"})
        with urllib.request.urlopen(req, timeout=30) as resp, open(tar_path, "wb") as f:
            while chunk := resp.read(1024 * 1024):
                f.write(chunk)

        with tarfile.open(tar_path, "r:gz") as tar:
            for member in tar.getmembers():
                if member.name == "pmtiles" or member.name.endswith("/pmtiles"):
                    member.name = "pmtiles"
                    tar.extract(member, path=tools_dir)
                    break

        os.chmod(local_bin, 0o755)
        if os.path.exists(tar_path):
            os.remove(tar_path)
        print(f"pmtiles CLI installed to {local_bin}")
        return local_bin
    except Exception as e:
        print(f"Warning: Could not auto-download pmtiles CLI: {e}", file=sys.stderr)
        return "pmtiles"


def encode_terrain_rgb(input_tif: str, output_pmtiles: str, tools_dir: str, min_zoom: int = 0, max_zoom: int = 12):
    os.makedirs(os.path.dirname(output_pmtiles), exist_ok=True)
    temp_mbtiles = output_pmtiles + ".tmp.mbtiles"

    print(f"\n==========================================")
    print(f"Encoding Terrain-RGB DEM")
    print(f"Input DEM: {input_tif}")
    print(f"Zoom range: {min_zoom} - {max_zoom}")
    print(f"Output PMTiles: {output_pmtiles}")
    print(f"==========================================")

    # Step 1: Run rio rgbify
    # Formula: elevation = -10000 + (val * 0.1) -> base=-10000, interval=0.1
    rgbify_cmd = [
        "rio", "rgbify",
        "-b", "-10000",
        "-i", "0.1",
        "--min-z", str(min_zoom),
        "--max-z", str(max_zoom),
        "--format", "png",
        input_tif,
        temp_mbtiles
    ]
    print(f"Executing: {' '.join(rgbify_cmd)}")
    res = subprocess.run(rgbify_cmd)
    if res.returncode != 0:
        raise RuntimeError(f"rio rgbify failed with code {res.returncode}")

    # Step 2: Convert MBTiles to PMTiles using pmtiles CLI
    pmtiles_bin = ensure_pmtiles_cli(tools_dir)
    convert_cmd = [pmtiles_bin, "convert", temp_mbtiles, output_pmtiles]
    print(f"Executing: {' '.join(convert_cmd)}")
    res = subprocess.run(convert_cmd)
    if res.returncode != 0:
        raise RuntimeError(f"pmtiles convert failed with code {res.returncode}")

    # Step 3: Remove intermediate MBTiles
    if os.path.exists(temp_mbtiles):
        os.remove(temp_mbtiles)

    print(f"Successfully generated terrain PMTiles: {output_pmtiles} ({os.path.getsize(output_pmtiles) / (1024*1024):.2f} MB)")


def main():
    parser = argparse.ArgumentParser(description="Encode DEM as Terrain-RGB PMTiles")
    parser.add_argument("--input-tif", required=True, help="Input cropped DEM GeoTIFF")
    parser.add_argument("--output-pmtiles", required=True, help="Output terrain.pmtiles path")
    parser.add_argument("--tools-dir", default="./cache/tools", help="Tools directory for pmtiles binary")
    parser.add_argument("--min-zoom", type=int, default=0, help="Min zoom (default: 0)")
    parser.add_argument("--max-zoom", type=int, default=12, help="Max zoom (default: 12)")
    args = parser.parse_args()

    encode_terrain_rgb(args.input_tif, args.output_pmtiles, args.tools_dir, args.min_zoom, args.max_zoom)


if __name__ == "__main__":
    main()
