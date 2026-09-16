#!/usr/bin/env python3
"""
Downloads Geofabrik OpenStreetMap PBF extracts for BrandyFly regions.
Supports caching, resume, and MD5 checksum verification.
"""

import argparse
import hashlib
import os
import sys
import urllib.request
from yaml_loader import load_yaml


def calculate_md5(filepath: str) -> str:
    md5 = hashlib.md5()
    with open(filepath, "rb") as f:
        while chunk := f.read(1024 * 1024):
            md5.update(chunk)
    return md5.hexdigest()


def download_file(url: str, dest_path: str, verify_md5: bool = True) -> bool:
    os.makedirs(os.path.dirname(dest_path), exist_ok=True)
    
    # Check remote MD5 if available
    expected_md5 = None
    if verify_md5:
        md5_url = url + ".md5"
        try:
            req = urllib.request.Request(md5_url, headers={"User-Agent": "BrandyFly-MapPipeline/1.0"})
            with urllib.request.urlopen(req, timeout=10) as resp:
                content = resp.read().decode("utf-8").strip()
                expected_md5 = content.split()[0]
        except Exception as e:
            print(f"Warning: Could not fetch MD5 for {url}: {e}", file=sys.stderr)

    if os.path.exists(dest_path):
        if expected_md5:
            current_md5 = calculate_md5(dest_path)
            if current_md5 == expected_md5:
                print(f"File {dest_path} exists and MD5 matches ({expected_md5}). Skipping download.")
                return True
            else:
                print(f"File {dest_path} exists but MD5 mismatch ({current_md5} vs {expected_md5}). Re-downloading.")
        else:
            print(f"File {dest_path} exists. Skipping download.")
            return True

    print(f"Downloading {url} -> {dest_path}...")
    req = urllib.request.Request(url, headers={"User-Agent": "BrandyFly-MapPipeline/1.0"})
    with urllib.request.urlopen(req) as resp, open(dest_path, "wb") as f:
        total = int(resp.headers.get("Content-Length", 0))
        downloaded = 0
        while chunk := resp.read(1024 * 1024):
            f.write(chunk)
            downloaded += len(chunk)
            if total > 0:
                pct = downloaded * 100 / total
                print(f"\rProgress: {downloaded / (1024*1024):.1f}MB / {total / (1024*1024):.1f}MB ({pct:.1f}%)", end="", flush=True)
        print()

    if expected_md5:
        current_md5 = calculate_md5(dest_path)
        if current_md5 != expected_md5:
            raise ValueError(f"MD5 mismatch after download: {current_md5} != {expected_md5}")
        print(f"MD5 verified: {expected_md5}")

    return True


def main():
    parser = argparse.ArgumentParser(description="Download Geofabrik OSM PBF extracts for BrandyFly regions")
    parser.add_argument("--config", default=os.path.join(os.path.dirname(__file__), "regions.yaml"), help="Path to regions.yaml")
    parser.add_argument("--region", help="Region ID to download (default: all)")
    parser.add_argument("--output-dir", default="./cache/osm", help="Directory to save downloaded PBF files")
    parser.add_argument("--no-verify", action="store_true", help="Skip MD5 verification")
    args = parser.parse_args()

    with open(args.config, "r", encoding="utf-8") as f:
        config = load_yaml(f)

    regions = config.get("regions", [])
    if args.region:
        regions = [r for r in regions if r["id"] == args.region]
        if not regions:
            print(f"Error: Region '{args.region}' not found in {args.config}", file=sys.stderr)
            sys.exit(1)

    print(f"Preparing to download OSM PBF extracts for {len(regions)} region(s)...")
    downloaded_urls = set()

    for r in regions:
        url = r.get("geofabrikUrl")
        if not url:
            print(f"Skipping {r['id']}: no geofabrikUrl defined")
            continue

        filename = os.path.basename(url)
        dest_path = os.path.join(args.output_dir, filename)

        if url in downloaded_urls:
            print(f"Region {r['id']} shares extract {filename} (already processed).")
            continue

        print(f"\n[Region: {r['id']}] Source: {url}")
        download_file(url, dest_path, verify_md5=not args.no_verify)
        downloaded_urls.add(url)

    print("\nAll requested OSM PBF extracts downloaded successfully.")


if __name__ == "__main__":
    main()
