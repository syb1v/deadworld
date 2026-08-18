import { ATTACK_EVENT, CONTAINER_MUTATE, DAMAGE_EVENT, DEATH_EVENT, ERROR_EVENT, INPUT_ATTACK, INPUT_MOVE, INPUT_RELOAD, INVENTORY_SNAPSHOT, ITEM_DROP, ITEM_PICKUP, MAX_INPUTS_PER_SECOND, MAX_INTERACTIONS_PER_SECOND, PLAYER_MAX_HEALTH, PLAYER_RESPAWN_TICKS, PLAYER_SNAPSHOT, PLAYER_SPEED, PROTOCOL_VERSION, RELOAD_EVENT, RESPAWN_EVENT, TICK_RATE } from "./protocol";
import { parseMoveInput } from "./movement";
import { createZombies, repairZombiePositions, separateZombies, simulateZombie, Zombie } from "./zombies";
import { createItemState, dropItem, ItemInstance, ItemState, mutateContainer, parseInteraction, pickupItem } from "./items";
import { attack, parseAttack, parseReload, reload } from "./combat";
import { applyWorld, loadWorld, PersistedPlayer, PersistentWorld, snapshotWorld, writeWorld } from "./persistence";
import { moveWithCollision, PLAYER_RADIUS, repairPosition } from "./world";

interface Player {
  id: string; presence: nkruntime.Presence; x: number; y: number; vx: number; vy: number;
  inputX: number; inputY: number; lastSequence: number; rateWindow: number; rateCount: number;
  health: number; spawnIndex: number; respawnAtMs: number; lastAttackSequence: number; lastReloadSequence: number; nextAttackTick: number;
  inventory: ItemInstance[]; interactionWindow: number; interactionCount: number; inventoryDirty: boolean;
}
interface WorldState extends nkruntime.MatchState { players: Record<string, Player>; playerStates: Record<string, Player>; inventories: Record<string, ItemInstance[]>; persistedPlayers: Record<string, PersistedPlayer>; zombies: Record<string, Zombie>; items: ItemState; persistenceEnabled: boolean; persistenceLoaded: boolean; persistenceStale: boolean; persistenceKey: string; persistenceVersion: string; }

const PLAYER_SPAWNS = [[560, 360], [720, 360], [640, 280], [640, 440]];

