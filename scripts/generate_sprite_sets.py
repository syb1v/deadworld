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


def pixel_disc(c: Canvas, cx: int, cy: int, rx: int, ry: int, color: tuple[int, int, int]) -> None:
    """Hard-edged stepped ellipse for pixel-art silhouettes."""
    for y in range(-ry, ry + 1):
        span = int(rx * math.sqrt(max(0.0, 1.0 - (y / max(1, ry)) ** 2)))
        c.rect(cx - span, cy + y, span * 2 + 1, 1, color)


def pixel_line(c: Canvas, x0: int, y0: int, x1: int, y1: int, color: tuple[int, int, int], width: int = 3) -> None:
    steps = max(abs(x1 - x0), abs(y1 - y0), 1)
    for step in range(steps + 1):
        x = round(x0 + (x1 - x0) * step / steps)
        y = round(y0 + (y1 - y0) * step / steps)
        c.rect(x - width // 2, y - width // 2, width, width, color)


def actor_layer(seed: int, survivor: bool, state: str, direction: str, frame: int, layer: str) -> Canvas:
    c = Canvas(*SIZE)
    sector = DIRECTIONS.index(direction)
    forward = ((0, -1), (1, -1), (1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1))[sector]
    side = ((1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1), (0, -1), (1, -1))[sector]
    walk_shift = (-2, 0, 2, 0)[frame % 4] if state == "walk" else 0
    cx = 48 + side[0] * 2
    if state == "death":
        cx += side[0] * 10
    if layer == "shadow":
        pixel_disc(c, cx + 2, 118, 20 if state != "death" else 25, 5, (12, 14, 12))
        return c
    head_y = 37 + forward[1] * 2
    body_y = 57 + walk_shift
    skin = (188, 158, 121) if survivor else (126, 132, 99)
    skin_shadow = (112, 85, 67) if survivor else (74, 78, 62)
    body = (43, 66, 58) if survivor else (77, 65, 58)
    body_light = (76, 105, 82) if survivor else (116, 92, 68)
    cloth = (139, 101, 59) if survivor else (91, 73, 61)
    if layer == "body":
        if state == "death":
            c.rect(cx - 26, 96, 45, 9, body)
            pixel_disc(c, cx + 23, 97, 7, 7, skin)
            return c
        pixel_disc(c, cx, head_y, 8 if direction in ("E", "W") else 9, 10, skin)
        c.rect(cx - 12, body_y, 25, 36, body)
        c.rect(cx - 8, body_y + 4, 16, 18, body_light)
        pixel_line(c, cx - 13, body_y + 10, cx - 17 + side[0] * 4, body_y + 29, skin_shadow, 5)
        pixel_line(c, cx + 12, body_y + 10, cx + 16 + side[0] * 4, body_y + 29, skin, 5)
        c.rect(cx - 10 + walk_shift, body_y + 34, 8, 24, (28, 34, 34))
        c.rect(cx + 2 - walk_shift, body_y + 34, 8, 24, (28, 34, 34))
        if direction in ("S", "SE", "SW"):
            c.rect(cx - 5, head_y - 3, 11, 3, (36, 36, 32))
        if direction in ("E", "W"):
            c.rect(cx + (7 if direction == "E" else -9), head_y - 1, 3, 4, skin_shadow)
    elif layer == "clothing":
        c.rect(cx - 12, body_y + 3, 25, 8, cloth)
        c.rect(cx - 9, body_y + 16, 18, 3, (190, 157, 79))
        c.rect(cx - 8, body_y + 22, 6, 8, (54, 66, 57))
        c.rect(cx + 4, body_y + 22, 6, 8, (54, 66, 57))
        c.rect(cx - 10, body_y + 5, 3, 12, body_light)
    elif layer == "weapon":
        aim_x = cx + forward[0] * (29 if state == "attack" else 22)
        aim_y = body_y + 13 + forward[1] * 8
        pixel_line(c, cx + forward[0] * 5, body_y + 13, aim_x, aim_y, (46, 51, 52), 4)
        pixel_line(c, aim_x - forward[0] * 2, aim_y, aim_x + forward[0] * 8, aim_y + forward[1] * 2, (198, 174, 106), 3)
        if state == "attack" and frame == 1:
            pixel_disc(c, aim_x + forward[0] * 8, aim_y + forward[1] * 2, 4, 3, (235, 193, 88))
    elif layer == "backpack":
        if direction in ("N", "NE", "NW"):
            c.rect(cx - 16, body_y + 5, 8, 23, (60, 77, 68))
            c.rect(cx - 17, body_y + 12, 5, 9, (122, 91, 55))
        elif direction in ("E", "W"):
            c.rect(cx + (-13 if direction == "W" else 7), body_y + 8, 6, 17, (60, 77, 68))
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
