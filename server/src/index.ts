import { CONTAINER_MUTATE, ERROR_EVENT, INPUT_MOVE, INVENTORY_SNAPSHOT, ITEM_DROP, ITEM_PICKUP, MAX_INPUTS_PER_SECOND, MAX_INTERACTIONS_PER_SECOND, PLAYER_SNAPSHOT, PLAYER_SPEED, PROTOCOL_VERSION, TICK_RATE } from "./protocol";
import { parseMoveInput } from "./movement";
import { createZombies, simulateZombie, Zombie } from "./zombies";
import { createItemState, dropItem, ItemInstance, ItemState, mutateContainer, parseInteraction, pickupItem } from "./items";

interface Player {
  id: string; presence: nkruntime.Presence; x: number; y: number; vx: number; vy: number;
  inputX: number; inputY: number; lastSequence: number; rateWindow: number; rateCount: number;
  health: number;
  inventory: ItemInstance[]; interactionWindow: number; interactionCount: number; inventoryDirty: boolean;
}
interface WorldState extends nkruntime.MatchState { players: Record<string, Player>; inventories: Record<string, ItemInstance[]>; zombies: Record<string, Zombie>; items: ItemState; }

const PLAYER_SPAWNS = [[560, 360], [720, 360], [640, 280], [640, 440]];

export const worldMatch: nkruntime.MatchHandler = {
  matchInit(_ctx, logger, _nk, _params) {
    logger.info(JSON.stringify({ event: "world_created", protocol: PROTOCOL_VERSION }));
    return { state: { players: {}, inventories: {}, zombies: createZombies(), items: createItemState() } as WorldState, tickRate: TICK_RATE, label: JSON.stringify({ world: "main", protocol: PROTOCOL_VERSION }) };
  },
  matchJoinAttempt(_ctx, _logger, _nk, _dispatcher, _tick, state) { return { state, accept: true }; },
  matchJoin(_ctx, logger, _nk, dispatcher, _tick, rawState, presences) {
    const state = rawState as WorldState;
    for (const presence of presences) {
      const spawn = PLAYER_SPAWNS[Object.keys(state.players).length % PLAYER_SPAWNS.length];
      const inventory = state.inventories[presence.userId] || [];
      state.inventories[presence.userId] = inventory;
      state.players[presence.sessionId] = { id: `player:${presence.userId}`, presence, x: spawn[0], y: spawn[1], vx: 0, vy: 0, inputX: 0, inputY: 0, lastSequence: -1, rateWindow: 0, rateCount: 0, health: 100, inventory, interactionWindow: 0, interactionCount: 0, inventoryDirty: true };
      logger.info(JSON.stringify({ event: "player_join", player_id: `player:${presence.userId}` }));
    }
    dispatcher.matchLabelUpdate(JSON.stringify({ world: "main", protocol: PROTOCOL_VERSION, players: Object.keys(state.players).length }));
    return { state };
  },
  matchLeave(_ctx, logger, _nk, dispatcher, _tick, rawState, presences) {
    const state = rawState as WorldState;
    for (const presence of presences) {
      delete state.players[presence.sessionId];
      logger.info(JSON.stringify({ event: "player_leave", player_id: `player:${presence.userId}` }));
    }
    dispatcher.matchLabelUpdate(JSON.stringify({ world: "main", protocol: PROTOCOL_VERSION, players: Object.keys(state.players).length }));
    return { state };
  },
  matchLoop(_ctx, logger, _nk, dispatcher, tick, rawState, messages) {
    const state = rawState as WorldState;
    for (const message of messages) {
      const player = state.players[message.sender.sessionId];
      if (!player) continue;
      if (message.opCode !== INPUT_MOVE) {
        const second = Math.floor(tick / TICK_RATE);
        if (player.interactionWindow !== second) { player.interactionWindow = second; player.interactionCount = 0; }
        player.interactionCount += 1;
        if (player.interactionCount > MAX_INTERACTIONS_PER_SECOND) continue;
        const payload = parseInteraction(message.data);
        if (!payload) { sendError(dispatcher, player, "BAD_PAYLOAD"); continue; }
        let result;
        if (message.opCode === ITEM_PICKUP) result = pickupItem(state.items, player, payload.item_instance_id, payload.expected_world_version);
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
    const players = Object.keys(state.players).map((sessionId) => {
      const player = state.players[sessionId];
      player.vx = player.inputX * PLAYER_SPEED; player.vy = player.inputY * PLAYER_SPEED;
      player.x += player.vx * dt; player.y += player.vy * dt;
      return { id: player.id, x: player.x, y: player.y, vx: player.vx, vy: player.vy, health: player.health, state: player.vx || player.vy ? "move" : "idle" };
    });
    const targets = Object.keys(state.players).map((sessionId) => state.players[sessionId]);
    for (const id of Object.keys(state.zombies)) simulateZombie(state.zombies[id], targets, tick, dt);
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
