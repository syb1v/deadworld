import assert from "node:assert/strict";
import test from "node:test";
import { createZombies, simulateZombie, Zombie, ZombieTarget } from "../src/zombies";

const zombie = (): Zombie => ({ id: "zombie:test", x: 0, y: 0, vx: 0, vy: 0, hp: 30, state: "IDLE", targetId: "", nextAttackTick: 0 });
const player = (id: string, x: number): ZombieTarget => ({ id, x, y: 0, health: 100 });

test("creates stable world zombie IDs", () => {
  const zombies = createZombies();
  assert.deepEqual(Object.keys(zombies), ["zombie:main-1", "zombie:main-2", "zombie:main-3"]);
  assert.deepEqual({ hp: zombies["zombie:main-3"].hp, state: zombies["zombie:main-3"].state }, { hp: 0, state: "DEAD" });
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

test("does not lose its only target before Day 4 death exists", () => {
  const subject = zombie();
  const target = player("player:near", 10);
  for (let tick = 0; tick < 400; tick += 15) simulateZombie(subject, [target], tick, 1 / 15);
  assert.equal(target.health, 1);
  assert.equal(subject.state, "ATTACK");
  assert.equal(subject.targetId, target.id);
});

test("synchronizes terminal dead state from authoritative HP", () => {
  const subject = zombie();
  subject.hp = 0;
  simulateZombie(subject, [player("player:near", 10)], 1, 1 / 15);
  assert.deepEqual({ hp: subject.hp, state: subject.state, target: subject.targetId }, { hp: 0, state: "DEAD", target: "" });
});
