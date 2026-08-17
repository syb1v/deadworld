import { ItemInstance, ItemState } from "./items";
import { Zombie } from "./zombies";

const SYSTEM_USER = "00000000-0000-0000-0000-000000000000";
const COLLECTION = "deadworld";
const MAIN_KEY = "main_world_v1";
export const PERSISTENCE_SCHEMA = 1;

export interface PersistedPlayer { x: number; y: number; health: number; spawnIndex: number; respawnAtMs: number; }
export interface PersistentWorld {
  schema: number;
  items: ItemState;
  inventories: Record<string, ItemInstance[]>;
  players: Record<string, PersistedPlayer>;
  zombies: Record<string, { x: number; y: number; hp: number }>;
}

export interface PersistenceSource {
  persistenceEnabled?: boolean;
  persistenceKey?: string;
  items: ItemState;
  inventories: Record<string, ItemInstance[]>;
  persistedPlayers: Record<string, PersistedPlayer>;
  zombies: Record<string, Zombie>;
}

export function snapshotWorld(source: PersistenceSource): PersistentWorld {
  const zombies: PersistentWorld["zombies"] = {};
  for (const id of Object.keys(source.zombies)) {
    const zombie = source.zombies[id];
    zombies[id] = { x: zombie.x, y: zombie.y, hp: zombie.hp };
  }
  return clone({ schema: PERSISTENCE_SCHEMA, items: source.items, inventories: source.inventories, players: source.persistedPlayers, zombies });
}

export function applyWorld(source: PersistenceSource, persisted: PersistentWorld): void {
  source.items = clone(persisted.items);
  source.inventories = clone(persisted.inventories);
  source.persistedPlayers = clone(persisted.players);
  for (const id of Object.keys(source.zombies)) {
    const saved = persisted.zombies[id];
    if (!saved) continue;
    const zombie = source.zombies[id];
    zombie.x = saved.x; zombie.y = saved.y; zombie.hp = Math.max(0, saved.hp);
    zombie.vx = 0; zombie.vy = 0; zombie.targetId = ""; zombie.nextAttackTick = 0;
    zombie.state = zombie.hp === 0 ? "DEAD" : "IDLE";
  }
}

export function loadWorld(nk: nkruntime.Nakama, source: PersistenceSource): string {
  if (source.persistenceEnabled === false) return "";
  const records = nk.storageRead([{ collection: COLLECTION, key: source.persistenceKey || MAIN_KEY, userId: SYSTEM_USER }]);
  if (records.length === 0) return "";
  const value = records[0].value as unknown as PersistentWorld;
  if (value.schema !== PERSISTENCE_SCHEMA) throw new Error(`Unsupported persistence schema: ${value.schema}`);
  applyWorld(source, value);
  return records[0].version;
}

export function writeWorld(nk: nkruntime.Nakama, source: PersistenceSource, version: string): string {
  if (source.persistenceEnabled === false) return version;
  const request: nkruntime.StorageWriteRequest = { collection: COLLECTION, key: source.persistenceKey || MAIN_KEY, userId: SYSTEM_USER, value: snapshotWorld(source) as unknown as Record<string, unknown>, permissionRead: 0, permissionWrite: 0 };
  request.version = version || "*";
  const acknowledgements = nk.storageWrite([request]);
  if (acknowledgements.length !== 1) throw new Error("World persistence write was not acknowledged");
  return acknowledgements[0].version;
}

function clone<T>(value: T): T { return JSON.parse(JSON.stringify(value)) as T; }
