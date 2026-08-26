#!/usr/bin/env python3
"""Validate the shared expanded world descriptor before client/server use."""
from __future__ import annotations

import json
import pathlib
import sys


REQUIRED_DISTRICTS = {"safehouse", "residential", "clinic", "industrial", "commercial", "warehouse", "park", "fuel", "perimeter"}


def validate(path: pathlib.Path) -> list[str]:
    data = json.loads(path.read_text(encoding="utf-8"))
    errors: list[str] = []
    if data.get("schemaVersion") != 2:
        errors.append("schemaVersion must be 2")
    if data.get("cellSize") != 32:
        errors.append("cellSize must be 32")
    bounds = data.get("bounds", {})
    if bounds.get("width", 0) < 3000 or bounds.get("height", 0) < 1500:
        errors.append("bounds are not expanded to the 9x target")
    district_ids = {district.get("id") for district in data.get("districts", [])}
    errors.extend(f"missing district: {district}" for district in sorted(REQUIRED_DISTRICTS - district_ids))
    expected_cells = (bounds.get("width", 0) // 32) * (bounds.get("height", 0) // 32)
    if len(data.get("cells", [])) != expected_cells:
        errors.append(f"expected {expected_cells} cells, got {len(data.get('cells', []))}")
    cell_ids = {cell.get("id") for cell in data.get("cells", [])}
    if len(cell_ids) != len(data.get("cells", [])):
        errors.append("cell IDs must be unique")
    for spawn in data.get("spawnPoints", []):
        if not (bounds["x"] <= spawn["x"] <= bounds["x"] + bounds["width"] and bounds["y"] <= spawn["y"] <= bounds["y"] + bounds["height"]):
            errors.append(f"spawn outside bounds: {spawn}")
    return errors


if __name__ == "__main__":
    target = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else pathlib.Path("client/data/world_map.json")
    failures = validate(target)
    if failures:
        for failure in failures:
            print(f"ERROR: {failure}", file=sys.stderr)
        raise SystemExit(1)
    print("World descriptor is valid")