export const worldMatch: nkruntime.MatchHandler = {
  matchInit(_ctx, logger, nk, params) {
    logger.info(JSON.stringify({ event: "world_created", protocol: PROTOCOL_VERSION }));
    const persistenceEnabled = params.persistence_enabled !== false;
    const activationRequired = params.activation_required === true;
    const state = { players: {}, playerStates: {}, inventories: {}, persistedPlayers: {}, zombies: createZombies(), items: createItemState(), persistenceEnabled, persistenceLoaded: !persistenceEnabled && !activationRequired, persistenceStale: false, persistenceKey: typeof params.persistence_key === "string" ? params.persistence_key : "main_world_v1", persistenceVersion: "" } as WorldState;
    return { state, tickRate: TICK_RATE, label: JSON.stringify({ world: "main", protocol: PROTOCOL_VERSION }) };
  },
  matchJoinAttempt(_ctx, _logger, _nk, _dispatcher, _tick, rawState, presence) {
    const state = rawState as WorldState;
    if (!state.persistenceLoaded) return { state, accept: false, rejectMessage: "WORLD_LOADING" };
    const duplicate = state.players[presence.userId] !== undefined;
    return { state, accept: !duplicate, rejectMessage: duplicate ? "USER_ALREADY_CONNECTED" : undefined };
  },
  matchJoin(_ctx, logger, _nk, dispatcher, _tick, rawState, presences) {
    const state = rawState as WorldState;
    for (const presence of presences) {
      if (state.players[presence.userId]) {
        logger.warn(JSON.stringify({ event: "duplicate_user_join_ignored", player_id: `player:${presence.userId}` }));
        continue;
      }
      let player = state.playerStates[presence.userId];
      if (!player) {
        const inventory = state.inventories[presence.userId] || [];
        state.inventories[presence.userId] = inventory;
        const usedSpawns = new Set(Object.values(state.playerStates).map((existing) => existing.spawnIndex));
        const spawnIndex = PLAYER_SPAWNS.findIndex((_spawn, index) => !usedSpawns.has(index));
        const assignedSpawnIndex = spawnIndex >= 0 ? spawnIndex : Object.keys(state.playerStates).length % PLAYER_SPAWNS.length;
        const saved = state.persistedPlayers[presence.userId];
        const spawn = PLAYER_SPAWNS[saved?.spawnIndex ?? assignedSpawnIndex];
        player = { id: `player:${presence.userId}`, presence, x: saved?.x ?? spawn[0], y: saved?.y ?? spawn[1], vx: 0, vy: 0, inputX: 0, inputY: 0, lastSequence: -1, rateWindow: 0, rateCount: 0, health: saved?.health ?? PLAYER_MAX_HEALTH, spawnIndex: saved?.spawnIndex ?? assignedSpawnIndex, respawnAtMs: saved?.respawnAtMs ?? 0, lastAttackSequence: -1, lastReloadSequence: -1, nextAttackTick: 0, inventory, interactionWindow: 0, interactionCount: 0, inventoryDirty: true };
        state.playerStates[presence.userId] = player;
      } else {
        player.presence = presence;
        player.inputX = 0; player.inputY = 0; player.vx = 0; player.vy = 0;
        player.lastSequence = -1; player.lastAttackSequence = -1; player.lastReloadSequence = -1;
        player.inventoryDirty = true;
      }
      state.players[presence.userId] = player;
      logger.info(JSON.stringify({ event: "player_join", player_id: `player:${presence.userId}` }));
    }
    dispatcher.matchLabelUpdate(JSON.stringify({ world: "main", protocol: PROTOCOL_VERSION, players: Object.keys(state.players).length }));
    return { state };
  },
  matchLeave(_ctx, logger, _nk, dispatcher, _tick, rawState, presences) {
    const state = rawState as WorldState;
    for (const presence of presences) {
      const player = state.players[presence.userId];
      if (player?.presence.sessionId === presence.sessionId) {
        state.playerStates[presence.userId] = player;
        state.inventories[presence.userId] = player.inventory;
        state.persistedPlayers[presence.userId] = { x: player.x, y: player.y, health: player.health, spawnIndex: player.spawnIndex, respawnAtMs: player.respawnAtMs };
        delete state.players[presence.userId];
      }
      logger.info(JSON.stringify({ event: "player_leave", player_id: `player:${presence.userId}` }));
    }
    dispatcher.matchLabelUpdate(JSON.stringify({ world: "main", protocol: PROTOCOL_VERSION, players: Object.keys(state.players).length }));
    return { state };
  },
  matchLoop(_ctx, logger, nk, dispatcher, tick, rawState, messages) {
    const state = rawState as WorldState;
    if (state.persistenceStale) return null;
    if (!state.persistenceLoaded) {
      try {
        state.persistenceVersion = loadWorld(nk, state);
        repairZombiePositions(state.zombies);
        for (const saved of Object.values(state.persistedPlayers)) {
          const spawn = PLAYER_SPAWNS[saved.spawnIndex] || PLAYER_SPAWNS[0];
          const repaired = repairPosition(saved, { x: spawn[0], y: spawn[1] }, PLAYER_RADIUS);
          saved.x = repaired.x; saved.y = repaired.y;
        }
        for (const item of Object.values(state.items.worldItems)) {
          const repaired = repairPosition(item, { x: 640, y: 360 }, 4);
          item.x = repaired.x; item.y = repaired.y;
        }
        for (const container of Object.values(state.items.containers)) {
          const repaired = repairPosition(container, { x: 640, y: 400 }, 12);
          container.x = repaired.x; container.y = repaired.y;
        }
        state.persistenceVersion = writeWorld(nk, state, state.persistenceVersion);
        state.persistenceLoaded = true;
        logger.info(JSON.stringify({ event: "persistence_loaded", key: state.persistenceKey, version: state.persistenceVersion, inventory_users: Object.keys(state.inventories).length }));
      }
      catch (error) { state.persistenceStale = true; logger.warn(JSON.stringify({ event: "persistence_writer_rejected", key: state.persistenceKey, error: String(error) })); }
      return { state };
    }
    for (const message of messages) {
      const player = state.players[message.sender.userId];
      if (!player || player.presence.sessionId !== message.sender.sessionId) continue;
      if (message.opCode !== INPUT_MOVE) {
        const second = Math.floor(tick / TICK_RATE);
        if (player.interactionWindow !== second) { player.interactionWindow = second; player.interactionCount = 0; }
        player.interactionCount += 1;
        if (player.interactionCount > MAX_INTERACTIONS_PER_SECOND) continue;
        const payload = parseInteraction(message.data);
        if (!payload) { sendError(dispatcher, player, "BAD_PAYLOAD"); continue; }
        if (player.health <= 0) { sendError(dispatcher, player, "PLAYER_DEAD"); continue; }
        let result;
        syncPersistedPlayers(state);
        const rollback = snapshotWorld(state);
        const runtimeRollback = captureRuntime(player);
        if (message.opCode === INPUT_ATTACK) {
          const input = parseAttack(payload);
          if (!input) { sendError(dispatcher, player, "BAD_PAYLOAD"); continue; }
          result = attack(player, state.zombies, input, tick);
          if (result.ok && (result.inventoryChanged || result.targetId) && !persistMutation(nk, state, rollback, logger)) { restoreRuntime(player, runtimeRollback); sendError(dispatcher, player, "PERSISTENCE_CONFLICT"); return null; }
          if (result.ok && result.inventoryChanged) player.inventoryDirty = true;
          if (result.ok) dispatcher.broadcastMessage(ATTACK_EVENT, JSON.stringify({ player_id: player.id, weapon: result.weapon, aim_x: result.aimX, aim_y: result.aimY, magazine_ammo: result.magazineAmmo }), null, null, true);
          if (result.ok && result.targetId) dispatcher.broadcastMessage(DAMAGE_EVENT, JSON.stringify({ source_id: player.id, target_id: result.targetId, damage: result.damage }), null, null, true);
          if (result.ok && result.killed) dispatcher.broadcastMessage(DEATH_EVENT, JSON.stringify({ entity_id: result.targetId }), null, null, true);
        } else if (message.opCode === INPUT_RELOAD) {
          const input = parseReload(payload);
          if (!input) { sendError(dispatcher, player, "BAD_PAYLOAD"); continue; }
          result = reload(player, input);
          if (result.ok) {
            if (!persistMutation(nk, state, rollback, logger)) { restoreRuntime(player, runtimeRollback); sendError(dispatcher, player, "PERSISTENCE_CONFLICT"); return null; }
            player.inventoryDirty = true;
            dispatcher.broadcastMessage(RELOAD_EVENT, JSON.stringify({ player_id: player.id, magazine_ammo: result.magazineAmmo, loaded: result.loaded, weapon_slot: result.weaponSlot }), null, null, true);
          }
        } else if (message.opCode === ITEM_PICKUP) result = pickupItem(state.items, player, payload.item_instance_id, payload.expected_world_version);
        else if (message.opCode === ITEM_DROP) result = dropItem(state.items, player, payload.item_instance_id);
        else if (message.opCode === CONTAINER_MUTATE) result = mutateContainer(state.items, player, payload);
        else continue;
        if (!result.ok) sendError(dispatcher, player, result.code || "MUTATION_REJECTED");
        else {
          if (message.opCode !== INPUT_ATTACK && message.opCode !== INPUT_RELOAD && !persistMutation(nk, state, rollback, logger)) { sendError(dispatcher, player, "PERSISTENCE_CONFLICT"); return null; }
          player.inventoryDirty = true;
        }
        continue;
      }
      const second = Math.floor(tick / TICK_RATE);
      if (player.rateWindow !== second) { player.rateWindow = second; player.rateCount = 0; }
      player.rateCount += 1;
      if (player.rateCount > MAX_INPUTS_PER_SECOND) continue;
      const input = parseMoveInput(message.data);
      if (!input || input.sequence <= player.lastSequence) {
        logger.warn(JSON.stringify({ event: "move_rejected", player_id: player.id }));
        continue;
      }
      player.inputX = input.x; player.inputY = input.y; player.lastSequence = input.sequence;
    }
    const dt = 1 / TICK_RATE;
    const dueRespawns: Player[] = [];
    for (const sessionId of Object.keys(state.players)) {
      const player = state.players[sessionId];
      if (player.health <= 0) {
        player.inputX = 0; player.inputY = 0; player.vx = 0; player.vy = 0;
        if (Date.now() >= player.respawnAtMs) dueRespawns.push(player);
        continue;
      }
      player.vx = player.inputX * PLAYER_SPEED; player.vy = player.inputY * PLAYER_SPEED;
      const moved = moveWithCollision(player, { x: player.vx * dt, y: player.vy * dt }, PLAYER_RADIUS);
      player.x = moved.x; player.y = moved.y;
    }
    if (dueRespawns.length > 0) {
      syncPersistedPlayers(state);
      const respawnRollback = snapshotWorld(state);
      for (const player of dueRespawns) respawnPlayer(player);
      if (!persistMutation(nk, state, respawnRollback, logger)) return null;
      for (const player of dueRespawns) dispatcher.broadcastMessage(RESPAWN_EVENT, JSON.stringify({ player_id: player.id, x: player.x, y: player.y, health: player.health }), null, null, true);
    }
    const targets = Object.keys(state.players).map((sessionId) => state.players[sessionId]);
    const healthBefore = new Map(targets.map((player) => [player.id, player.health]));
    syncPersistedPlayers(state);
    const simulationRollback = snapshotWorld(state);
    for (const id of Object.keys(state.zombies)) simulateZombie(state.zombies[id], targets, tick, dt);
    separateZombies(state.zombies);
    const damageEvents: { player: Player; damage: number }[] = [];
    const deathEvents: Player[] = [];
    for (const player of targets) {
      const previousHealth = healthBefore.get(player.id) || 0;
      if (player.health < previousHealth) damageEvents.push({ player, damage: previousHealth - player.health });
      if (previousHealth > 0 && player.health === 0) {
        killPlayer(state, player, tick);
        deathEvents.push(player);
      }
    }
    let simulationCommitted = true;
    if (deathEvents.length > 0) {
      syncPersistedPlayers(state);
      simulationCommitted = persistMutation(nk, state, simulationRollback, logger);
    }
    if (!simulationCommitted) return null;
    if (simulationCommitted) {
      for (const event of damageEvents) dispatcher.broadcastMessage(DAMAGE_EVENT, JSON.stringify({ source_id: "zombie", target_id: event.player.id, damage: event.damage }), null, null, true);
      for (const player of deathEvents) dispatcher.broadcastMessage(DEATH_EVENT, JSON.stringify({ player_id: player.id, respawn_tick: tick + Math.ceil(Math.max(0, player.respawnAtMs - Date.now()) * TICK_RATE / 1000) }), null, null, true);
    }
    if (tick % TICK_RATE === 0) {
      syncPersistedPlayers(state);
      try { state.persistenceVersion = writeWorld(nk, state, state.persistenceVersion); } catch (error) { state.persistenceStale = true; logger.warn(JSON.stringify({ event: "periodic_persistence_failed", error: String(error) })); return null; }
    }
    const players = Object.keys(state.players).map((sessionId) => {
      const player = state.players[sessionId];
      return { id: player.id, x: player.x, y: player.y, vx: player.vx, vy: player.vy, health: player.health, state: player.health <= 0 ? "dead" : player.vx || player.vy ? "move" : "idle" };
    });
    const zombies = Object.keys(state.zombies).sort().map((id) => {
      const zombie = state.zombies[id];
      return { id: zombie.id, x: zombie.x, y: zombie.y, vx: zombie.vx, vy: zombie.vy, hp: zombie.hp, state: zombie.state, target_id: zombie.targetId };
    });
    const worldItems = Object.keys(state.items.worldItems).sort().map((id) => state.items.worldItems[id]);
    const containers = Object.keys(state.items.containers).sort().map((id) => state.items.containers[id]);
    dispatcher.broadcastMessage(PLAYER_SNAPSHOT, JSON.stringify({ protocol: PROTOCOL_VERSION, tick, players, zombies, world_version: state.items.worldVersion, world_items: worldItems, containers }), null, null, false);
    for (const sessionId of Object.keys(state.players)) {
      const player = state.players[sessionId];
      if (!player.inventoryDirty && tick % TICK_RATE !== 0) continue;
      dispatcher.broadcastMessage(INVENTORY_SNAPSHOT, JSON.stringify({ protocol: PROTOCOL_VERSION, items: player.inventory }), [player.presence], null, true);
      player.inventoryDirty = false;
    }
    return { state };
  },
  matchTerminate(_ctx, logger, nk, _dispatcher, _tick, rawState, _grace) {
    const state = rawState as WorldState;
    syncPersistedPlayers(state);
    try { state.persistenceVersion = writeWorld(nk, state, state.persistenceVersion); } catch (error) { logger.warn(JSON.stringify({ event: "final_persistence_failed", error: String(error) })); }
    return { state };
  },
  matchSignal(_ctx, _logger, _nk, _dispatcher, _tick, rawState, data) {
    const state = rawState as WorldState;
    if (data === "terminate") return null;
    if (data === "activate_persistence") { state.persistenceEnabled = true; state.persistenceLoaded = false; return { state, data: "activated" }; }
    return { state, data };
  }
};

