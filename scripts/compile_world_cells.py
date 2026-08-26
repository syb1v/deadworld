#!/usr/bin/env python3
"""Compile the shared 2D world descriptor's deterministic 32 m cell grid."""
from __future__ import annotations

import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
MAP_PATH = ROOT / "client/data/world_map.json"
CELL_SIZE = 32


def district_for(x: float, y: float, width: float, height: float) -> str:
    column = min(2, int(x / max(1.0, width) * 3.0))
    row = min(2, int(y / max(1.0, height) * 3.0))
    return (
        ("safehouse", "residential", "clinic") if row == 0 else
        ("industrial", "commercial", "warehouse") if row == 1 else
        ("park", "fuel", "perimeter")
    )[column]


def compile_map() -> dict:
    data = json.loads(MAP_PATH.read_text(encoding="utf-8"))
    old = data["bounds"]
    bounds = {"x": 0, "y": 0, "width": old["width"] * 3, "height": old["height"] * 3}
    cells = []
    for row in range(bounds["height"] // CELL_SIZE):
        for column in range(bounds["width"] // CELL_SIZE):
            x = column * CELL_SIZE
            y = row * CELL_SIZE
            cells.append({"id": f"{column}:{row}", "x": x, "y": y, "districtId": district_for(x, y, bounds["width"], bounds["height"])})
    data["bounds"] = bounds
    data["cells"] = cells
    data["spawnPoints"] = [{"x": 640, "y": 380}, {"x": 1920, "y": 380}, {"x": 3200, "y": 1700}]
    data["pointsOfInterest"] = [
        {"id": "poi_safehouse", "x": 640, "y": 380, "districtId": "safehouse"},
        {"id": "poi_clinic", "x": 205, "y": 155, "districtId": "clinic"},
        {"id": "poi_industrial", "x": 1450, "y": 900, "districtId": "industrial"},
        {"id": "poi_perimeter", "x": 3200, "y": 1700, "districtId": "perimeter"}
    ]
    district_width = bounds["width"] // 3
    district_height = bounds["height"] // 3
    district_ids = [
        "safehouse", "residential", "clinic",
        "industrial", "commercial", "warehouse",
        "park", "fuel", "perimeter"
    ]
    surface_by_district = {
        "safehouse": "concrete", "residential": "wood", "clinic": "tile_clinic",
        "industrial": "asphalt", "commercial": "concrete", "warehouse": "concrete",
        "park": "grass", "fuel": "asphalt", "perimeter": "soil"
    }
    areas = []
    for index, district_id in enumerate(district_ids):
        column = index % 3
        row = index // 3
        areas.append({
            "name": district_id.upper(),
            "districtId": district_id,
            "x": column * district_width + 28,
            "y": row * district_height + 28,
            "width": district_width - 56,
            "height": district_height - 56,
            "color": "3a433b",
            "surface": surface_by_district[district_id]
        })
    data["areas"] = areas
    return data


if __name__ == "__main__":
    MAP_PATH.write_text(json.dumps(compile_map(), ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("Compiled world schema v2: 9x bounds and deterministic cells")
