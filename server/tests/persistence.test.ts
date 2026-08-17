import assert from "node:assert/strict";
import test from "node:test";
import { createItemState } from "../src/items";
import { applyWorld, snapshotWorld, writeWorld } from "../src/persistence";
import { createZombies } from "../src/zombies";

test("round-trips stack quantity, magazine ammo, players and dead zombies", () => {
  const source = { items: createItemState(), inventories: { user: [{ id: "pistol", definitionId: "pistol" as const, magazineAmmo: 4 }, { id: "ammo", definitionId: "pistol_ammo" as const, quantity: 18 }] }, persistedPlayers: { user: { x: 12, y: 34, health: 55, spawnIndex: 2, respawnAtMs: 123456 } }, zombies: createZombies() };
  source.zombies["zombie:main-1"].hp = 0;
  const saved = snapshotWorld(source);
  const restored = { items: createItemState(), inventories: {}, persistedPlayers: {}, zombies: createZombies() };
  applyWorld(restored, saved);
  assert.deepEqual(restored.inventories, source.inventories);
  assert.deepEqual(restored.persistedPlayers, source.persistedPlayers);
  assert.equal(restored.persistedPlayers.user.respawnAtMs, 123456);
  assert.equal(restored.zombies["zombie:main-1"].state, "DEAD");
  assert.equal(restored.zombies["zombie:main-1"].hp, 0);
});

test("persistent snapshots are detached rollback values", () => {
  const source = { items: createItemState(), inventories: {}, persistedPlayers: {}, zombies: createZombies() };
  const saved = snapshotWorld(source);
  delete source.items.worldItems["item:world-pistol"];
  assert.ok(saved.items.worldItems["item:world-pistol"]);
});

test("creates a missing aggregate with create-only CAS", () => {
  let request: any;
  const nk = { storageWrite: (requests: any[]) => { request = requests[0]; return [{ version: "created-version" }]; } } as any;
  const source = { persistenceKey: "test", items: createItemState(), inventories: {}, persistedPlayers: {}, zombies: createZombies() };
  assert.equal(writeWorld(nk, source, ""), "created-version");
  assert.equal(request.version, "*");
});
