"""
Lightweight YAML loader with fallback when pyyaml is not installed.
Handles basic YAML mapping, lists, comments, and strings.
"""

import json
import re

try:
    import yaml
    def load_yaml(content_or_file):
        if hasattr(content_or_file, "read"):
            return yaml.safe_load(content_or_file)
        if isinstance(content_or_file, str) and "\n" not in content_or_file and content_or_file.endswith((".yaml", ".yml")):
            with open(content_or_file, "r", encoding="utf-8") as f:
                return yaml.safe_load(f)
        return yaml.safe_load(content_or_file)
except ImportError:
    def parse_simple_yaml(text: str) -> dict:
        """Fallback line-based YAML parser for regions.yaml structure."""
        lines = text.splitlines()
        root = {}
        current_region = None
        in_regions = False
        in_bounds = False
        in_attr = False
        in_fallback = False

        for line in lines:
            line_str = line.strip()
            if not line_str or line_str.startswith("#"):
                continue

            # Check root keys
            if re.match(r"^version:\s*(.*)", line):
                root["version"] = int(re.match(r"^version:\s*(.*)", line).group(1).strip())
                continue
            if re.match(r"^catalog_version:\s*(.*)", line):
                root["catalog_version"] = int(re.match(r"^catalog_version:\s*(.*)", line).group(1).strip())
                continue
            if re.match(r"^cdn_base_url:\s*(.*)", line):
                val = re.match(r"^cdn_base_url:\s*(.*)", line).group(1).strip().strip('"\'')
                root["cdn_base_url"] = val
                continue
            if line.startswith("attribution:"):
                in_attr = True
                in_regions = False
                in_fallback = False
                root["attribution"] = {}
                continue
            if line.startswith("regions:"):
                in_regions = True
                in_attr = False
                in_fallback = False
                root["regions"] = []
                continue
            if line.startswith("fallback:"):
                in_fallback = True
                in_regions = False
                in_attr = False
                root["fallback"] = {}
                continue

            if in_attr:
                m = re.match(r"^\s+([a-zA-Z0-9_]+):\s*(.*)", line)
                if m:
                    root["attribution"][m.group(1)] = m.group(2).strip().strip('"\'')
                continue

            if in_fallback:
                m = re.match(r"^\s+([a-zA-Z0-9_]+):\s*(.*)", line)
                if m:
                    key = m.group(1)
                    val = m.group(2).strip().strip('"\'')
                    if val.isdigit():
                        val = int(val)
                    root["fallback"][key] = val
                continue

            if in_regions:
                if line_str.startswith("- id:"):
                    current_region = {"id": line_str.split(":", 1)[1].strip()}
                    root["regions"].append(current_region)
                    in_bounds = False
                    continue
                if current_region is not None:
                    if line_str.startswith("bounds:"):
                        in_bounds = True
                        current_region["bounds"] = {}
                        continue
                    if in_bounds:
                        bm = re.match(r"^\s+([a-zA-Z0-9_]+):\s*([0-9.-]+)", line)
                        if bm:
                            current_region["bounds"][bm.group(1)] = float(bm.group(2))
                            continue
                        else:
                            in_bounds = False
                    m = re.match(r"^\s+([a-zA-Z0-9_]+):\s*(.*)", line)
                    if m:
                        key = m.group(1)
                        val = m.group(2).strip().strip('"\'')
                        if key == "overlapKm":
                            val = float(val)
                        current_region[key] = val

        return root

    def load_yaml(content_or_file):
        if hasattr(content_or_file, "read"):
            text = content_or_file.read()
        elif isinstance(content_or_file, str) and "\n" not in content_or_file and content_or_file.endswith((".yaml", ".yml")):
            with open(content_or_file, "r", encoding="utf-8") as f:
                text = f.read()
        else:
            text = content_or_file
        return parse_simple_yaml(text)