function sendError(dispatcher: nkruntime.MatchDispatcher, player: Player, code: string): void {
  dispatcher.broadcastMessage(ERROR_EVENT, JSON.stringify({ code }), [player.presence], null, true);
}

function captureRuntime(player: Player) { return { lastAttackSequence: player.lastAttackSequence, lastReloadSequence: player.lastReloadSequence, nextAttackTick: player.nextAttackTick, respawnAtMs: player.respawnAtMs }; }
function restoreRuntime(player: Player, value: ReturnType<typeof captureRuntime>): void { player.lastAttackSequence = value.lastAttackSequence; player.lastReloadSequence = value.lastReloadSequence; player.nextAttackTick = value.nextAttackTick; player.respawnAtMs = value.respawnAtMs; }

function killPlayer(state: WorldState, player: Player, _tick: number): void {
  player.respawnAtMs = Date.now() + PLAYER_RESPAWN_TICKS * (1000 / TICK_RATE);
  player.inputX = 0; player.inputY = 0; player.vx = 0; player.vy = 0;
  while (player.inventory.length > 0) {
    const item = player.inventory.pop()!;
    state.items.worldItems[item.id] = { ...item, x: player.x, y: player.y };
    state.items.worldVersion += 1;
  }
  player.inventoryDirty = true;
}

