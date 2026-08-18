import { Client } from "@heroiclabs/nakama-js";
import { readFileSync, writeFileSync } from "node:fs";
import WebSocket from "ws";

Object.assign(globalThis, { WebSocket });
const host = process.env.GAME_HOST || "127.0.0.1";
const port = process.env.GAME_PORT || "7350";
const serverKey = process.env.NAKAMA_SERVER_KEY || "deadworld-local-key";
const httpKey = process.env.NAKAMA_HTTP_KEY || "deadworld-local-http-key";
const expectedPath = "/tmp/opencode/deadworld-restart-expected.json";

type Harness = Awaited<ReturnType<typeof connect>>;
const wait = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));
async function waitFor(predicate: () => boolean, message: string, timeout = 5000) {
  const deadline = Date.now() + timeout;
  while (Date.now() < deadline) { if (predicate()) return; await wait(50); }
  throw new Error(message);
}

async function createWorld(client: Client, resume: boolean) {
  const rpc = await client.rpcHttpKey(httpKey, resume ? "resume_restart_test_world" : "create_restart_test_world");
  const payload = typeof rpc.payload === "string" ? JSON.parse(rpc.payload) : rpc.payload;
  return payload as { match_id: string; token: string };
}

async function connect(matchId: string, deviceId: string) {
  const client = new Client(serverKey, host, port, false, 10000);
  const session = await client.authenticateDevice(deviceId, true);
  const socket = client.createSocket(false, false);
  const state = { client, session, socket, matchId, snapshots: [] as any[], inventory: [] as any[], inventoryReceived: false, errors: [] as string[] };
  socket.onmatchdata = (data) => {
    const payload = JSON.parse(new TextDecoder().decode(data.data));
    if (data.op_code === 10) state.snapshots.push(payload);
    else if (data.op_code === 33) { state.inventory = payload.items; state.inventoryReceived = true; }
    else if (data.op_code === 50) state.errors.push(payload.code);
  };
  await socket.connect(session, true);
  let joined = false;
  for (let attempt = 0; attempt < 10 && !joined; attempt += 1) {
    try { await socket.joinMatch(matchId); joined = true; } catch (error) { if (attempt === 9) throw error; await wait(150); }
  }
  await waitFor(() => state.snapshots.length > 0 && state.inventoryReceived, "initial persistent snapshots timed out");
  return state;
}

function latest(harness: Harness) { return harness.snapshots[harness.snapshots.length - 1]; }
function localPlayer(harness: Harness) { return latest(harness).players.find((player: any) => player.id === `player:${harness.session.user_id}`); }
function ownership(harness: Harness) {
  const result: Record<string, unknown> = {};
  const add = (item: any, location: string) => {
    if (result[item.id]) throw new Error(`duplicate item before comparison: ${item.id}`);
    result[item.id] = { location, definitionId: item.definitionId, quantity: item.quantity ?? null, magazineAmmo: item.magazineAmmo ?? null };
  };
  for (const item of latest(harness).world_items) add(item, "world");
  for (const container of latest(harness).containers) for (const item of container.items) add(item, container.id);
  for (const item of harness.inventory) add(item, `inventory:${harness.session.user_id}`);
  return Object.fromEntries(Object.entries(result).sort(([a], [b]) => a.localeCompare(b)));
}

async function moveNear(harness: Harness, x: number, y: number, sequenceStart: number) {
  let sequence = sequenceStart;
  for (let attempt = 0; attempt < 40; attempt += 1) {
    const player = localPlayer(harness);
    if (Math.hypot(x - player.x, y - player.y) <= 60) {
      await harness.socket.sendMatchState(harness.matchId, 1, JSON.stringify({ x: 0, y: 0, sequence }));
      return sequence + 1;
    }
    await harness.socket.sendMatchState(harness.matchId, 1, JSON.stringify({ x: x - player.x, y: y - player.y, sequence: sequence++ }));
    await wait(150);
  }
  throw new Error(`could not move near ${x},${y}`);
}

