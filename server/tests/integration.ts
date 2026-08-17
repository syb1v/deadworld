import { Client } from "@heroiclabs/nakama-js";
import WebSocket from "ws";

Object.assign(globalThis, { WebSocket });
const host = process.env.GAME_HOST || "127.0.0.1";
const port = process.env.GAME_PORT || "7350";
const key = process.env.NAKAMA_SERVER_KEY || "deadworld-local-key";

async function connect(id: string) {
  const client = new Client(key, host, port, false);
  const session = await client.authenticateDevice(id, true);
  const socket = client.createSocket(false, false);
  await socket.connect(session, true);
  const rpc = await client.rpc(session, "find_world", {});
  const payload = typeof rpc.payload === "string" ? JSON.parse(rpc.payload) : rpc.payload;
  const matchId = (payload as { match_id: string }).match_id;
  await socket.joinMatch(matchId);
  return { session, socket, matchId, snapshots: [] as any[] };
}

const wait = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

async function main() {
  const a = await connect(`deadworld-integration-a-${Date.now()}`);
  const b = await connect(`deadworld-integration-b-${Date.now()}`);
  if (a.session.user_id === b.session.user_id || a.matchId !== b.matchId) throw new Error("clients are not unique or did not share a world");
  for (const client of [a, b]) client.socket.onmatchdata = (data) => { if (data.op_code === 10) client.snapshots.push(JSON.parse(new TextDecoder().decode(data.data))); };
  await a.socket.sendMatchState(a.matchId, 1, JSON.stringify({ x: 999, y: 999, sequence: 1 }));
  await a.socket.sendMatchState(a.matchId, 1, "malformed");
  await wait(600);
  const snapshot = b.snapshots[b.snapshots.length - 1];
  const player = snapshot?.players.find((p: any) => p.id === `player:${a.session.user_id}`);
  if (!player || Math.hypot(player.vx, player.vy) > 180.001) throw new Error("authoritative speed validation failed");
  const zombiesA = a.snapshots[a.snapshots.length - 1]?.zombies;
  const zombiesB = b.snapshots[b.snapshots.length - 1]?.zombies;
  if (!zombiesA || JSON.stringify(zombiesA) !== JSON.stringify(zombiesB)) throw new Error("clients did not receive identical zombie state");
  if (!zombiesA.some((zombie: any) => zombie.target_id === `player:${a.session.user_id}` || zombie.target_id === `player:${b.session.user_id}`)) throw new Error("server did not select a zombie target");
  if (!zombiesA.some((zombie: any) => zombie.state === "DEAD" && zombie.hp === 0)) throw new Error("dead zombie state was not synchronized");
  await a.socket.disconnect(false);
  await wait(500);
  const afterLeave = b.snapshots[b.snapshots.length - 1];
  if (afterLeave.players.some((p: any) => p.id === `player:${a.session.user_id}`)) throw new Error("disconnect cleanup failed");
  const reconnect = await connect(`deadworld-integration-reconnect-${Date.now()}`);
  reconnect.socket.onmatchdata = (data) => { if (data.op_code === 10) reconnect.snapshots.push(JSON.parse(new TextDecoder().decode(data.data))); };
  await wait(300);
  const reconnectZombies = reconnect.snapshots[reconnect.snapshots.length - 1]?.zombies;
  if (!reconnectZombies || reconnectZombies.length !== zombiesB.length) throw new Error("reconnect did not restore zombie state");
  await reconnect.socket.disconnect(false);
  await b.socket.disconnect(false);
  console.log(JSON.stringify({ auth: true, socket: true, shared_world: true, unique_players: true, speed_validation: true, disconnect_cleanup: true, shared_zombies: true, server_targeting: true, dead_state_sync: true, reconnect_zombies: true }));
}

main().catch((error) => { console.error(error); process.exit(1); });
