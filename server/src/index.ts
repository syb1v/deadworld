import { ATTACK_EVENT, CONTAINER_MUTATE, DAMAGE_EVENT, DEATH_EVENT, ERROR_EVENT, INPUT_ATTACK, INPUT_MOVE, INPUT_RELOAD, INVENTORY_SNAPSHOT, ITEM_DROP, ITEM_PICKUP, MAX_INPUTS_PER_SECOND, MAX_INTERACTIONS_PER_SECOND, PLAYER_MAX_HEALTH, PLAYER_RESPAWN_TICKS, PLAYER_SNAPSHOT, PLAYER_SPEED, PROTOCOL_VERSION, RELOAD_EVENT, RESPAWN_EVENT, TICK_RATE } from "./protocol";
import { parseMoveInput } from "./movement";
import { createZombies, separateZombies, simulateZombie, Zombie } from "./zombies";
import { createItemState, dropItem, ItemInstance, ItemState, mutateContainer, parseInteraction, pickupItem } from "./items";
import { attack, parseAttack, parseReload, reload } from "./combat";

interface Player {
  id: string; presence: nkruntime.Presence; x: number; y: number; vx: number; vy: number;
  inputX: number; inputY: number; lastSequence: number; rateWindow: number; rateCount: number;
  health: number; spawnIndex: number; respawnAtTick: number; lastAttackSequence: number; lastReloadSequence: number; nextAttackTick: number;
  inventory: ItemInstance[]; interactionWindow: number; interactionCount: number; inventoryDirty: boolean;
}
interface WorldState extends nkruntime.MatchState { players: Record<string, Player>; playerStates: Record<string, Player>; inventories: Record<string, ItemInstance[]>; zombies: Record<string, Zombie>; items: ItemState; }

const PLAYER_SPAWNS = [[560, 360], [720, 360], [640, 280], [640, 440]];

