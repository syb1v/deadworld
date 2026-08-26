#!/usr/bin/env python3
"""Generate deterministic directional 2D/2.5D sprite layers."""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import pathlib
import random
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))
from generate_assets import Canvas  # noqa: E402

SIZE = (96, 128)
DIRECTIONS = ("N", "NE", "E", "SE", "S", "SW", "W", "NW")
STATES = ("idle", "walk", "attack", "hit", "death")
LAYERS = ("shadow", "body", "clothing", "weapon", "backpack")


def actor_layer(seed: int, survivor: bool, state: str, direction: str, frame: int, layer: str) -> Canvas:
    rng = random.Random(seed)
    c = Canvas(*SIZE)
    sector = DIRECTIONS.index(direction)
    side = math.sin(sector * math.pi / 4.0)
    motion = math.sin(frame * math.pi / 3.0) * (2 if state == "walk" else 0)
    cx = 48 + int(side * 2)
    if layer == "shadow":
        for offset in range(-18, 19):
            radius = max(2.0, 6.0 * (1.0 - abs(offset) / 20.0))
            c.circle(cx + offset, 119, radius, (8, 10, 8), 0.18)
        return c
    if state == "death":
        cx += int(math.sin(frame * 0.8) * 8)
    head_y = 39 + (2 if direction in ("N", "NW", "NE") else 0)
    body_y = 57 + int(motion)
    if layer == "body":
        skin = (173, 150, 121) if survivor else (118, 126, 102)
        body = (55, 72, 61) if survivor else (83, 66, 60)
        c.circle(cx, head_y, 10, skin)
        c.rect(cx - 13, body_y, 26, 39, body)
        c.rect(cx - 17, body_y + 10, 5, 25, skin)
        c.rect(cx + 12, body_y + 10, 5, 25, skin)
        c.rect(cx - 10 + int(motion), body_y + 37, 8, 22, (35, 40, 37))
        c.rect(cx + 2 - int(motion), body_y + 37, 8, 22, (35, 40, 37))
        if direction in ("S", "SE", "SW"):
            c.rect(cx - 6, head_y - 2, 12, 4, (42, 45, 39))
    elif layer == "clothing":
        c.rect(cx - 13, body_y + 4, 26, 9, (122, 91, 55))
        c.rect(cx - 9, body_y + 18, 18, 3, (183, 156, 83))
        c.circle(cx - 7, body_y + 14, 2, (204, 180, 109))
        c.circle(cx + 7, body_y + 14, 2, (204, 180, 109))
    elif layer == "weapon":
        if state == "attack":
            x0, y0 = cx + int(side * 8), body_y + 15
            c.line(x0, y0, x0 + int(side * 24) + 10, y0 - 10, (82, 87, 84), 4)
            c.line(x0 + int(side * 24) + 10, y0 - 10, x0 + int(side * 24) + 22, y0 - 12, (189, 177, 126), 3)
        else:
            c.line(cx + 8, body_y + 15, cx + 19, body_y + 23, (82, 87, 84), 4)
            c.line(cx + 17, body_y + 21, cx + 25, body_y + 20, (189, 177, 126), 3)
    elif layer == "backpack" and direction in ("N", "NE", "NW"):
        c.rect(cx - 17, body_y + 7, 7, 22, (74, 82, 70))
        c.rect(cx - 18, body_y + 12, 5, 10, (110, 92, 60))
    return c


def copy_frame(atlas: Canvas, frame: Canvas, offset_x: int, offset_y: int) -> None:
    for y in range(frame.height):
        source = y * frame.width * 4
        target = ((offset_y + y) * atlas.width + offset_x) * 4
        atlas.pixels[target:target + frame.width * 4] = frame.pixels[source:source + frame.width * 4]


def write_sets(output: pathlib.Path, seed: int) -> dict[str, dict]:
    atlases: dict[str, dict] = {}
    for asset, base_seed in (("survivor", seed), ("zombie", seed + 7919)):
        states = ("idle", "walk", "attack", "hit", "death")
        for state in states:
            frame_count = 6 if state in ("idle", "walk") else 4
            for layer in LAYERS:
                atlas = Canvas(SIZE[0] * len(DIRECTIONS), SIZE[1] * frame_count)
                for direction_index, direction in enumerate(DIRECTIONS):
                    for frame in range(frame_count):
                        canvas = actor_layer(base_seed, asset == "survivor", state, direction, frame, layer)
                        copy_frame(atlas, canvas, direction_index * SIZE[0], frame * SIZE[1])
                relative = pathlib.Path("characters") / asset / f"{layer}_{state}.png"
                path = output / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                data = atlas.to_png()
                path.write_bytes(data)
                atlases[str(relative)] = {
                    "sha256": hashlib.sha256(data).hexdigest(),
                    "width": atlas.width,
                    "height": atlas.height,
                    "frame_width": SIZE[0],
                    "frame_height": SIZE[1],
                    "frames": frame_count,
                }
    return atlases


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=pathlib.Path, default=ROOT / "client/assets/generated")
    parser.add_argument("--seed", type=int, default=20260826)
    args = parser.parse_args()
    atlases = write_sets(args.output, args.seed)
    manifest = {"version": 2, "frame": {"width": 96, "height": 128}, "directions": list(DIRECTIONS), "atlases": atlases}
    (args.output / "characters").mkdir(parents=True, exist_ok=True)
    (args.output / "characters" / "manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"Generated {len(atlases)} directional sprite atlases")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
