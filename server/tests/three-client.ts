import { Client } from "@heroiclabs/nakama-js";
import WebSocket from "ws";

Object.assign(globalThis, { WebSocket });
const host = process.env.GAME_HOST || "127.0.0.1";
const port = process.env.GAME_PORT || "7350";
const serverKey = process.env.NAKAMA_SERVER_KEY || "deadworld-mvp-client-v1";
const ssl = process.env.GAME_SSL === "true";
const wait = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

async function waitFor(predicate: () => boolean, message: string, timeout = 10000) {
  const deadline = Date.now() + timeout;
  while (Date.now() < deadline) {
    if (predicate()) return;
    await wait(50);
  }
  throw new Error(message);
}

async function connect(index: number) {
  const client = new Client(serverKey, host, port, ssl, 10000);
  const session = await client.authenticateDevice(`deadworld-three-client-${Date.now()}-${index}`, true);
  const socket = client.createSocket(ssl, false);
  const snapshots: any[] = [];
  socket.onmatchdata = (data) => {
    if (data.op_code === 10) snapshots.push(JSON.parse(new TextDecoder().decode(data.data)));
  };
  await socket.connect(session, true);
  const rpc = await client.rpc(session, "find_world", {});
  const world = typeof rpc.payload === "string" ? JSON.parse(rpc.payload) : rpc.payload as any;
  let joined = false;
  for (let attempt = 0; attempt < 10 && !joined; attempt += 1) {
    try {
      await socket.joinMatch(world.match_id);
      joined = true;
    } catch (error) {
      if (attempt === 9) throw error;
      await wait(150);
    }
  }
  return { session, socket, matchId: world.match_id, snapshots };
}

async function main() {
  const clients = [];
  try {
    for (let index = 0; index < 3; index += 1) clients.push(await connect(index));
    const expectedPlayers = clients.map((client) => `player:${client.session.user_id}`).sort();
    await Promise.all(clients.map((client) => waitFor(
      () => expectedPlayers.every((id) => client.snapshots[client.snapshots.length - 1]?.players.some((player: any) => player.id === id)),
      "three-player snapshot timed out"
    )));
    if (new Set(clients.map((client) => client.session.user_id)).size !== 3) throw new Error("accounts are not unique");
    if (new Set(clients.map((client) => client.matchId)).size !== 1) throw new Error("clients joined different worlds");
    const sharedState = clients.map((client) => {
      const snapshot = client.snapshots[client.snapshots.length - 1];
      return JSON.stringify({ zombies: snapshot.zombies.map((entity: any) => entity.id).sort(), world_items: snapshot.world_items.map((item: any) => item.id).sort(), containers: snapshot.containers.map((container: any) => container.id).sort() });
    });
    if (new Set(sharedState).size !== 1) throw new Error("shared world state differs between clients");
    console.log(JSON.stringify({ concurrent_clients: 3, unique_accounts: true, same_world: true, shared_state: true }));
  } finally {
    for (const client of clients) client.socket.disconnect(false);
  }
}

main().catch((error) => { console.error(error); process.exit(1); });
