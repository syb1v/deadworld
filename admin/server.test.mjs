import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { createServer } from "node:http";
import { rmSync } from "node:fs";
import test from "node:test";

test("admin login, status and CSRF-protected respawn", async (context) => {
  const calls = [];
  const mock = createServer((request, response) => {
    const url = new URL(request.url, "http://mock");
    calls.push(url.pathname);
    if (url.pathname === "/releases") {
      response.setHeader("Content-Type", "application/json");
      return response.end(JSON.stringify([{ tag_name: "v10.0.0-incomplete", draft: false, assets: [{ name: "deadworld-v10.0.0-incomplete-linux-x86_64.tar.gz" }] }, { tag_name: releaseTag, draft: false, prerelease: true, assets: releaseAssets.map((name) => ({ name })) }]));
    }
    const result = url.pathname.endsWith("admin_respawn_zombies") ? { ok: true, respawned: 2 } : { ok: true, players_online: 1, zombies_alive: 1, zombies_total: 3, events: [] };
    response.setHeader("Content-Type", "application/json");
    response.end(JSON.stringify({ payload: JSON.stringify(result) }));
  });
  await new Promise((resolve) => mock.listen(18181, "127.0.0.1", resolve));
  const settingsPath = "/tmp/opencode/deadworld-admin-test-settings.json";
  rmSync(settingsPath, { force: true });
  const child = spawn(process.execPath, ["admin/server.mjs"], { cwd: new URL("..", import.meta.url), env: { ...process.env, ADMIN_PORT: "18182", ADMIN_USERNAME: "operator", ADMIN_PASSWORD: "test-password", ADMIN_SESSION_KEY: "test-session-key", NAKAMA_HTTP_KEY: "private-http-key", NAKAMA_INTERNAL_URL: "http://127.0.0.1:18181", GITHUB_RELEASES_URL: "http://127.0.0.1:18181/releases", LANDING_SETTINGS_PATH: settingsPath }, stdio: "ignore" });
  context.after(() => { child.kill(); mock.close(); rmSync(settingsPath, { force: true }); });
  await waitForServer("http://127.0.0.1:18182/health");

  const landingResponse = await fetch("http://127.0.0.1:18182/landing");
  assert.match(landingResponse.headers.get("content-security-policy") ?? "", /connect-src 'self'/);
  const landing = await landingResponse.text();
  assert.match(landing, /МЁРТВЫЙ/);
  for (const asset of releaseAssets) assert.match(landing, new RegExp(asset.replaceAll(".", "\\.")));
  assert.match(landing, /требуется переподписание/);
  assert.match(landing, new RegExp(`SHA256SUMS-${releaseTag.replaceAll(".", "\\.")}\\.txt`));
  assert.doesNotMatch(landing, /v10\.0\.0-incomplete/);
  assert.match(landing, new RegExp(releaseTag.replaceAll(".", "\\.")));
  assert.doesNotMatch(landing, /href="[^"]*deadworld-(?:linux|windows|android|ios)-[^"]*"/);
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

  const settingsPage = await fetch("http://127.0.0.1:18182/landing-settings", { headers: { Cookie: cookie } });
  assert.equal(settingsPage.status, 200);
  assert.match(await settingsPage.text(), /Настройки лендинга/);

  const settingsForbidden = await fetch("http://127.0.0.1:18182/landing-settings", { method: "POST", headers: { Cookie: cookie }, body: new URLSearchParams({ csrf: "wrong", description: "Новое описание", announcement: "Тест", releaseMode: "manual", manualReleaseTag: "v1.2.3" }), redirect: "manual" });
  assert.equal(settingsForbidden.status, 403);

  const settingsSaved = await fetch("http://127.0.0.1:18182/landing-settings", { method: "POST", headers: { Cookie: cookie }, body: new URLSearchParams({ csrf, description: "Новое описание", announcement: "Тестовое объявление", releaseMode: "manual", manualReleaseTag: "v1.2.3" }), redirect: "manual" });
  assert.equal(settingsSaved.status, 303);
  const updatedLanding = await (await fetch("http://127.0.0.1:18182/landing")).text();
  assert.match(updatedLanding, /Новое описание/);
  assert.match(updatedLanding, /Тестовое объявление/);
  assert.match(updatedLanding, /releases\/download\/v1\.2\.3/);

  const logoutForbidden = await fetch("http://127.0.0.1:18182/logout", { method: "POST", headers: { Cookie: cookie }, body: new URLSearchParams({ csrf: "wrong" }), redirect: "manual" });
  assert.equal(logoutForbidden.status, 403);

  const forbidden = await fetch("http://127.0.0.1:18182/respawn-zombies", { method: "POST", headers: { Cookie: cookie }, body: new URLSearchParams({ csrf: "wrong" }), redirect: "manual" });
  assert.equal(forbidden.status, 403);
  assert.equal(calls.filter((path) => path.endsWith("admin_respawn_zombies")).length, 0);

  const respawn = await fetch("http://127.0.0.1:18182/respawn-zombies", { method: "POST", headers: { Cookie: cookie }, body: new URLSearchParams({ csrf }), redirect: "manual" });
  assert.equal(respawn.status, 303);
  assert.equal(calls.filter((path) => path.endsWith("admin_respawn_zombies")).length, 1);
});

const releaseTag = "v0.1.0-prealpha.6";
const releaseAssets = [
  `deadworld-${releaseTag}-linux-x86_64.tar.gz`, `deadworld-${releaseTag}-linux-x86_32.tar.gz`, `deadworld-${releaseTag}-linux-arm64.tar.gz`, `deadworld-${releaseTag}-linux-arm32.tar.gz`,
  `deadworld-${releaseTag}-linux-amd64.deb`, `deadworld-${releaseTag}-linux-i386.deb`, `deadworld-${releaseTag}-linux-arm64.deb`, `deadworld-${releaseTag}-linux-armhf.deb`,
  `deadworld-${releaseTag}-linux-x86_64.rpm`, `deadworld-${releaseTag}-linux-i686.rpm`, `deadworld-${releaseTag}-linux-aarch64.rpm`, `deadworld-${releaseTag}-linux-armv7hl.rpm`,
  `deadworld-${releaseTag}-windows-x86_64.zip`, `deadworld-${releaseTag}-windows-x86_32.zip`, `deadworld-${releaseTag}-windows-arm64.zip`,
  `deadworld-${releaseTag}-windows-x86_64.exe`, `deadworld-${releaseTag}-windows-x86_32.exe`, `deadworld-${releaseTag}-windows-arm64.exe`,
  `deadworld-${releaseTag}-android-universal.apk`, `deadworld-${releaseTag}-ios-arm64-unsigned.ipa`, `deadworld-${releaseTag}-ios-arm64-unsigned.ipa.sha256`, `SHA256SUMS-${releaseTag}.txt`
];

async function waitForServer(url) {
  for (let attempt = 0; attempt < 40; attempt += 1) {
    try { if ((await fetch(url)).ok) return; } catch (_error) { /* retry */ }
    await new Promise((resolve) => setTimeout(resolve, 50));
  }
  throw new Error("admin server did not start");
}