function syncPersistedPlayers(state: WorldState): void {
  for (const userId of Object.keys(state.players)) {
    const player = state.players[userId];
    state.playerStates[userId] = player;
    state.inventories[userId] = player.inventory;
  }
  for (const userId of Object.keys(state.playerStates)) {
    const player = state.playerStates[userId];
    state.persistedPlayers[userId] = { x: player.x, y: player.y, health: player.health, spawnIndex: player.spawnIndex, respawnAtMs: player.respawnAtMs };
  }
}

function persistMutation(nk: nkruntime.Nakama, state: WorldState, rollback: PersistentWorld, logger: nkruntime.Logger): boolean {
  syncPersistedPlayers(state);
  try {
    state.persistenceVersion = writeWorld(nk, state, state.persistenceVersion);
    return true;
  } catch (error) {
    state.persistenceStale = true;
    logger.warn(JSON.stringify({ event: "persistence_mutation_rollback", error: String(error) }));
    applyWorld(state, rollback);
    for (const userId of Object.keys(state.playerStates)) {
      const player = state.playerStates[userId];
      player.inventory = state.inventories[userId] || [];
      const saved = state.persistedPlayers[userId];
      if (saved) { player.x = saved.x; player.y = saved.y; player.health = saved.health; player.spawnIndex = saved.spawnIndex; player.respawnAtMs = saved.respawnAtMs; }
      player.inventoryDirty = true;
    }
    return false;
  }
}

