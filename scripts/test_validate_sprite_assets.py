import hashlib
import json
import pathlib
import struct
import sys
import tempfile
import unittest
import zlib

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from validate_sprite_assets import validate


def png(width: int, height: int) -> bytes:
    header = b"\x89PNG\r\n\x1a\n" + b"\x00" * 8
    return header + struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0) + b"\x00" * 16


class SpriteValidatorTest(unittest.TestCase):
    def write_manifest(self, root: pathlib.Path, entries: list[dict]) -> pathlib.Path:
        manifest = root / "manifest.json"
        manifest.write_text(json.dumps({"version": 1, "directions": ["N", "NE", "E", "SE", "S", "SW", "W", "NW"], "character_frame": {"width": 96, "height": 128}, "entries": entries}), encoding="utf-8")
        return manifest

    def test_accepts_valid_character_layer(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            path = root / "survivor_n.png"
            path.write_bytes(png(96, 128))
            entry = {"path": path.name, "kind": "character", "asset": "survivor", "layer": "body", "state": "idle", "direction": "N", "frame": 0, "width": 96, "height": 128, "pivot": [48, 127], "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
            self.assertEqual(validate(self.write_manifest(root, [entry]), root), [])

    def test_rejects_wrong_size_and_direction(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            path = root / "bad.png"
            path.write_bytes(png(64, 64))
            entry = {"path": path.name, "kind": "character", "asset": "survivor", "layer": "body", "state": "idle", "direction": "SIDE", "frame": 0, "width": 64, "height": 64, "pivot": [32, 63]}
            errors = validate(self.write_manifest(root, [entry]), root)
            self.assertTrue(any("character frame" in error for error in errors))
            self.assertTrue(any("invalid direction" in error for error in errors))

    def test_rejects_missing_sprite(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            entry = {"path": "missing.png", "kind": "character", "asset": "survivor", "layer": "body", "state": "idle", "direction": "N", "frame": 0, "width": 96, "height": 128, "pivot": [48, 127]}
            errors = validate(self.write_manifest(root, [entry]), root)
            self.assertEqual(errors, [f"missing sprite: {root / 'missing.png'}"])

    def test_directional_atlas_columns_are_not_identical(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            atlas = root / "atlas.png"
            rows = [bytes([0]) + bytes([column, 0, 0, 255] * 8) for column in range(4)]
            raw = b"".join(rows)
            header = struct.pack(">IIBBBBB", 8, 4, 8, 6, 0, 0, 0)

            def chunk(tag, data):
                return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

            atlas.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))
            payload = atlas.read_bytes()
            idat_start = payload.index(b"IDAT") + 4
            idat_size = struct.unpack(">I", payload[idat_start - 8:idat_start - 4])[0]
            pixels = zlib.decompress(payload[idat_start:idat_start + idat_size])
            columns = [pixels[1 + column * 4:1 + column * 4 + 4] for column in range(8)]
            self.assertGreater(len({bytes(column) for column in columns}), 1)


if __name__ == "__main__":
    unittest.main()