async function pickupDefinition(harness: Harness, definitionId: string) {
  const snapshot = latest(harness);
  const item = snapshot.world_items.find((candidate: any) => candidate.definitionId === definitionId);
  if (!item) throw new Error(`${definitionId} missing from persistent fixture`);
  await harness.socket.sendMatchState(harness.matchId, 30, JSON.stringify({ item_instance_id: item.id, expected_world_version: snapshot.world_version }));
  await waitFor(() => harness.inventory.some((candidate: any) => candidate.definitionId === definitionId), `${definitionId} pickup did not persist in inventory`);
  return item.id;
}

async function prepare() {
  console.log("prepare: create persistent test world");
  const admin = new Client(serverKey, host, port, false, 10000);
  const fixture = await createWorld(admin, false);
  const token = fixture.token;
  const deviceId = `deadworld-restart-${token}`;
  const matchId = fixture.match_id;
  console.log("prepare: authenticate and join");
  const harness = await connect(matchId, deviceId);
  console.log("prepare: pickup and reload");
  const bandageId = await pickupDefinition(harness, "bandage");
  const pistolId = await pickupDefinition(harness, "pistol");
  const ammoId = await pickupDefinition(harness, "pistol_ammo");
  const pistolSlot = () => harness.inventory.findIndex((item: any) => item.id === pistolId);
  await harness.socket.sendMatchState(matchId, 5, JSON.stringify({ weapon_slot: pistolSlot(), sequence: 1 }));
  await waitFor(() => harness.inventory.find((item: any) => item.id === pistolId)?.magazineAmmo === 6, "pistol magazine was not persisted after reload");

  console.log("prepare: kill zombie");
  await waitFor(() => latest(harness).zombies.some((zombie: any) => zombie.hp > 0 && Math.hypot(zombie.x - localPlayer(harness).x, zombie.y - localPlayer(harness).y) <= 260), "no zombie entered pistol range", 10000);
  let target = latest(harness).zombies.filter((zombie: any) => zombie.hp > 0).sort((a: any, b: any) => Math.hypot(a.x - localPlayer(harness).x, a.y - localPlayer(harness).y) - Math.hypot(b.x - localPlayer(harness).x, b.y - localPlayer(harness).y))[0];
  for (let sequence = 1; sequence <= 2; sequence += 1) {
    const player = localPlayer(harness);
    target = latest(harness).zombies.find((zombie: any) => zombie.id === target.id);
    await harness.socket.sendMatchState(matchId, 3, JSON.stringify({ weapon_slot: pistolSlot(), aim_x: target.x - player.x, aim_y: target.y - player.y, sequence }));
    await wait(450);
  }
  await waitFor(() => latest(harness).zombies.some((zombie: any) => zombie.id === target.id && zombie.state === "DEAD"), "zombie death was not persisted");

  console.log("prepare: mutate container");
  let moveSequence = await moveNear(harness, 640, 400, 100);
  const containerBefore = latest(harness).containers[0];
  const beans = containerBefore.items.find((item: any) => item.definitionId === "canned_beans");
  await harness.socket.sendMatchState(matchId, 41, JSON.stringify({ container_id: containerBefore.id, expected_version: containerBefore.version, operation: "take", item_instance_id: beans.id }));
  await waitFor(() => harness.inventory.some((item: any) => item.id === beans.id), "container take was not persisted");
  const containerAfterTake = latest(harness).containers[0];
  await harness.socket.sendMatchState(matchId, 41, JSON.stringify({ container_id: containerAfterTake.id, expected_version: containerAfterTake.version, operation: "deposit", item_instance_id: bandageId }));
  await waitFor(() => latest(harness).containers[0].items.some((item: any) => item.id === bandageId), "container deposit was not persisted");

  console.log("prepare: persist player position and HP");
  moveSequence = await moveNear(harness, 700, 430, moveSequence);
  await waitFor(() => localPlayer(harness).health < 100, "player HP did not change before restart", 15000);
  moveSequence = await moveNear(harness, 640, 40, moveSequence);
  await harness.socket.sendMatchState(matchId, 1, JSON.stringify({ x: 0, y: 0, sequence: moveSequence }));
  await wait(1200);
  if (harness.errors.length > 0) throw new Error(`prepare received server errors: ${harness.errors.join(",")}`);
  const expected = {
    token,
    deviceId,
    userId: harness.session.user_id,
    pistolId,
    ammoId,
    beansId: beans.id,
    bandageId,
    zombieId: target.id,
    player: { x: localPlayer(harness).x, y: localPlayer(harness).y, health: localPlayer(harness).health },
    ownership: ownership(harness),
    containers: Object.fromEntries(latest(harness).containers.map((container: any) => [container.id, container.version])),
    zombies: Object.fromEntries(latest(harness).zombies.map((zombie: any) => [zombie.id, { hp: zombie.hp, dead: zombie.state === "DEAD" }]))
  };
  writeFileSync(expectedPath, JSON.stringify(expected), "utf8");
  await harness.socket.disconnect(false);
  console.log(JSON.stringify(expected));
}