function respawnPlayer(player: Player): void {
  const spawn = PLAYER_SPAWNS[player.spawnIndex];
  player.x = spawn[0]; player.y = spawn[1]; player.health = PLAYER_MAX_HEALTH; player.respawnAtMs = 0; player.nextAttackTick = 0;
}

export const findWorld: nkruntime.RpcFunction = (_ctx, _logger, nk, _payload) => {
  const systemUser = "00000000-0000-0000-0000-000000000000";
  const records = nk.storageRead([{ collection: "system", key: "main_world", userId: systemUser }]);
  let matchId = records.length > 0 ? String(records[0].value.match_id || "") : "";
  if (!matchId || nk.matchGet(matchId) === null) {
    const candidate = nk.matchCreate("world", { persistence_enabled: false, activation_required: true, persistence_key: "main_world_v1" });
    try {
      nk.storageWrite([{ collection: "system", key: "main_world", userId: systemUser, value: { match_id: candidate }, version: records.length > 0 ? records[0].version : "*", permissionRead: 0, permissionWrite: 0 }]);
    } catch (_error) {
      nk.matchSignal(candidate, "terminate");
      const winner = nk.storageRead([{ collection: "system", key: "main_world", userId: systemUser }]);
      if (winner.length === 0) throw new Error("Main world publication conflict without winner");
      matchId = String(winner[0].value.match_id || "");
      return JSON.stringify({ match_id: matchId, protocol: PROTOCOL_VERSION });
    }
    nk.matchSignal(candidate, "activate_persistence");
    matchId = candidate;
  }
  return JSON.stringify({ match_id: matchId, protocol: PROTOCOL_VERSION });
};