export const worldMatch: nkruntime.MatchHandler = {
  matchInit(_ctx, logger, _nk, _params) {
    logger.info(JSON.stringify({ event: "world_created", protocol: PROTOCOL_VERSION }));
    return { state: { players: {}, playerStates: {}, inventories: {}, zombies: createZombies(), items: createItemState() } as WorldState, tickRate: TICK_RATE, label: JSON.stringify({ world: "main", protocol: PROTOCOL_VERSION }) };
  },
  matchJoinAttempt(_ctx, _logger, _nk, _dispatcher, _tick, rawState, presence) {
    const state = rawState as WorldState;
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
        const spawn = PLAYER_SPAWNS[assignedSpawnIndex];
        player = { id: `player:${presence.userId}`, presence, x: spawn[0], y: spawn[1], vx: 0, vy: 0, inputX: 0, inputY: 0, lastSequence: -1, rateWindow: 0, rateCount: 0, health: PLAYER_MAX_HEALTH, spawnIndex: assignedSpawnIndex, respawnAtTick: 0, lastAttackSequence: -1, lastReloadSequence: -1, nextAttackTick: 0, inventory, interactionWindow: 0, interactionCount: 0, inventoryDirty: true };
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
      if (player?.presence.sessionId === presence.sessionId) delete state.players[presence.userId];
      logger.info(JSON.stringify({ event: "player_leave", player_id: `player:${presence.userId}` }));
    }
    dispatcher.matchLabelUpdate(JSON.stringify({ world: "main", protocol: PROTOCOL_VERSION, players: Object.keys(state.players).length }));
    return { state };
  },
  matchLoop(_ctx, logger, _nk, dispatcher, tick, rawState, messages) {
    const state = rawState as WorldState;
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
        if (message.opCode === INPUT_ATTACK) {
          const input = parseAttack(payload);
          if (!input) { sendError(dispatcher, player, "BAD_PAYLOAD"); continue; }
          result = attack(player, state.zombies, input, tick);
          if (result.ok && result.inventoryChanged) player.inventoryDirty = true;
          if (result.ok) dispatcher.broadcastMessage(ATTACK_EVENT, JSON.stringify({ player_id: player.id, weapon: result.weapon, aim_x: result.aimX, aim_y: result.aimY, magazine_ammo: result.magazineAmmo }), null, null, true);
          if (result.ok && result.targetId) dispatcher.broadcastMessage(DAMAGE_EVENT, JSON.stringify({ source_id: player.id, target_id: result.targetId, damage: result.damage }), null, null, true);
          if (result.ok && result.killed) dispatcher.broadcastMessage(DEATH_EVENT, JSON.stringify({ entity_id: result.targetId }), null, null, true);
        } else if (message.opCode === INPUT_RELOAD) {
          const input = parseReload(payload);
          if (!input) { sendError(dispatcher, player, "BAD_PAYLOAD"); continue; }
          result = reload(player, input);
          if (result.ok) {
            player.inventoryDirty = true;
            dispatcher.broadcastMessage(RELOAD_EVENT, JSON.stringify({ player_id: player.id, magazine_ammo: result.magazineAmmo, loaded: result.loaded, weapon_slot: result.weaponSlot }), null, null, true);
          }
        } else if (message.opCode === ITEM_PICKUP) result = pickupItem(state.items, player, payload.item_instance_id, payload.expected_world_version);
        else if (message.opCode === ITEM_DROP) result = dropItem(state.items, player, payload.item_instance_id);
        else if (message.opCode === CONTAINER_MUTATE) result = mutateContainer(state.items, player, payload);
        else continue;
        if (!result.ok) sendError(dispatcher, player, result.code || "MUTATION_REJECTED");
        else player.inventoryDirty = true;
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
    for (const sessionId of Object.keys(state.players)) {
      const player = state.players[sessionId];
      if (player.health <= 0) {
        player.inputX = 0; player.inputY = 0; player.vx = 0; player.vy = 0;
        if (tick >= player.respawnAtTick) respawnPlayer(player, dispatcher);
        continue;
      }
      player.vx = player.inputX * PLAYER_SPEED; player.vy = player.inputY * PLAYER_SPEED;
      player.x += player.vx * dt; player.y += player.vy * dt;
    }
    const targets = Object.keys(state.players).map((sessionId) => state.players[sessionId]);
    const healthBefore = new Map(targets.map((player) => [player.id, player.health]));
    for (const id of Object.keys(state.zombies)) simulateZombie(state.zombies[id], targets, tick, dt);
    separateZombies(state.zombies);
    for (const player of targets) {
      const previousHealth = healthBefore.get(player.id) || 0;
      if (player.health < previousHealth) dispatcher.broadcastMessage(DAMAGE_EVENT, JSON.stringify({ source_id: "zombie", target_id: player.id, damage: previousHealth - player.health }), null, null, true);
      if (previousHealth > 0 && player.health === 0) killPlayer(state, player, tick, dispatcher);
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
  matchTerminate(_ctx, _logger, _nk, _dispatcher, _tick, state, _grace) { return { state }; },
  matchSignal(_ctx, _logger, _nk, _dispatcher, _tick, state, data) { return { state, data }; }
};

function sendError(dispatcher: nkruntime.MatchDispatcher, player: Player, code: string): void {
  dispatcher.broadcastMessage(ERROR_EVENT, JSON.stringify({ code }), [player.presence], null, true);
}

function killPlayer(state: WorldState, player: Player, tick: number, dispatcher: nkruntime.MatchDispatcher): void {
  player.respawnAtTick = tick + PLAYER_RESPAWN_TICKS;
  player.inputX = 0; player.inputY = 0; player.vx = 0; player.vy = 0;
  while (player.inventory.length > 0) {
    const item = player.inventory.pop()!;
    state.items.worldItems[item.id] = { ...item, x: player.x, y: player.y };
    state.items.worldVersion += 1;
  }
  player.inventoryDirty = true;
  dispatcher.broadcastMessage(DEATH_EVENT, JSON.stringify({ player_id: player.id, respawn_tick: player.respawnAtTick }), null, null, true);
}

function respawnPlayer(player: Player, dispatcher: nkruntime.MatchDispatcher): void {
  const spawn = PLAYER_SPAWNS[player.spawnIndex];
  player.x = spawn[0]; player.y = spawn[1]; player.health = PLAYER_MAX_HEALTH; player.respawnAtTick = 0; player.nextAttackTick = 0;
  dispatcher.broadcastMessage(RESPAWN_EVENT, JSON.stringify({ player_id: player.id, x: player.x, y: player.y, health: player.health }), null, null, true);
}

export const findWorld: nkruntime.RpcFunction = (_ctx, _logger, nk, _payload) => {
  const systemUser = "00000000-0000-0000-0000-000000000000";
  const records = nk.storageRead([{ collection: "system", key: "main_world", userId: systemUser }]);
  let matchId = records.length > 0 ? String(records[0].value.match_id || "") : "";
  if (!matchId || nk.matchGet(matchId) === null) {
    matchId = nk.matchCreate("world", {});
    nk.storageWrite([{ collection: "system", key: "main_world", userId: systemUser, value: { match_id: matchId }, permissionRead: 0, permissionWrite: 0 }]);
  }
  return JSON.stringify({ match_id: matchId, protocol: PROTOCOL_VERSION });
};
