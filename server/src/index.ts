import { INPUT_MOVE, MAX_INPUTS_PER_SECOND, PLAYER_SNAPSHOT, PLAYER_SPEED, PROTOCOL_VERSION, TICK_RATE } from "./protocol";
import { parseMoveInput } from "./movement";
import { createZombies, simulateZombie, Zombie } from "./zombies";

interface Player {
  id: string; presence: nkruntime.Presence; x: number; y: number; vx: number; vy: number;
  inputX: number; inputY: number; lastSequence: number; rateWindow: number; rateCount: number;
  health: number;
}
interface WorldState extends nkruntime.MatchState { players: Record<string, Player>; zombies: Record<string, Zombie>; }

export const worldMatch: nkruntime.MatchHandler = {
  matchInit(_ctx, logger, _nk, _params) {
    logger.info(JSON.stringify({ event: "world_created", protocol: PROTOCOL_VERSION }));
    return { state: { players: {}, zombies: createZombies() } as WorldState, tickRate: TICK_RATE, label: JSON.stringify({ world: "main", protocol: PROTOCOL_VERSION }) };
  },
  matchJoinAttempt(_ctx, _logger, _nk, _dispatcher, _tick, state) { return { state, accept: true }; },
  matchJoin(_ctx, logger, _nk, dispatcher, _tick, rawState, presences) {
    const state = rawState as WorldState;
    for (const presence of presences) {
      state.players[presence.sessionId] = { id: `player:${presence.userId}`, presence, x: 640, y: 360, vx: 0, vy: 0, inputX: 0, inputY: 0, lastSequence: -1, rateWindow: 0, rateCount: 0, health: 100 };
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
      if (message.opCode !== INPUT_MOVE) continue;
      const player = state.players[message.sender.sessionId];
      if (!player) continue;
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
    dispatcher.broadcastMessage(PLAYER_SNAPSHOT, JSON.stringify({ protocol: PROTOCOL_VERSION, tick, players, zombies }), null, null, false);
    return { state };
  },
  matchTerminate(_ctx, _logger, _nk, _dispatcher, _tick, state, _grace) { return { state }; },
  matchSignal(_ctx, _logger, _nk, _dispatcher, _tick, state, data) { return { state, data }; }
};

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
