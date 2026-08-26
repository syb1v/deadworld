import assert from "node:assert/strict";
import test from "node:test";
import { getCellId, getCellDescriptor, normalizeWorldDescriptor, WORLD_CELL_SIZE } from "../src/world_cells";

test("world descriptor normalizes legacy map to schema v2", () => {
  const descriptor = normalizeWorldDescriptor();
  assert.equal(descriptor.schemaVersion, 2);
  assert.equal(descriptor.cellSize, 32);
  assert.ok(descriptor.bounds.width > 0);
  assert.ok(descriptor.districts.length > 0);
});

test("cell IDs are deterministic at boundaries", () => {
  assert.equal(getCellId(0, 0), "0:0");
  assert.equal(getCellId(WORLD_CELL_SIZE - 0.01, WORLD_CELL_SIZE - 0.01), "0:0");
  assert.equal(getCellId(WORLD_CELL_SIZE, WORLD_CELL_SIZE), "1:1");
  assert.equal(getCellDescriptor("missing"), undefined);
});
