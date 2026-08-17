import definitions from "../../shared/data/items.json";
import { INTERACTION_RANGE, INVENTORY_CAPACITY, MAX_INTERACTION_BYTES } from "./protocol";
import { movementPayloadText } from "./movement";

export const ITEM_DEFINITIONS = definitions;

export interface ItemInstance { id: string; definitionId: keyof typeof definitions; quantity?: number; magazineAmmo?: number; }
export interface WorldItem extends ItemInstance { x: number; y: number; }
export interface Container { id: string; x: number; y: number; version: number; items: ItemInstance[]; }
export interface ItemPlayer { id: string; x: number; y: number; inventory: ItemInstance[]; }
export interface ItemState { worldVersion: number; worldItems: Record<string, WorldItem>; containers: Record<string, Container>; }
export interface MutationResult { ok: boolean; code?: string; }

export function createItemState(): ItemState {
  return {
    worldVersion: 1,
    worldItems: {
      "item:world-bandage": { id: "item:world-bandage", definitionId: "bandage", quantity: 3, x: 640, y: 360 },
      "item:world-water": { id: "item:world-water", definitionId: "water_bottle", x: 690, y: 360 },
      "item:world-bat": { id: "item:world-bat", definitionId: "baseball_bat", x: 575, y: 360 },
      "item:world-pistol": { id: "item:world-pistol", definitionId: "pistol", magazineAmmo: 0, x: 590, y: 360 },
      "item:world-ammo-1": { id: "item:world-ammo-1", definitionId: "pistol_ammo", quantity: 24, x: 605, y: 360 },
      "item:world-bat-2": { id: "item:world-bat-2", definitionId: "baseball_bat", x: 705, y: 390 }
    },
    containers: {
      "container:clinic": {
        id: "container:clinic", x: 640, y: 400, version: 1,
        items: [
          { id: "item:clinic-beans", definitionId: "canned_beans" },
          { id: "item:clinic-scrap", definitionId: "scrap_metal" }
        ]
      }
    }
  };
}

export function parseInteraction(data: string | ArrayBuffer | Uint8Array): Record<string, unknown> | null {
  const payload = movementPayloadText(data);
  if (payload.length === 0 || payload.length > MAX_INTERACTION_BYTES) return null;
  try {
    const parsed = JSON.parse(payload);
    return parsed && typeof parsed === "object" && !Array.isArray(parsed) ? parsed as Record<string, unknown> : null;
  } catch (_) { return null; }
}

export function pickupItem(state: ItemState, player: ItemPlayer, itemId: unknown, expectedVersion: unknown): MutationResult {
  if (typeof itemId !== "string" || !Number.isSafeInteger(expectedVersion)) return fail("BAD_PAYLOAD");
  if (expectedVersion !== state.worldVersion) return fail("STALE_WORLD_VERSION");
  const item = state.worldItems[itemId];
  if (!item) return fail("ITEM_NOT_AVAILABLE");
  if (!withinRange(player, item)) return fail("OUT_OF_RANGE");
  if (!canAdd(player.inventory, item)) return fail("INVENTORY_FULL");
  delete state.worldItems[itemId];
  addToInventory(player.inventory, item);
  state.worldVersion += 1;
  return { ok: true };
}

export function dropItem(state: ItemState, player: ItemPlayer, itemId: unknown): MutationResult {
  if (typeof itemId !== "string") return fail("BAD_PAYLOAD");
  const index = player.inventory.findIndex((item) => item.id === itemId);
  if (index < 0) return fail("ITEM_NOT_OWNED");
  const item = player.inventory.splice(index, 1)[0];
  state.worldItems[item.id] = { ...item, x: player.x, y: player.y };
  state.worldVersion += 1;
  return { ok: true };
}

export function mutateContainer(state: ItemState, player: ItemPlayer, payload: Record<string, unknown>): MutationResult {
  const containerId = payload.container_id;
  const itemId = payload.item_instance_id;
  const operation = payload.operation;
  const expectedVersion = payload.expected_version;
  if (typeof containerId !== "string" || typeof itemId !== "string" || typeof operation !== "string" || !Number.isSafeInteger(expectedVersion)) return fail("BAD_PAYLOAD");
  const container = state.containers[containerId];
  if (!container) return fail("CONTAINER_NOT_FOUND");
  if (!withinRange(player, container)) return fail("OUT_OF_RANGE");
  if (expectedVersion !== container.version) return fail("STALE_CONTAINER_VERSION");
  if (operation === "take") {
    const index = container.items.findIndex((item) => item.id === itemId);
    if (index < 0) return fail("ITEM_NOT_AVAILABLE");
    const item = container.items[index];
    if (!canAdd(player.inventory, item)) return fail("INVENTORY_FULL");
    container.items.splice(index, 1);
    addToInventory(player.inventory, item);
  } else if (operation === "deposit") {
    const index = player.inventory.findIndex((item) => item.id === itemId);
    if (index < 0) return fail("ITEM_NOT_OWNED");
    container.items.push(player.inventory.splice(index, 1)[0]);
  } else return fail("BAD_OPERATION");
  container.version += 1;
  return { ok: true };
}

export function itemQuantity(item: ItemInstance): number { return item.quantity || 1; }

function canAdd(inventory: ItemInstance[], item: ItemInstance): boolean {
  let remaining = itemQuantity(item);
  const limit = definitions[item.definitionId].stack_size;
  for (const existing of inventory) {
    if (existing.definitionId === item.definitionId && limit > 1) remaining -= Math.max(0, limit - itemQuantity(existing));
  }
  return remaining <= 0 || Math.ceil(remaining / limit) <= INVENTORY_CAPACITY - inventory.length;
}

function addToInventory(inventory: ItemInstance[], item: ItemInstance): void {
  let remaining = itemQuantity(item);
  const limit = definitions[item.definitionId].stack_size;
  if (limit > 1) {
    for (const existing of inventory) {
      if (existing.definitionId !== item.definitionId) continue;
      const moved = Math.min(remaining, limit - itemQuantity(existing));
      if (moved <= 0) continue;
      existing.quantity = itemQuantity(existing) + moved;
      remaining -= moved;
      if (remaining === 0) return;
    }
  }
  while (remaining > 0) {
    const moved = Math.min(remaining, limit);
    inventory.push({ id: item.id, definitionId: item.definitionId, quantity: limit > 1 ? moved : undefined, magazineAmmo: item.magazineAmmo });
    remaining -= moved;
  }
}

function withinRange(a: { x: number; y: number }, b: { x: number; y: number }): boolean {
  return Math.hypot(a.x - b.x, a.y - b.y) <= INTERACTION_RANGE;
}

function fail(code: string): MutationResult { return { ok: false, code }; }
