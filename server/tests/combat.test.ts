import assert from "node:assert/strict";
import test from "node:test";
import { attack, CombatPlayer, parseAttack, reload } from "../src/combat";
import { Zombie } from "../src/zombies";

const player = (inventory: any[]): CombatPlayer => ({ id: "player:test", x: 0, y: 0, health: 100, inventory, lastAttackSequence: -1, lastReloadSequence: -1, nextAttackTick: 0 });
const zombie = (x = 30): Zombie => ({ id: "zombie:test", x, y: 0, vx: 0, vy: 0, hp: 30, state: "IDLE", targetId: "", nextAttackTick: 0, spawnX: x, spawnY: 0 });

test("normalizes aim and rejects forged combat fields", () => {
  assert.deepEqual(parseAttack({ weapon_slot: 0, aim_x: 10, aim_y: 0, sequence: 1 }), { weapon_slot: 0, aim_x: 1, aim_y: 0, sequence: 1 });
  assert.equal(parseAttack({ weapon_slot: 0, aim_x: 0, aim_y: 0, sequence: 1, target_id: "zombie:test", damage: 999 }), null);
});

test("melee damages only an authoritative target in range and aim cone", () => {
  const subject = player([{ id: "item:bat", definitionId: "baseball_bat" }]);
  const target = zombie();
  const result = attack(subject, { [target.id]: target }, { weapon_slot: 0, aim_x: 1, aim_y: 0, sequence: 1 }, 10);
  assert.deepEqual({ ok: result.ok, targetId: result.targetId, damage: result.damage, hp: target.hp }, { ok: true, targetId: target.id, damage: 15, hp: 15 });
});

test("pistol consumes server-owned magazine ammo and enforces cooldown", () => {
  const subject = player([{ id: "item:pistol", definitionId: "pistol", magazineAmmo: 1 }]);
  const target = zombie(100);
  const first = attack(subject, { [target.id]: target }, { weapon_slot: 0, aim_x: 1, aim_y: 0, sequence: 1 }, 10);
  const second = attack(subject, { [target.id]: target }, { weapon_slot: 0, aim_x: 1, aim_y: 0, sequence: 2 }, 11);
  assert.equal(first.damage, 20);
  assert.equal(subject.inventory[0].magazineAmmo, 0);
  assert.equal(second.code, "ATTACK_COOLDOWN");
});

test("rejects firing an empty magazine without accepting an attack", () => {
  const subject = player([{ id: "item:pistol", definitionId: "pistol", magazineAmmo: 0 }, { id: "item:ammo", definitionId: "pistol_ammo" }]);
  assert.deepEqual(attack(subject, {}, { weapon_slot: 0, aim_x: 1, aim_y: 0, sequence: 1 }, 1), { ok: false, code: "MAGAZINE_EMPTY" });
  assert.equal(subject.inventory.length, 2);
});

test("reload consumes loose ammo up to magazine capacity", () => {
  const subject = player([{ id: "item:a", definitionId: "pistol_ammo" }, { id: "item:b", definitionId: "pistol_ammo" }, { id: "item:pistol", definitionId: "pistol", magazineAmmo: 4 }, { id: "item:c", definitionId: "pistol_ammo" }]);
  assert.deepEqual(reload(subject, { weapon_slot: 2, sequence: 1 }), { ok: true, loaded: 2, magazineAmmo: 6, weaponSlot: 0 });
  assert.equal(subject.inventory.filter((item) => item.definitionId === "pistol_ammo").length, 1);
  assert.equal(reload(subject, { weapon_slot: 0, sequence: 1 }).code, "STALE_RELOAD_SEQUENCE");
});

test("rejects unowned weapon slots and dead attackers", () => {
  const unarmed = player([]);
  assert.equal(attack(unarmed, {}, { weapon_slot: 0, aim_x: 1, aim_y: 0, sequence: 1 }, 1).code, "WEAPON_NOT_OWNED");
  unarmed.health = 0;
  assert.equal(attack(unarmed, {}, { weapon_slot: 0, aim_x: 1, aim_y: 0, sequence: 2 }, 2).code, "PLAYER_DEAD");
});