async function verify() {
  const admin = new Client(serverKey, host, port, false, 10000);
  const expected = JSON.parse(readFileSync(expectedPath, "utf8"));
  const fixture = await createWorld(admin, true);
  if (fixture.token !== expected.token) throw new Error("restart fixture pointer changed between phases");
  const harness = await connect(fixture.match_id, expected.deviceId);
  if (harness.session.user_id !== expected.userId) throw new Error("restart test did not use the same account");
  await waitFor(() => harness.inventory.some((item: any) => item.id === expected.pistolId), "inventory did not restore after full restart");
  if (harness.errors.length > 0) throw new Error(`verify received server errors: ${harness.errors.join(",")}`);
  const pistol = harness.inventory.find((item: any) => item.id === expected.pistolId);
  const ammo = harness.inventory.find((item: any) => item.id === expected.ammoId);
  if (pistol.magazineAmmo !== 4 || ammo.quantity !== 18) throw new Error(`magazine/ammo mismatch after restart: ${JSON.stringify({ pistol, ammo })}`);
  if (!harness.inventory.some((item: any) => item.id === expected.beansId)) throw new Error("container-taken item did not remain in inventory");
  const container = latest(harness).containers[0];
  if (!container.items.some((item: any) => item.id === expected.bandageId) || container.items.some((item: any) => item.id === expected.beansId)) throw new Error("container contents did not restore");
  const containerVersions = Object.fromEntries(latest(harness).containers.map((candidate: any) => [candidate.id, candidate.version]));
  if (JSON.stringify(containerVersions) !== JSON.stringify(expected.containers)) throw new Error(`container versions did not restore: ${JSON.stringify(containerVersions)}`);
  if (!latest(harness).zombies.some((zombie: any) => zombie.id === expected.zombieId && zombie.state === "DEAD" && zombie.hp === 0)) throw new Error("dead zombie respawned after restart");
  const player = localPlayer(harness);
  const firstRestoredPlayer = harness.snapshots.map((snapshot) => snapshot.players.find((candidate: any) => candidate.id === `player:${harness.session.user_id}`)).find(Boolean);
  if (!firstRestoredPlayer || Math.hypot(firstRestoredPlayer.x - expected.player.x, firstRestoredPlayer.y - expected.player.y) > 15 || firstRestoredPlayer.health !== expected.player.health) throw new Error(`initial player snapshot did not restore: ${JSON.stringify({ player: firstRestoredPlayer, expected: expected.player })}`);
  if (player.health > expected.player.health) throw new Error(`player was healed/reset after restart: ${JSON.stringify({ player, expected: expected.player })}`);
  const restoredOwnership = ownership(harness);
  if (JSON.stringify(restoredOwnership) !== JSON.stringify(expected.ownership)) throw new Error(`complete ownership map changed after restart: ${JSON.stringify(restoredOwnership)}`);
  const zombieStates = Object.fromEntries(latest(harness).zombies.map((zombie: any) => [zombie.id, { hp: zombie.hp, dead: zombie.state === "DEAD" }]));
  if (JSON.stringify(zombieStates) !== JSON.stringify(expected.zombies)) throw new Error(`zombie terminal states changed after restart: ${JSON.stringify(zombieStates)}`);
  await harness.socket.disconnect(false);
  console.log(JSON.stringify({ full_server_restart: true, same_account: true, player_state: true, inventory: true, magazine_ammo: true, world_items: true, container_version: true, dead_world_state: true, no_duplication: true }));
}

const phase = process.argv[2];
(phase === "prepare" ? prepare() : phase === "verify" ? verify() : Promise.reject(new Error("Expected prepare or verify"))).catch((error) => { console.error(error); process.exit(1); });
