import assert from "node:assert/strict";
import test from "node:test";
import { createItemState } from "../src/items";
import { createZombies } from "../src/zombies";
import { isWalkable, moveWithCollision, PLAYER_RADIUS, repairPosition, WORLD_BOUNDS, ZOMBIE_RADIUS } from "../src/world";

test("blocks walls and slides along them", () => {
  const blocked = moveWithCollision({ x: 100, y: 260 }, { x: 0, y: -30 }, PLAYER_RADIUS);
  assert.ok(blocked.y >= 252 && blocked.y < 260);
  const sliding = moveWithCollision({ x: 100, y: 260 }, { x: 20, y: -30 }, PLAYER_RADIUS);
  assert.equal(sliding.x, 120);
  assert.ok(sliding.y >= 252 && sliding.y < 260);
});

test("allows movement through broad building entrances", () => {
  const throughDoor = moveWithCollision({ x: 200, y: 260 }, { x: 0, y: -30 }, PLAYER_RADIUS);
  assert.equal(throughDoor.y, 230);
});

test("prevents large-delta tunneling and remains stable at corners", () => {
  const tunneled = moveWithCollision({ x: 100, y: 300 }, { x: 0, y: -200 }, PLAYER_RADIUS);
  assert.ok(tunneled.y >= 252);
  const corner = moveWithCollision({ x: 40, y: 260 }, { x: 80, y: -80 }, PLAYER_RADIUS);
  assert.ok(Number.isFinite(corner.x) && Number.isFinite(corner.y));
  assert.ok(isWalkable(corner, PLAYER_RADIUS));
});

test("keeps entities inside world bounds", () => {
  const result = moveWithCollision({ x: 40, y: 40 }, { x: -100, y: -100 }, PLAYER_RADIUS);
  assert.equal(result.x, WORLD_BOUNDS.x + PLAYER_RADIUS);
  assert.equal(result.y, WORLD_BOUNDS.y + PLAYER_RADIUS);
});

test("repairs invalid persisted positions deterministically", () => {
  assert.deepEqual(repairPosition({ x: 70, y: 70 }, { x: 640, y: 360 }, PLAYER_RADIUS), { x: 640, y: 360 });
});

test("all authoritative fixtures start in walkable space", () => {
  for (const zombie of Object.values(createZombies())) assert.ok(isWalkable(zombie, ZOMBIE_RADIUS), zombie.id);
  const items = createItemState();
  for (const item of Object.values(items.worldItems)) assert.ok(isWalkable(item, 4), item.id);
  for (const container of Object.values(items.containers)) assert.ok(isWalkable(container, 12), container.id);
  for (const spawn of [[560, 360], [720, 360], [640, 280], [640, 440]]) assert.ok(isWalkable({ x: spawn[0], y: spawn[1] }, PLAYER_RADIUS));
});
