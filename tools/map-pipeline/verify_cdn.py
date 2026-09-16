#!/usr/bin/env python3
"""
Verifies that published PMTiles files and catalog.json are accessible via anonymous HTTPS GET
requests with proper HTTP headers (e.g. Accept-Ranges for PMTiles partial reading).
"""

import argparse
import json
import sys
import urllib.request
import urllib.error


def check_url(url: str, expected_size: int | None = None, check_range: bool = True) -> tuple[bool, str]:
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "BrandyFly-CDN-Verifier/1.0"}, method="HEAD")
        with urllib.request.urlopen(req, timeout=15) as resp:
            status = resp.status
            headers = resp.headers
            content_length = int(headers.get("Content-Length", -1))
            accept_ranges = headers.get("Accept-Ranges", "")

            if status not in (200, 204):
                return False, f"Unexpected status {status}"

            if expected_size is not None and expected_size > 0:
                if content_length != -1 and content_length != expected_size:
                    return False, f"Content-Length mismatch: {content_length} != expected {expected_size}"

            if check_range and "bytes" not in accept_ranges.lower():
                # Perform a test 1-byte Range request to be certain
                range_req = urllib.request.Request(
                    url,
                    headers={"User-Agent": "BrandyFly-CDN-Verifier/1.0", "Range": "bytes=0-0"}
                )
                try:
                    with urllib.request.urlopen(range_req, timeout=10) as r_resp:
                        if r_resp.status != 206:
                            return False, f"Range request failed (HTTP {r_resp.status}, expected 206)"
                except Exception as e:
                    return False, f"Range request error: {e}"

            return True, f"OK ({content_length} bytes, Accept-Ranges: {accept_ranges or 'verified'})"
    except urllib.error.HTTPError as e:
        return False, f"HTTP Error {e.code}: {e.reason}"
    except Exception as e:
        return False, f"Connection failed: {e}"


def verify_catalog_cdn(catalog_path_or_url: str) -> bool:
    print(f"Loading catalog: {catalog_path_or_url}...")
    if catalog_path_or_url.startswith("http://") or catalog_path_or_url.startswith("https://"):
        req = urllib.request.Request(catalog_path_or_url, headers={"User-Agent": "BrandyFly-CDN-Verifier/1.0"})
        with urllib.request.urlopen(req, timeout=15) as resp:
            catalog = json.loads(resp.read().decode("utf-8"))
    else:
        with open(catalog_path_or_url, "r", encoding="utf-8") as f:
            catalog = json.load(f)

    all_passed = True
    urls_to_check = []

    for r in catalog.get("regions", []):
        rid = r["id"]
        for f_type in ("map", "terrain"):
            f_meta = r["files"].get(f_type, {})
            url = f_meta.get("url")
            size = f_meta.get("sizeBytes", 0)
            if url:
                urls_to_check.append((f"{rid}/{f_type}", url, size))

    fb = catalog.get("fallback", {}).get("overview", {})
    if fb.get("url"):
        urls_to_check.append(("fallback/overview", fb["url"], fb.get("sizeBytes", 0)))

    print(f"\nVerifying {len(urls_to_check)} CDN endpoints via anonymous HTTPS GET/HEAD...")
    for label, url, size in urls_to_check:
        passed, msg = check_url(url, expected_size=size)
        symbol = "✓" if passed else "✗"
        print(f"[{symbol}] {label}: {url} -> {msg}")
        if not passed:
            all_passed = False

    return all_passed


def main():
    parser = argparse.ArgumentParser(description="Verify CDN endpoints for BrandyFly maps")
    parser.add_argument("catalog", help="Path or URL to catalog.json")
    args = parser.parse_args()

    success = verify_catalog_cdn(args.catalog)
    if not success:
        print("\nVerification FAILED: One or more CDN URLs were inaccessible or invalid.", file=sys.stderr)
        sys.exit(1)

    print("\nVerification PASSED: All CDN URLs accessible anonymously with valid byte ranges.")


if __name__ == "__main__":
    main()
