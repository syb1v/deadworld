import {
  ZOMBIE_ATTACK_COOLDOWN_TICKS,
  ZOMBIE_ATTACK_DAMAGE,
  ZOMBIE_ATTACK_RANGE,
  ZOMBIE_ATTACK_RELEASE_RANGE,
  ZOMBIE_DETECTION_RANGE,
  ZOMBIE_SEPARATION_DISTANCE,
  ZOMBIE_SPEED,
  ZOMBIE_TARGET_RELEASE_RANGE
} from "./protocol";

export type ZombieMode = "IDLE" | "CHASE" | "ATTACK" | "DEAD";

export interface ZombieTarget {
  id: string;
  x: number;
  y: number;
  health: number;
}

export interface Zombie {
  id: string;
  x: number;
  y: number;
  vx: number;
  vy: number;
  hp: number;
  state: ZombieMode;
  targetId: string;
  nextAttackTick: number;
  spawnX: number;
  spawnY: number;
}

export function createZombies(): Record<string, Zombie> {
  const spawns = [[420, 360], [820, 260], [760, 520]];
  const zombies: Record<string, Zombie> = {};
  for (let index = 0; index < spawns.length; index += 1) {
    const id = `zombie:main-${index + 1}`;
    zombies[id] = { id, x: spawns[index][0], y: spawns[index][1], vx: 0, vy: 0, hp: 30, state: "IDLE", targetId: "", nextAttackTick: 0, spawnX: spawns[index][0], spawnY: spawns[index][1] };
  }
  return zombies;
}

export function simulateZombie(zombie: Zombie, players: ZombieTarget[], tick: number, dt: number): void {
  if (zombie.hp <= 0) {
    zombie.hp = 0;
    zombie.vx = 0;
    zombie.vy = 0;
    zombie.state = "DEAD";
    zombie.targetId = "";
    return;
  }

  const target = selectTarget(zombie, players);
  if (!target) {
    zombie.vx = 0;
    zombie.vy = 0;
    zombie.state = "IDLE";
    zombie.targetId = "";
    return;
  }

  const dx = target.x - zombie.x;
  const dy = target.y - zombie.y;
  const distance = Math.sqrt(dx * dx + dy * dy);
  if (distance > ZOMBIE_DETECTION_RANGE) {
    zombie.vx = 0;
    zombie.vy = 0;
    zombie.state = "IDLE";
    zombie.targetId = "";
    return;
  }

  zombie.targetId = target.id;
  const attackRange = zombie.state === "ATTACK" ? ZOMBIE_ATTACK_RELEASE_RANGE : ZOMBIE_ATTACK_RANGE;
  if (distance <= attackRange) {
    zombie.vx = 0;
    zombie.vy = 0;
    zombie.state = "ATTACK";
    if (tick >= zombie.nextAttackTick) {
      target.health = Math.max(0, target.health - ZOMBIE_ATTACK_DAMAGE);
      zombie.nextAttackTick = tick + ZOMBIE_ATTACK_COOLDOWN_TICKS;
    }
    return;
  }

  zombie.state = "CHASE";
  zombie.vx = dx / distance * ZOMBIE_SPEED;
  zombie.vy = dy / distance * ZOMBIE_SPEED;
  const step = Math.min(distance - ZOMBIE_ATTACK_RANGE, ZOMBIE_SPEED * dt);
  zombie.x += dx / distance * step;
  zombie.y += dy / distance * step;
}

export function killZombie(zombie: Zombie, tick: number): void {
  zombie.hp = 0; zombie.vx = 0; zombie.vy = 0; zombie.state = "DEAD"; zombie.targetId = "";
}

export function separateZombies(zombies: Record<string, Zombie>): void {
  const living = Object.keys(zombies).sort().map((id) => zombies[id]).filter((zombie) => zombie.hp > 0);
  for (let leftIndex = 0; leftIndex < living.length; leftIndex += 1) {
    for (let rightIndex = leftIndex + 1; rightIndex < living.length; rightIndex += 1) {
      const left = living[leftIndex];
      const right = living[rightIndex];
      let dx = right.x - left.x;
      let dy = right.y - left.y;
      let distance = Math.hypot(dx, dy);
      if (distance >= ZOMBIE_SEPARATION_DISTANCE) continue;
      if (distance < 0.001) { dx = 1; dy = 0; distance = 0; }
      const correction = (ZOMBIE_SEPARATION_DISTANCE - distance) / 2;
      const directionLength = Math.hypot(dx, dy);
      left.x -= dx / directionLength * correction; left.y -= dy / directionLength * correction;
      right.x += dx / directionLength * correction; right.y += dy / directionLength * correction;
    }
  }
}

function selectTarget(zombie: Zombie, players: ZombieTarget[]): ZombieTarget | null {
  const current = players.find((player) => player.id === zombie.targetId && player.health > 0);
  if (current && distanceSquared(zombie, current) <= ZOMBIE_TARGET_RELEASE_RANGE * ZOMBIE_TARGET_RELEASE_RANGE) return current;

  let nearest: ZombieTarget | null = null;
  let nearestDistanceSquared = Number.POSITIVE_INFINITY;
  for (const player of players) {
    if (player.health <= 0) continue;
    const candidateDistanceSquared = distanceSquared(zombie, player);
    if (candidateDistanceSquared < nearestDistanceSquared || (candidateDistanceSquared === nearestDistanceSquared && player.id < (nearest?.id || ""))) {
      nearest = player;
      nearestDistanceSquared = candidateDistanceSquared;
    }
  }
  return nearest;
}

function distanceSquared(zombie: Zombie, player: ZombieTarget): number {
  const dx = player.x - zombie.x;
  const dy = player.y - zombie.y;
  return dx * dx + dy * dy;
}
