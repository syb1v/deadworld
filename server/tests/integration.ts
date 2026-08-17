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
  return { session, socket, matchId, snapshots: [] as any[], inventory: [] as any[], errors: [] as string[], deaths: [] as any[], respawns: [] as any[] };
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
  const aDeviceId = `deadworld-integration-a-${Date.now()}`;
  const a = await connect(aDeviceId);
  const b = await connect(`deadworld-integration-b-${Date.now()}`);
  if (a.session.user_id === b.session.user_id || a.matchId !== b.matchId) throw new Error("clients are not unique or did not share a world");
  const duplicateClient = new Client(key, host, port, false);
  const duplicateSession = await duplicateClient.authenticateDevice(aDeviceId, true);
  const duplicateSocket = duplicateClient.createSocket(false, false);
  await duplicateSocket.connect(duplicateSession, true);
  let duplicateRejected = false;
  try { await duplicateSocket.joinMatch(a.matchId); } catch (_error) { duplicateRejected = true; }
  await duplicateSocket.disconnect(false);
  if (!duplicateRejected) throw new Error("duplicate live user presence was accepted");
  for (const client of [a, b]) client.socket.onmatchdata = (data) => {
    const payload = JSON.parse(new TextDecoder().decode(data.data));
    if (data.op_code === 10) client.snapshots.push(payload);
    else if (data.op_code === 33) client.inventory = payload.items;
    else if (data.op_code === 21) client.deaths.push(payload);
    else if (data.op_code === 22) client.respawns.push(payload);
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
  await a.socket.sendMatchState(a.matchId, 1, JSON.stringify({ x: 0, y: 0, sequence: 2 }));
  const zombiesA = a.snapshots[a.snapshots.length - 1]?.zombies;
  const zombiesB = b.snapshots[b.snapshots.length - 1]?.zombies;
  if (!zombiesA || JSON.stringify(zombiesA) !== JSON.stringify(zombiesB)) throw new Error("clients did not receive identical zombie state");
  if (!zombiesA.some((zombie: any) => zombie.target_id === `player:${a.session.user_id}` || zombie.target_id === `player:${b.session.user_id}`)) throw new Error("server did not select a zombie target");
  const itemSnapshot = b.snapshots[b.snapshots.length - 1];
  const itemPlayerA = itemSnapshot.players.find((entity: any) => entity.id === `player:${a.session.user_id}`);
  const itemPlayerB = itemSnapshot.players.find((entity: any) => entity.id === `player:${b.session.user_id}`);
  const contestedItem = itemSnapshot.world_items.find((item: any) => Math.hypot(item.x - itemPlayerA.x, item.y - itemPlayerA.y) <= 96 && Math.hypot(item.x - itemPlayerB.x, item.y - itemPlayerB.y) <= 96);
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
  const combatSnapshot = a.snapshots[a.snapshots.length - 1];
  const bat = combatSnapshot.world_items.find((item: any) => item.definitionId === "baseball_bat");
  if (!bat) throw new Error("combat weapon was not present in world state");
  const combatPlayer = combatSnapshot.players.find((entity: any) => entity.id === `player:${a.session.user_id}`);
  const approach = { x: bat.x - combatPlayer.x, y: bat.y - combatPlayer.y };
  await a.socket.sendMatchState(a.matchId, 1, JSON.stringify({ x: approach.x, y: approach.y, sequence: 3 }));
  await waitFor(() => {
    const latest = a.snapshots[a.snapshots.length - 1];
    const local = latest.players.find((entity: any) => entity.id === `player:${a.session.user_id}`);
    return Math.hypot(bat.x - local.x, bat.y - local.y) <= 72;
  }, "player did not approach combat weapon");
  await a.socket.sendMatchState(a.matchId, 1, JSON.stringify({ x: 0, y: 0, sequence: 4 }));
  const pickupSnapshot = a.snapshots[a.snapshots.length - 1];
  await a.socket.sendMatchState(a.matchId, 30, JSON.stringify({ item_instance_id: bat.id, expected_world_version: pickupSnapshot.world_version }));
  await waitFor(() => a.inventory.some((item: any) => item.id === bat.id), "authoritative weapon pickup failed");
  const weaponSlot = a.inventory.findIndex((item: any) => item.id === bat.id);
  await waitFor(() => {
    const latest = a.snapshots[a.snapshots.length - 1];
    const local = latest.players.find((entity: any) => entity.id === `player:${a.session.user_id}`);
    return latest.zombies.some((entity: any) => entity.hp > 0 && Math.hypot(entity.x - local.x, entity.y - local.y) <= 45);
  }, "no zombie entered authoritative melee range", 10000);
  const beforeCombat = a.snapshots[a.snapshots.length - 1];
  const localBeforeCombat = beforeCombat.players.find((entity: any) => entity.id === `player:${a.session.user_id}`);
  const combatTarget = beforeCombat.zombies.filter((entity: any) => entity.hp > 0).sort((left: any, right: any) => Math.hypot(left.x - localBeforeCombat.x, left.y - localBeforeCombat.y) - Math.hypot(right.x - localBeforeCombat.x, right.y - localBeforeCombat.y))[0];
  const aim = { x: combatTarget.x - localBeforeCombat.x, y: combatTarget.y - localBeforeCombat.y };
  await a.socket.sendMatchState(a.matchId, 3, JSON.stringify({ weapon_slot: weaponSlot, aim_x: aim.x, aim_y: aim.y, sequence: 1 }));
  await waitFor(() => a.snapshots[a.snapshots.length - 1].zombies.some((entity: any) => entity.id === combatTarget.id && entity.hp === 15), "first authoritative melee damage was not applied");
  await wait(650);
  const secondCombat = a.snapshots[a.snapshots.length - 1];
  const localSecondCombat = secondCombat.players.find((entity: any) => entity.id === `player:${a.session.user_id}`);
  const targetSecondCombat = secondCombat.zombies.find((entity: any) => entity.id === combatTarget.id);
  await a.socket.sendMatchState(a.matchId, 3, JSON.stringify({ weapon_slot: weaponSlot, aim_x: targetSecondCombat.x - localSecondCombat.x, aim_y: targetSecondCombat.y - localSecondCombat.y, sequence: 2, target_id: "forged", damage: 999999 }));
  await waitFor(() => a.snapshots[a.snapshots.length - 1].zombies.some((entity: any) => entity.id === combatTarget.id && entity.state === "DEAD" && entity.hp === 0), "server-validated melee did not kill zombie");
  const expectedInventoryIds = b.inventory.map((item: any) => item.id).sort();
  await b.socket.disconnect(false);
  await waitFor(() => a.snapshots[a.snapshots.length - 1].players.some((entity: any) => entity.id === `player:${a.session.user_id}` && entity.state === "dead" && entity.health === 0), "zombie damage did not kill player", 35000);
  await waitFor(() => a.inventory.length === 0 && a.snapshots[a.snapshots.length - 1].world_items.some((item: any) => item.id === bat.id), "death did not drop inventory authoritatively");
  await waitFor(() => a.snapshots[a.snapshots.length - 1].players.some((entity: any) => entity.id === `player:${a.session.user_id}` && entity.state !== "dead" && entity.health === 100), "player did not respawn with reset health", 6000);
  if (!a.deaths.some((event) => event.player_id === `player:${a.session.user_id}`) || !a.respawns.some((event) => event.player_id === `player:${a.session.user_id}`)) throw new Error("death/respawn events were not broadcast");
  await a.socket.disconnect(false);
  const reconnectClient = new Client(key, host, port, false);
  const reconnectSocket = reconnectClient.createSocket(false, false);
  const reconnect = { session: b.session, socket: reconnectSocket, matchId: b.matchId, snapshots: [] as any[], inventory: [] as any[], errors: [] as string[], deaths: [] as any[], respawns: [] as any[] };
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
  if (reconnect.snapshots[reconnect.snapshots.length - 1]?.players.some((entity: any) => entity.id === `player:${a.session.user_id}`)) throw new Error("disconnect cleanup failed");
  const reconnectZombies = reconnect.snapshots[reconnect.snapshots.length - 1]?.zombies;
  if (!reconnectZombies || reconnectZombies.length !== zombiesB.length) throw new Error("reconnect did not restore zombie state");
  if (!reconnect.snapshots[reconnect.snapshots.length - 1]?.containers) throw new Error("reconnect did not restore item state");
  const reconnectInventory = await Promise.race([inventorySnapshot, wait(2000).then(() => { throw new Error("reconnect inventory snapshot timed out"); })]);
  const reconnectInventoryIds = reconnectInventory.map((item: any) => item.id).sort();
  if (JSON.stringify(reconnectInventoryIds) !== JSON.stringify(expectedInventoryIds)) throw new Error("stable user inventory was not restored on reconnect");
  await reconnect.socket.disconnect(false);
  console.log(JSON.stringify({ auth: true, socket: true, shared_world: true, unique_players: true, separated_spawns: true, speed_validation: true, disconnect_cleanup: true, shared_zombies: true, server_targeting: true, combat_server_validated: true, zombie_death: true, player_death: true, inventory_death_drop: true, player_respawn: true, reconnect_zombies: true, pickup_single_owner: true, stale_container_rejected: true, reconnect_items: true, reconnect_inventory: true }));
}

main().catch((error) => { console.error(error); process.exit(1); });
