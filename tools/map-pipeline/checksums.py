#!/usr/bin/env python3
"""
Computes SHA-256 checksums and file sizes for generated PMTiles archives.
"""

import argparse
import hashlib
import json
import os
import sys


def compute_sha256(filepath: str) -> str:
    sha = hashlib.sha256()
    with open(filepath, "rb") as f:
        while chunk := f.read(1024 * 1024):
            sha.update(chunk)
    return sha.hexdigest()


def compute_file_info(filepath: str) -> dict:
    if not os.path.exists(filepath):
        raise FileNotFoundError(f"File not found: {filepath}")
    
    size_bytes = os.path.getsize(filepath)
    sha256 = compute_sha256(filepath)
    return {
        "path": filepath,
        "filename": os.path.basename(filepath),
        "sizeBytes": size_bytes,
        "sha256": sha256
    }


def compute_directory_checksums(base_dir: str, output_manifest: str | None = None) -> list[dict]:
    results = []
    lines = []
    
    for root, _, files in sorted(os.walk(base_dir)):
        for file in sorted(files):
            if file.endswith(".pmtiles") or file.endswith(".json"):
                full_path = os.path.join(root, file)
                rel_path = os.path.relpath(full_path, base_dir)
                info = compute_file_info(full_path)
                info["relativePath"] = rel_path
                results.append(info)
                lines.append(f"{info['sha256']}  {rel_path}\n")

    if output_manifest:
        os.makedirs(os.path.dirname(os.path.abspath(output_manifest)), exist_ok=True)
        with open(output_manifest, "w", encoding="utf-8") as f:
            f.writelines(lines)
        print(f"Wrote SHA-256 checksums manifest to {output_manifest}")

    return results


def main():
    parser = argparse.ArgumentParser(description="Compute SHA-256 checksums for PMTiles files")
    parser.add_argument("path", help="Path to file or directory")
    parser.add_argument("--manifest", help="Optional output path for sha256sum format manifest")
    parser.add_argument("--json", action="store_true", help="Output JSON results")
    args = parser.parse_args()

    if os.path.isfile(args.path):
        info = compute_file_info(args.path)
        if args.json:
            print(json.dumps(info, indent=2))
        else:
            print(f"{info['sha256']}  {info['filename']} ({info['sizeBytes']} bytes)")
    elif os.path.isdir(args.path):
        results = compute_directory_checksums(args.path, output_manifest=args.manifest)
        if args.json:
            print(json.dumps(results, indent=2))
        else:
            for r in results:
                print(f"{r['sha256']}  {r['relativePath']} ({r['sizeBytes']} bytes)")
    else:
        print(f"Error: {args.path} does not exist", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
