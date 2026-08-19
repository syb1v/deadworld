import assert from "node:assert/strict";
import test from "node:test";
import { createItemState, dropItem, ItemPlayer, mutateContainer, pickupItem } from "../src/items";

const player = (id: string, x = 640, y = 360): ItemPlayer => ({ id, x, y, inventory: [] });

test("allows exactly one winner for simultaneous world pickup", () => {
  const state = createItemState();
  const a = player("player:a");
  const b = player("player:b");
  const first = pickupItem(state, a, "item:world-bandage", 1);
  const second = pickupItem(state, b, "item:world-bandage", 1);
  assert.equal(first.ok, true);
  assert.equal(second.ok, false);
  assert.equal(a.inventory.length + b.inventory.length, 1);
  assert.equal(state.worldItems["item:world-bandage"], undefined);
});

test("rejects stale container versions without moving ownership", () => {
  const state = createItemState();
  const a = player("player:a", 640, 400);
  const b = player("player:b", 640, 400);
  assert.equal(mutateContainer(state, a, { container_id: "container:clinic", expected_version: 1, operation: "take", item_instance_id: "item:clinic-beans" }).ok, true);
  const stale = mutateContainer(state, b, { container_id: "container:clinic", expected_version: 1, operation: "take", item_instance_id: "item:clinic-scrap" });
  assert.deepEqual(stale, { ok: false, code: "STALE_CONTAINER_VERSION" });
  assert.equal(state.containers["container:clinic"].items.length, 1);
  assert.equal(a.inventory.length + b.inventory.length, 1);
});

test("drop transfers an owned instance back to world exactly once", () => {
  const state = createItemState();
  const owner = player("player:owner");
  assert.equal(pickupItem(state, owner, "item:world-bandage", 1).ok, true);
  assert.equal(dropItem(state, owner, "item:world-bandage").ok, true);
  assert.equal(dropItem(state, owner, "item:world-bandage").ok, false);
  assert.equal(owner.inventory.length, 0);
  assert.equal(state.worldItems["item:world-bandage"].id, "item:world-bandage");
});

test("validates proximity for item and container mutations", () => {
  const state = createItemState();
  const far = player("player:far", 0, 0);
  assert.equal(pickupItem(state, far, "item:world-bandage", 1).code, "OUT_OF_RANGE");
  assert.equal(mutateContainer(state, far, { container_id: "container:clinic", expected_version: 1, operation: "take", item_instance_id: "item:clinic-beans" }).code, "OUT_OF_RANGE");
});

test("world fixture provides melee weapons and practical pistol ammo", () => {
  const items = Object.values(createItemState().worldItems);
  assert.ok(items.filter((item) => item.definitionId === "baseball_bat").length >= 2);
  assert.ok(items.filter((item) => item.definitionId === "pistol_ammo").reduce((total, item) => total + (item.quantity || 1), 0) >= 24);
});

test("merges quantity items into authoritative stacks up to 64", () => {
  const state = createItemState();
  const owner = player("player:owner");
  owner.inventory.push({ id: "item:owned-ammo", definitionId: "pistol_ammo", quantity: 40 });
  assert.equal(pickupItem(state, owner, "item:world-ammo-1", 1).ok, true);
  assert.deepEqual(owner.inventory, [{ id: "item:owned-ammo", definitionId: "pistol_ammo", quantity: 64 }]);
});

test("rejects an entire stack when no quantity can fit", () => {
  const state = createItemState();
  const owner = player("player:full");
  owner.inventory.push({ id: "item:owned-ammo", definitionId: "pistol_ammo", quantity: 64 });
  for (let index = 0; index < 7; index += 1) owner.inventory.push({ id: `item:bat-${index}`, definitionId: "baseball_bat" });
  assert.equal(pickupItem(state, owner, "item:world-ammo-1", 1).code, "INVENTORY_FULL");
  assert.equal(owner.inventory[0].quantity, 64);
  assert.equal(state.worldItems["item:world-ammo-1"].quantity, 24);
});

test("deposits an owned item into an empty container exactly once", () => {
  const state = createItemState();
  const owner = player("player:owner", 640, 400);
  const container = state.containers["container:clinic"];
  container.items = [];
  owner.inventory.push({ id: "item:owned-bandage", definitionId: "bandage", quantity: 2 });
  const version = container.version;
  assert.equal(mutateContainer(state, owner, { container_id: container.id, expected_version: version, operation: "deposit", item_instance_id: "item:owned-bandage" }).ok, true);
  assert.equal(owner.inventory.length, 0);
  assert.deepEqual(container.items, [{ id: "item:owned-bandage", definitionId: "bandage", quantity: 2 }]);
  assert.equal(container.version, version + 1);
  assert.equal(mutateContainer(state, owner, { container_id: container.id, expected_version: version, operation: "deposit", item_instance_id: "item:owned-bandage" }).code, "STALE_CONTAINER_VERSION");
  assert.equal(container.items.length, 1);
});

test("rejects unowned and out-of-range deposits without moving items", () => {
  const state = createItemState();
  const owner = player("player:owner", 640, 400);
  owner.inventory.push({ id: "item:owned-bandage", definitionId: "bandage" });
  const container = state.containers["container:clinic"];
  assert.equal(mutateContainer(state, owner, { container_id: container.id, expected_version: container.version, operation: "deposit", item_instance_id: "item:missing" }).code, "ITEM_NOT_OWNED");
  owner.x = 0; owner.y = 0;
  assert.equal(mutateContainer(state, owner, { container_id: container.id, expected_version: container.version, operation: "deposit", item_instance_id: "item:owned-bandage" }).code, "OUT_OF_RANGE");
  assert.equal(owner.inventory.length, 1);
  assert.equal(container.items.some((item) => item.id === "item:owned-bandage"), false);
});