export const createTestWorld: nkruntime.RpcFunction = (ctx, _logger, nk, _payload) => {
  if (ctx.userId) throw new Error("Server-to-server authentication required");
  const matchId = nk.matchCreate("world", { persistence_enabled: false });
  return JSON.stringify({ match_id: matchId, protocol: PROTOCOL_VERSION });
};

export const createRestartTestWorld: nkruntime.RpcFunction = (ctx, _logger, nk, _payload) => {
  if (ctx.userId) throw new Error("Server-to-server authentication required");
  const systemUser = "00000000-0000-0000-0000-000000000000";
  const pointer = nk.storageRead([{ collection: "system", key: "restart_test_pointer", userId: systemUser }]);
  const token = nk.uuidv4().replace(/-/g, "");
  nk.storageWrite([{ collection: "system", key: "restart_test_pointer", userId: systemUser, value: { token }, version: pointer.length > 0 ? pointer[0].version : "*", permissionRead: 0, permissionWrite: 0 }]);
  const matchId = nk.matchCreate("world", { persistence_key: `test_restart_${token}` });
  return JSON.stringify({ match_id: matchId, token, protocol: PROTOCOL_VERSION });
};

export const resumeRestartTestWorld: nkruntime.RpcFunction = (ctx, _logger, nk, _payload) => {
  if (ctx.userId) throw new Error("Server-to-server authentication required");
  const pointer = nk.storageRead([{ collection: "system", key: "restart_test_pointer", userId: "00000000-0000-0000-0000-000000000000" }]);
  if (pointer.length === 0 || typeof pointer[0].value.token !== "string") throw new Error("Restart fixture pointer missing");
  const token = pointer[0].value.token;
  const matchId = nk.matchCreate("world", { persistence_key: `test_restart_${token}` });
  return JSON.stringify({ match_id: matchId, token, protocol: PROTOCOL_VERSION });
};
