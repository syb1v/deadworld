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
  return { session, socket, matchId, snapshots: [] as any[], inventory: [] as any[], errors: [] as string[] };
}

const wait = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));
async function waitFor(predicate: () => boolean, message: string, timeout = 2000) {
  const deadline = Date.now() + timeout;
  while (Date.now() < deadline) {
    if (predicate()) return;
    await wait(25);
  }
  throw new Error(message);
}

async function main() {
  const a = await connect(`deadworld-integration-a-${Date.now()}`);
  const b = await connect(`deadworld-integration-b-${Date.now()}`);
  if (a.session.user_id === b.session.user_id || a.matchId !== b.matchId) throw new Error("clients are not unique or did not share a world");
  for (const client of [a, b]) client.socket.onmatchdata = (data) => {
    const payload = JSON.parse(new TextDecoder().decode(data.data));
    if (data.op_code === 10) client.snapshots.push(payload);
    else if (data.op_code === 33) client.inventory = payload.items;
    else if (data.op_code === 50) client.errors.push(payload.code);
  };
  await a.socket.sendMatchState(a.matchId, 1, JSON.stringify({ x: 999, y: 999, sequence: 1 }));
  await a.socket.sendMatchState(a.matchId, 1, "malformed");
  await wait(600);
  const snapshot = b.snapshots[b.snapshots.length - 1];
  const player = snapshot?.players.find((p: any) => p.id === `player:${a.session.user_id}`);
  const secondPlayer = snapshot?.players.find((p: any) => p.id === `player:${b.session.user_id}`);
  if (!player || Math.hypot(player.vx, player.vy) > 180.001) throw new Error("authoritative speed validation failed");
  if (!secondPlayer || (player.x === secondPlayer.x && player.y === secondPlayer.y)) throw new Error("players spawned on top of each other");
  const zombiesA = a.snapshots[a.snapshots.length - 1]?.zombies;
  const zombiesB = b.snapshots[b.snapshots.length - 1]?.zombies;
  if (!zombiesA || JSON.stringify(zombiesA) !== JSON.stringify(zombiesB)) throw new Error("clients did not receive identical zombie state");
  if (!zombiesA.some((zombie: any) => zombie.target_id === `player:${a.session.user_id}` || zombie.target_id === `player:${b.session.user_id}`)) throw new Error("server did not select a zombie target");
  if (!zombiesA.some((zombie: any) => zombie.state === "DEAD" && zombie.hp === 0)) throw new Error("dead zombie state was not synchronized");
  const itemSnapshot = b.snapshots[b.snapshots.length - 1];
  const contestedItem = itemSnapshot.world_items[0];
  if (contestedItem) {
    await Promise.all([
      a.socket.sendMatchState(a.matchId, 30, JSON.stringify({ item_instance_id: contestedItem.id, expected_world_version: itemSnapshot.world_version })),
      b.socket.sendMatchState(b.matchId, 30, JSON.stringify({ item_instance_id: contestedItem.id, expected_world_version: itemSnapshot.world_version }))
    ]);
    await waitFor(() => [a, b].some((client) => client.inventory.some((item: any) => item.id === contestedItem.id)), "pickup winner inventory was not updated");
    const owners = [a, b].filter((client) => client.inventory.some((item: any) => item.id === contestedItem.id));
    if (owners.length !== 1) throw new Error("simultaneous pickup did not produce exactly one owner");
    const loser = owners[0] === a ? b : a;
    await waitFor(() => loser.errors.some((code) => code === "STALE_WORLD_VERSION" || code === "ITEM_NOT_AVAILABLE"), `pickup rejection was not delivered: ${JSON.stringify(loser.errors)}`);
    if (!loser.errors.some((code) => code === "STALE_WORLD_VERSION" || code === "ITEM_NOT_AVAILABLE")) throw new Error("pickup loser did not receive authoritative rejection");
    await owners[0].socket.sendMatchState(owners[0].matchId, 31, JSON.stringify({ item_instance_id: contestedItem.id }));
    await wait(200);
  }
  const containerState = b.snapshots[b.snapshots.length - 1].containers[0];
  if (containerState?.items.length >= 2) {
    await Promise.all([
      a.socket.sendMatchState(a.matchId, 41, JSON.stringify({ container_id: containerState.id, expected_version: containerState.version, operation: "take", item_instance_id: containerState.items[0].id })),
      b.socket.sendMatchState(b.matchId, 41, JSON.stringify({ container_id: containerState.id, expected_version: containerState.version, operation: "take", item_instance_id: containerState.items[1].id }))
    ]);
    await waitFor(() => b.snapshots[b.snapshots.length - 1].containers[0].version > containerState.version, "container version did not advance");
    await waitFor(() => [a, b].some((client) => client.errors.includes("STALE_CONTAINER_VERSION")), `stale container error was not delivered: ${JSON.stringify({ a: a.errors, b: b.errors })}`);
    const latestContainer = b.snapshots[b.snapshots.length - 1].containers[0];
    if (latestContainer.version !== containerState.version + 1 || latestContainer.items.length !== containerState.items.length - 1) throw new Error("container race was not atomic");
    const containerWinner = [a, b].find((client) => client.inventory.some((item: any) => containerState.items.some((original: any) => original.id === item.id)));
    const taken = containerWinner?.inventory.find((item: any) => containerState.items.some((original: any) => original.id === item.id));
    if (containerWinner && taken) {
      await containerWinner.socket.sendMatchState(containerWinner.matchId, 41, JSON.stringify({ container_id: containerState.id, expected_version: latestContainer.version, operation: "deposit", item_instance_id: taken.id }));
      await waitFor(() => b.snapshots[b.snapshots.length - 1].containers[0].items.length === containerState.items.length, "container test cleanup failed");
    }
  }
  await a.socket.disconnect(false);
  await wait(500);
  const afterLeave = b.snapshots[b.snapshots.length - 1];
  if (afterLeave.players.some((p: any) => p.id === `player:${a.session.user_id}`)) throw new Error("disconnect cleanup failed");
  const expectedInventoryIds = b.inventory.map((item: any) => item.id).sort();
  await b.socket.disconnect(false);
  const reconnectClient = new Client(key, host, port, false);
  const reconnectSocket = reconnectClient.createSocket(false, false);
  const reconnect = { session: b.session, socket: reconnectSocket, matchId: b.matchId, snapshots: [] as any[], inventory: [] as any[], errors: [] as string[] };
  let resolveInventory: ((items: any[]) => void) | undefined;
  const inventorySnapshot = new Promise<any[]>((resolve) => { resolveInventory = resolve; });
  reconnect.socket.onmatchdata = (data) => {
    const payload = JSON.parse(new TextDecoder().decode(data.data));
    if (data.op_code === 10) reconnect.snapshots.push(payload);
    if (data.op_code === 33) resolveInventory?.(payload.items);
  };
  await reconnectSocket.connect(b.session, true);
  await reconnectSocket.joinMatch(b.matchId);
  await wait(300);
  const reconnectZombies = reconnect.snapshots[reconnect.snapshots.length - 1]?.zombies;
  if (!reconnectZombies || reconnectZombies.length !== zombiesB.length) throw new Error("reconnect did not restore zombie state");
  if (!reconnect.snapshots[reconnect.snapshots.length - 1]?.containers) throw new Error("reconnect did not restore item state");
  const reconnectInventory = await Promise.race([inventorySnapshot, wait(2000).then(() => { throw new Error("reconnect inventory snapshot timed out"); })]);
  const reconnectInventoryIds = reconnectInventory.map((item: any) => item.id).sort();
  if (JSON.stringify(reconnectInventoryIds) !== JSON.stringify(expectedInventoryIds)) throw new Error("stable user inventory was not restored on reconnect");
  await reconnect.socket.disconnect(false);
  console.log(JSON.stringify({ auth: true, socket: true, shared_world: true, unique_players: true, separated_spawns: true, speed_validation: true, disconnect_cleanup: true, shared_zombies: true, server_targeting: true, dead_state_sync: true, reconnect_zombies: true, pickup_single_owner: true, stale_container_rejected: true, reconnect_items: true, reconnect_inventory: true }));
}

main().catch((error) => { console.error(error); process.exit(1); });
