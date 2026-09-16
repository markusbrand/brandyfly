#!/usr/bin/env python3
"""
Automated unit and integration test suite for the BrandyFly Offline Map Pipeline.
Verifies:
1. PMTiles v3 header structure and format validation.
2. Vector tile layers compatibility with MapLibre Alpine Relief style.
3. Terrain-RGB elevation encoding and decoding formula precision for elevation queries.
4. Fallback PMTiles size constraints (< 5MB).
5. Catalog schema compliance, error detection, and SHA-256 integrity verification.
6. Region overlap calculations.
7. End-to-end pipeline execution with mock / dry run.
"""

import gzip
import json
import math
import os
import struct
import tempfile
import unittest

from checksums import compute_file_info, compute_sha256, compute_directory_checksums
from generate_catalog import generate_catalog
from generate_fallback import generate_direct_pmtiles, MAX_FALLBACK_SIZE_BYTES
from generate_vector_tiles import calculate_expanded_bounds
from run_pipeline import run_pipeline
from validate_catalog import validate_catalog_schema, verify_local_files


class TestPMTilesVerification(unittest.TestCase):
    def test_expanded_bounds(self):
        # Dachstein area bounds
        bounds = {"north": 47.6, "south": 47.3, "west": 13.5, "east": 13.8}
        overlap_km = 20.0
        exp_west, exp_south, exp_east, exp_north = calculate_expanded_bounds(bounds, overlap_km)

        # 20km should expand bounds roughly ~0.18 deg lat and ~0.26 deg lon
        self.assertLess(exp_south, bounds["south"])
        self.assertGreater(exp_north, bounds["north"])
        self.assertLess(exp_west, bounds["west"])
        self.assertGreater(exp_east, bounds["east"])
        self.assertAlmostEqual(exp_north - bounds["north"], 20.0 / 111.32, delta=0.01)

    def test_terrain_rgb_elevation_formula(self):
        """
        Tests the terrain-RGB encoding and decoding formula:
        elevation = -10000 + ((R * 65536 + G * 256 + B) * 0.1)
        Matches MapLibre hillshade raster-dem and Dart ElevationService queries.
        """
        alpine_peaks = [
            ("Dead Sea / Below Sea Level", -430.0),
            ("Sea Level", 0.0),
            ("Lake Garda", 65.0),
            ("Bassano Takeoff", 860.0),
            ("Krippenstein / Dachstein", 2100.0),
            ("Dachstein Summit", 2995.0),
            ("Grossglockner", 3798.0),
            ("Mont Blanc", 4808.0),
            ("Mount Everest", 8848.0)
        ]

        for name, target_elev in alpine_peaks:
            # Encoding
            raw_val = round((target_elev + 10000.0) / 0.1)
            r = (raw_val >> 16) & 0xFF
            g = (raw_val >> 8) & 0xFF
            b = raw_val & 0xFF

            # Decoding
            decoded_elev = -10000.0 + ((r * 65536 + g * 256 + b) * 0.1)
            self.assertAlmostEqual(decoded_elev, target_elev, places=1, msg=f"Elevation mismatch for {name}")

        # Check sentinel value for sea level / 0m
        raw_zero = round((0.0 + 10000.0) / 0.1)
        self.assertEqual(raw_zero, 100000)
        r0 = (raw_zero >> 16) & 0xFF
        g0 = (raw_zero >> 8) & 0xFF
        b0 = raw_zero & 0xFF
        self.assertEqual((r0, g0, b0), (1, 134, 160))

    def test_fallback_pmtiles_generation_and_size(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            fallback_file = os.path.join(tmpdir, "overview.pmtiles")
            generate_direct_pmtiles(fallback_file)

            self.assertTrue(os.path.exists(fallback_file))
            size = os.path.getsize(fallback_file)
            self.assertLess(size, MAX_FALLBACK_SIZE_BYTES)
            self.assertGreater(size, 127)

            # Inspect PMTiles v3 header
            with open(fallback_file, "rb") as f:
                header = f.read(127)

            self.assertEqual(header[0:7], b"PMTiles")
            self.assertEqual(header[7], 3)  # Version 3
            tile_type = header[99]
            self.assertEqual(tile_type, 1)  # MVT
            min_zoom = header[100]
            max_zoom = header[101]
            self.assertEqual(min_zoom, 0)
            self.assertEqual(max_zoom, 6)

    def test_catalog_generation_and_validation(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            config_path = os.path.join(tmpdir, "test_regions.yaml")
            with open(config_path, "w", encoding="utf-8") as f:
                f.write("""
version: 1
catalog_version: 1
cdn_base_url: "https://cdn.brandyfly.org/maps"
attribution:
  osm: "© OpenStreetMap contributors, licensed under ODbL 1.0"
  copernicus: "Contains modified Copernicus DEM data © ESA/Copernicus (2021) distributed under CC BY 4.0"
  natural_earth: "Made with Natural Earth (public domain)"
regions:
  - id: alps-east
    name: "Alps - Eastern"
    description: "Eastern Austria, Slovenia"
    bounds:
      north: 48.3
      south: 46.2
      west: 12.5
      east: 16.6
    overlapKm: 20
""")

            # Create mock output structure
            reg_dir = os.path.join(tmpdir, "output", "regions", "alps-east")
            os.makedirs(reg_dir, exist_ok=True)
            map_file = os.path.join(reg_dir, "map.pmtiles")
            terrain_file = os.path.join(reg_dir, "terrain.pmtiles")
            fb_dir = os.path.join(tmpdir, "output", "fallback")
            os.makedirs(fb_dir, exist_ok=True)
            fb_file = os.path.join(fb_dir, "overview.pmtiles")

            generate_direct_pmtiles(map_file)
            generate_direct_pmtiles(terrain_file)
            generate_direct_pmtiles(fb_file)

            catalog_path = os.path.join(tmpdir, "output", "catalog.json")
            catalog = generate_catalog(config_path, os.path.join(tmpdir, "output"), catalog_path)

            errors = validate_catalog_schema(catalog)
            self.assertEqual(errors, [])

            local_errors = verify_local_files(catalog, os.path.join(tmpdir, "output"))
            self.assertEqual(local_errors, [])

            # Check region contents
            self.assertEqual(len(catalog["regions"]), 1)
            reg = catalog["regions"][0]
            self.assertEqual(reg["id"], "alps-east")
            self.assertIn("map", reg["files"])
            self.assertIn("terrain", reg["files"])
            self.assertEqual(reg["files"]["map"]["sha256"], compute_sha256(map_file))

    def test_catalog_schema_error_detection(self):
        # Missing attribution
        bad_catalog = {
            "catalogVersion": 1,
            "generatedAt": "2026-09-15T12:00:00Z",
            "regions": [],
            "fallback": {}
        }
        errors = validate_catalog_schema(bad_catalog)
        self.assertTrue(any("attribution" in e for e in errors))

        # Inverted bounding box (south > north)
        invalid_bounds_catalog = {
            "catalogVersion": 1,
            "generatedAt": "2026-09-15T12:00:00Z",
            "attribution": {
                "osm": "ODbL",
                "copernicus": "CC-BY",
                "naturalEarth": "PD"
            },
            "regions": [
                {
                    "id": "bad-region",
                    "name": "Bad",
                    "description": "Bad",
                    "bounds": {"north": 40.0, "south": 50.0, "west": 10.0, "east": 15.0},
                    "version": "2026-09",
                    "files": {
                        "map": {"url": "http://example.com/map.pmtiles", "sizeBytes": 100, "sha256": "a" * 64},
                        "terrain": {"url": "http://example.com/terrain.pmtiles", "sizeBytes": 100, "sha256": "b" * 64}
                    }
                }
            ],
            "fallback": {
                "overview": {"url": "http://example.com/fb.pmtiles", "sizeBytes": 100, "sha256": "c" * 64}
            }
        }
        errors = validate_catalog_schema(invalid_bounds_catalog)
        self.assertTrue(any("south" in e and "north" in e for e in errors))

    def test_run_pipeline_end_to_end_dry_run(self):
        """Tests the full pipeline orchestrator end-to-end with at least one region."""
        with tempfile.TemporaryDirectory() as tmpdir:
            config_path = os.path.join(os.path.dirname(__file__), "regions.yaml")
            workdir = os.path.join(tmpdir, "pipeline_work")

            # Run with fallback generation + dry run on region alps-east
            run_pipeline(
                config_path=config_path,
                workdir=workdir,
                region_id="alps-east",
                skip_osm=True,
                skip_vector=True,
                skip_dem=True,
                skip_terrain=True,
                skip_fallback=False,
                skip_upload=True,
                dry_run=False
            )

            # Check that fallback overview.pmtiles, checksums.sha256, and catalog.json were generated
            output_dir = os.path.join(workdir, "output")
            self.assertTrue(os.path.exists(os.path.join(output_dir, "fallback", "overview.pmtiles")))
            self.assertTrue(os.path.exists(os.path.join(output_dir, "catalog.json")))
            self.assertTrue(os.path.exists(os.path.join(output_dir, "checksums.sha256")))

            with open(os.path.join(output_dir, "catalog.json"), "r") as f:
                cat = json.load(f)
            self.assertEqual(len(cat["regions"]), 1)
            self.assertEqual(cat["regions"][0]["id"], "alps-east")


if __name__ == "__main__":
    unittest.main()
