import json
import pathlib
import sys
import tempfile
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from validate_world_descriptor import validate


class WorldDescriptorTest(unittest.TestCase):
    def test_current_descriptor_is_expanded_and_complete(self):
        errors = validate(pathlib.Path(__file__).resolve().parent.parent / "client/data/world_map.json")
        self.assertEqual(errors, [])

    def test_rejects_missing_cells(self):
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / "world.json"
            path.write_text(json.dumps({"schemaVersion": 2, "cellSize": 32, "bounds": {"x": 0, "y": 0, "width": 3200, "height": 1600}, "districts": []}), encoding="utf-8")
            self.assertTrue(any("expected" in error for error in validate(path)))


if __name__ == "__main__":
    unittest.main()
