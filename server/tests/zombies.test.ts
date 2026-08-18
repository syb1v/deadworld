import assert from "node:assert/strict";
import test from "node:test";
import { createZombies, separateZombies, simulateZombie, Zombie, ZombieTarget } from "../src/zombies";

const zombie = (): Zombie => ({ id: "zombie:test", x: 0, y: 0, vx: 0, vy: 0, hp: 30, state: "IDLE", targetId: "", nextAttackTick: 0, spawnX: 0, spawnY: 0 });
const player = (id: string, x: number): ZombieTarget => ({ id, x, y: 0, health: 100 });

test("creates stable world zombie IDs", () => {
  const zombies = createZombies();
  assert.deepEqual(Object.keys(zombies), ["zombie:main-1", "zombie:main-2", "zombie:main-3"]);
  assert.ok(Object.values(zombies).every((entity) => entity.hp === 30 && entity.state === "IDLE"));
});

test("selects nearest player and chases server-side", () => {
  const subject = zombie();
  simulateZombie(subject, [player("player:far", 200), player("player:near", 100)], 1, 1 / 15);
  assert.equal(subject.state, "CHASE");
  assert.equal(subject.targetId, "player:near");
  assert.ok(subject.x > 0);
});

test("attacks with a server cooldown", () => {
  const subject = zombie();
  const target = player("player:near", 10);
  simulateZombie(subject, [target], 1, 1 / 15);
  simulateZombie(subject, [target], 2, 1 / 15);
  assert.equal(subject.state, "ATTACK");
  assert.equal(target.health, 95);
});

test("keeps its current target when a second nearby player joins", () => {
  const subject = zombie();
  const original = player("player:original", 100);
  simulateZombie(subject, [original], 1, 1 / 15);
  const newcomer = player("player:newcomer", 90);
  simulateZombie(subject, [original, newcomer], 2, 1 / 15);
  assert.equal(subject.targetId, "player:original");
});

test("uses hysteresis instead of flickering out of attack", () => {
  const subject = zombie();
  const target = player("player:near", 27);
  simulateZombie(subject, [target], 1, 1 / 15);
  target.x = 33;
  simulateZombie(subject, [target], 2, 1 / 15);
  assert.equal(subject.state, "ATTACK");
});

test("kills its target with authoritative damage", () => {
  const subject = zombie();
  const target = player("player:near", 10);
  for (let tick = 0; tick < 400; tick += 15) simulateZombie(subject, [target], tick, 1 / 15);
  assert.equal(target.health, 0);
});

test("synchronizes terminal dead state from authoritative HP", () => {
  const subject = zombie();
  subject.hp = 0;
  simulateZombie(subject, [player("player:near", 10)], 1, 1 / 15);
  assert.deepEqual({ hp: subject.hp, state: subject.state, target: subject.targetId }, { hp: 0, state: "DEAD", target: "" });
});

test("separates overlapping living zombies without spawning new ones", () => {
  const left = zombie(); left.id = "zombie:left"; left.x = 640; left.y = 360;
  const right = zombie(); right.id = "zombie:right"; right.x = 640; right.y = 360;
  const zombies = { [left.id]: left, [right.id]: right };
  separateZombies(zombies);
  assert.equal(Object.keys(zombies).length, 2);
  assert.ok(Math.hypot(left.x - right.x, left.y - right.y) >= 30);
});

test("separates wall-adjacent zombies using remaining free space", () => {
  const left = zombie(); left.id = "zombie:left"; left.x = 354; left.y = 150;
  const right = zombie(); right.id = "zombie:right"; right.x = 354; right.y = 150;
  separateZombies({ [left.id]: left, [right.id]: right });
  assert.ok(Math.hypot(left.x - right.x, left.y - right.y) >= 29.8);
});
