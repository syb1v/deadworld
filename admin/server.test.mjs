import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { createServer } from "node:http";
import test from "node:test";

test("admin login, status and CSRF-protected respawn", async (context) => {
  const calls = [];
  const mock = createServer((request, response) => {
    const url = new URL(request.url, "http://mock");
    calls.push(url.pathname);
    const result = url.pathname.endsWith("admin_respawn_zombies") ? { ok: true, respawned: 2 } : { ok: true, players_online: 1, zombies_alive: 1, zombies_total: 3, events: [] };
    response.setHeader("Content-Type", "application/json");
    response.end(JSON.stringify({ payload: JSON.stringify(result) }));
  });
  await new Promise((resolve) => mock.listen(18181, "127.0.0.1", resolve));
  const child = spawn(process.execPath, ["admin/server.mjs"], { cwd: new URL("..", import.meta.url), env: { ...process.env, ADMIN_PORT: "18182", ADMIN_USERNAME: "operator", ADMIN_PASSWORD: "test-password", ADMIN_SESSION_KEY: "test-session-key", NAKAMA_HTTP_KEY: "private-http-key", NAKAMA_INTERNAL_URL: "http://127.0.0.1:18181" }, stdio: "ignore" });
  context.after(() => { child.kill(); mock.close(); });
  await waitForServer("http://127.0.0.1:18182/health");

  const landing = await (await fetch("http://127.0.0.1:18182/landing")).text();
  assert.match(landing, /МЁРТВЫЙ/);
  assert.match(landing, /deadworld-linux-x86_64\.zip/);
  const status = await (await fetch("http://127.0.0.1:18182/status")).json();
  assert.deepEqual(status, { online: true, players: 1, zombies_alive: 1, zombies_total: 3 });

  const anonymous = await fetch("http://127.0.0.1:18182/", { redirect: "manual" });
  assert.equal(anonymous.status, 303);
  assert.equal(anonymous.headers.get("location"), "/admin/login");

  const rejected = await fetch("http://127.0.0.1:18182/login", { method: "POST", body: new URLSearchParams({ username: "operator", password: "wrong" }), redirect: "manual" });
  assert.equal(rejected.status, 401);

  const accepted = await fetch("http://127.0.0.1:18182/login", { method: "POST", body: new URLSearchParams({ username: "operator", password: "test-password" }), redirect: "manual" });
  assert.equal(accepted.status, 303);
  const setCookie = accepted.headers.get("set-cookie");
  assert.match(setCookie, /HttpOnly; Secure; SameSite=Strict/);
  const cookie = setCookie.split(";", 1)[0];

  const dashboard = await fetch("http://127.0.0.1:18182/", { headers: { Cookie: cookie } });
  const html = await dashboard.text();
  assert.equal(dashboard.status, 200);
  assert.match(html, /игроков онлайн/);
  const csrf = html.match(/name="csrf" value="([a-f0-9]+)"/)?.[1];
  assert.ok(csrf);

  const logoutForbidden = await fetch("http://127.0.0.1:18182/logout", { method: "POST", headers: { Cookie: cookie }, body: new URLSearchParams({ csrf: "wrong" }), redirect: "manual" });
  assert.equal(logoutForbidden.status, 403);

  const forbidden = await fetch("http://127.0.0.1:18182/respawn-zombies", { method: "POST", headers: { Cookie: cookie }, body: new URLSearchParams({ csrf: "wrong" }), redirect: "manual" });
  assert.equal(forbidden.status, 403);
  assert.equal(calls.filter((path) => path.endsWith("admin_respawn_zombies")).length, 0);

  const respawn = await fetch("http://127.0.0.1:18182/respawn-zombies", { method: "POST", headers: { Cookie: cookie }, body: new URLSearchParams({ csrf }), redirect: "manual" });
  assert.equal(respawn.status, 303);
  assert.equal(calls.filter((path) => path.endsWith("admin_respawn_zombies")).length, 1);
});

async function waitForServer(url) {
  for (let attempt = 0; attempt < 40; attempt += 1) {
    try { if ((await fetch(url)).ok) return; } catch (_error) { /* retry */ }
    await new Promise((resolve) => setTimeout(resolve, 50));
  }
  throw new Error("admin server did not start");
}
