import { ATTACK_AIM_COSINE, MELEE_COOLDOWN_TICKS, MELEE_DAMAGE, MELEE_RANGE, PISTOL_COOLDOWN_TICKS, PISTOL_DAMAGE, PISTOL_RANGE } from "./protocol";
import { ItemInstance } from "./items";
import { killZombie, Zombie } from "./zombies";

export interface CombatPlayer {
  id: string;
  x: number;
  y: number;
  health: number;
  inventory: ItemInstance[];
  lastAttackSequence: number;
  nextAttackTick: number;
}

export interface AttackPayload { weapon_slot: number; aim_x: number; aim_y: number; sequence: number; }
export interface AttackResult { ok: boolean; code?: string; targetId?: string; damage?: number; killed?: boolean; inventoryChanged?: boolean; }

export function parseAttack(payload: Record<string, unknown>): AttackPayload | null {
  const weaponSlot = payload.weapon_slot;
  const aimX = payload.aim_x;
  const aimY = payload.aim_y;
  const sequence = payload.sequence;
  if (!Number.isSafeInteger(weaponSlot) || !Number.isSafeInteger(sequence) || typeof aimX !== "number" || typeof aimY !== "number" || !Number.isFinite(aimX) || !Number.isFinite(aimY)) return null;
  const length = Math.hypot(aimX, aimY);
  if (length < 0.001) return null;
  return { weapon_slot: weaponSlot as number, aim_x: aimX / length, aim_y: aimY / length, sequence: sequence as number };
}

export function attack(player: CombatPlayer, zombies: Record<string, Zombie>, payload: AttackPayload, tick: number): AttackResult {
  if (player.health <= 0) return fail("PLAYER_DEAD");
  if (payload.sequence <= player.lastAttackSequence) return fail("STALE_ATTACK_SEQUENCE");
  player.lastAttackSequence = payload.sequence;
  if (tick < player.nextAttackTick) return fail("ATTACK_COOLDOWN");
  const weapon = player.inventory[payload.weapon_slot];
  if (!weapon || (weapon.definitionId !== "baseball_bat" && weapon.definitionId !== "pistol")) return fail("WEAPON_NOT_OWNED");

  const pistol = weapon.definitionId === "pistol";
  let ammoIndex = -1;
  if (pistol) {
    ammoIndex = player.inventory.findIndex((item) => item.definitionId === "pistol_ammo");
    if (ammoIndex < 0) return fail("NO_AMMO");
  }
  player.nextAttackTick = tick + (pistol ? PISTOL_COOLDOWN_TICKS : MELEE_COOLDOWN_TICKS);
  if (pistol) player.inventory.splice(ammoIndex, 1);

  const target = selectHit(player, zombies, payload, pistol ? PISTOL_RANGE : MELEE_RANGE);
  if (!target) return { ok: true, inventoryChanged: pistol };
  const damage = pistol ? PISTOL_DAMAGE : MELEE_DAMAGE;
  target.hp = Math.max(0, target.hp - damage);
  const killed = target.hp === 0;
  if (killed) killZombie(target, tick);
  return { ok: true, targetId: target.id, damage, killed, inventoryChanged: pistol };
}

function selectHit(player: CombatPlayer, zombies: Record<string, Zombie>, payload: AttackPayload, range: number): Zombie | null {
  let nearest: Zombie | null = null;
  let nearestDistance = Number.POSITIVE_INFINITY;
  for (const id of Object.keys(zombies)) {
    const zombie = zombies[id];
    if (zombie.hp <= 0) continue;
    const dx = zombie.x - player.x;
    const dy = zombie.y - player.y;
    const distance = Math.hypot(dx, dy);
    if (distance > range || distance < 0.001) continue;
    if ((dx / distance) * payload.aim_x + (dy / distance) * payload.aim_y < ATTACK_AIM_COSINE) continue;
    if (distance < nearestDistance) { nearest = zombie; nearestDistance = distance; }
  }
  return nearest;
}

function fail(code: string): AttackResult { return { ok: false, code }; }
