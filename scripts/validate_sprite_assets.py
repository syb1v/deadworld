#!/usr/bin/env python3
"""Validate deterministic 2D/2.5D sprite contracts without external packages."""

import argparse
import hashlib
import json
import pathlib
import struct
import sys


DIRECTIONS = ("N", "NE", "E", "SE", "S", "SW", "W", "NW")
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def png_info(path: pathlib.Path) -> tuple[int, int, bool]:
    data = path.read_bytes()
    if not data.startswith(PNG_SIGNATURE) or len(data) < 33:
        raise ValueError(f"{path}: invalid PNG signature")
    width, height, bit_depth, color_type = struct.unpack(">IIBB", data[16:26])
    if bit_depth != 8:
        raise ValueError(f"{path}: expected 8-bit PNG")
    if color_type not in (4, 6):
        raise ValueError(f"{path}: expected alpha channel")
    return width, height, True


def validate(manifest_path: pathlib.Path, root: pathlib.Path) -> list[str]:
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    errors: list[str] = []
    directions = tuple(manifest.get("directions", []))
    if directions != DIRECTIONS:
        errors.append(f"directions must be {DIRECTIONS}, got {directions}")
    frame = manifest.get("character_frame", manifest.get("frame", {}))
    expected_size = (int(frame.get("width", 0)), int(frame.get("height", 0)))
    if expected_size != (96, 128):
        errors.append(f"character_frame must be 96x128, got {expected_size}")

    entries = manifest.get("entries", [])
    atlases = manifest.get("atlases", {})
    for relative, atlas in sorted(atlases.items()):
        path = root / relative
        if not path.is_file():
            errors.append(f"missing sprite atlas: {path}")
            continue
        try:
            width, height, _ = png_info(path)
        except (OSError, ValueError) as error:
            errors.append(str(error))
            continue
        expected_width = expected_size[0] * len(DIRECTIONS)
        expected_height = expected_size[1] * int(atlas.get("frames", 0))
        if (width, height) != (expected_width, expected_height):
            errors.append(f"{relative}: atlas size {(width, height)} != {(expected_width, expected_height)}")
        if (atlas.get("frame_width"), atlas.get("frame_height")) != expected_size:
            errors.append(f"{relative}: frame size must be {expected_size}")
        if hashlib.sha256(path.read_bytes()).hexdigest() != atlas.get("sha256"):
            errors.append(f"{relative}: SHA256 mismatch")
    if not entries and manifest.get("hashes"):
        entries = []
        for relative, expected_hash in sorted(manifest["hashes"].items()):
            parts = pathlib.PurePosixPath(relative).parts
            if len(parts) != 4:
                entries.append({"path": relative, "sha256": expected_hash, "kind": "invalid"})
                continue
            _, asset, layer, frame_name = parts
            stem = pathlib.PurePosixPath(frame_name).stem
            state, direction, frame = stem.rsplit("_", 2)
            entries.append({
                "path": relative,
                "sha256": expected_hash,
                "kind": "character",
                "asset": asset,
                "layer": layer,
                "state": state,
                "direction": direction.upper(),
                "frame": int(frame),
                "width": expected_size[0],
                "height": expected_size[1],
                "pivot": [expected_size[0] // 2, expected_size[1] - 1],
            })
    seen: set[str] = set()
    layer_contract: dict[tuple[str, str, int], tuple[int, int, int, int]] = {}
    for entry in entries:
        relative = str(entry.get("path", ""))
        path = root / relative
        if relative.lower() != relative or " " in relative:
            errors.append(f"invalid lowercase ASCII path: {relative}")
        if relative in seen:
            errors.append(f"duplicate path: {relative}")
        seen.add(relative)
        if not path.is_file():
            errors.append(f"missing sprite: {path}")
            continue
        try:
            width, height, _ = png_info(path)
        except (OSError, ValueError) as error:
            errors.append(str(error))
            continue
        declared = (int(entry.get("width", 0)), int(entry.get("height", 0)))
        if (width, height) != declared:
            errors.append(f"{relative}: manifest size {declared} != PNG size {(width, height)}")
        if entry.get("kind") == "character" and (width, height) != expected_size:
            errors.append(f"{relative}: character frame must be {expected_size}")
        direction = entry.get("direction")
        if direction not in DIRECTIONS:
            errors.append(f"{relative}: invalid direction {direction}")
        pivot = entry.get("pivot")
        if pivot != [width // 2, height - 1]:
            errors.append(f"{relative}: pivot must be bottom-center {[width // 2, height - 1]}")
        contract_key = (str(entry.get("asset", "")), str(entry.get("state", "")), int(entry.get("frame", -1)))
        contract = (width, height, int(pivot[0]), int(pivot[1])) if isinstance(pivot, list) and len(pivot) == 2 else (width, height, -1, -1)
        previous = layer_contract.get(contract_key)
        if previous is not None and previous != contract:
            errors.append(f"{relative}: layer canvas/pivot differs from sibling")
        layer_contract[contract_key] = contract
        expected_hash = entry.get("sha256")
        if expected_hash and hashlib.sha256(path.read_bytes()).hexdigest() != expected_hash:
            errors.append(f"{relative}: SHA256 mismatch")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=pathlib.Path, required=True)
    parser.add_argument("--root", type=pathlib.Path, required=True)
    args = parser.parse_args()
    errors = validate(args.manifest, args.root)
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1
    print(f"Validated {len(json.loads(args.manifest.read_text(encoding='utf-8')).get('entries', []))} sprite entries")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
