import { createHmac, randomBytes, timingSafeEqual } from "node:crypto";
import { createServer } from "node:http";

const port = Number(process.env.ADMIN_PORT || 8080);
const username = required("ADMIN_USERNAME");
const password = required("ADMIN_PASSWORD");
const sessionKey = required("ADMIN_SESSION_KEY");
const nakamaHttpKey = required("NAKAMA_HTTP_KEY");
const nakamaUrl = process.env.NAKAMA_INTERNAL_URL || "http://nakama:7350";
const releaseTag = process.env.RELEASE_TAG || "v0.1.0-prealpha.2";
const repository = process.env.GITHUB_REPOSITORY || "syb1v/deadworld";
const sessions = new Map();
const loginAttempts = new Map();

createServer(async (request, response) => {
  securityHeaders(response);
  try {
    const url = new URL(request.url || "/", "http://admin");
    if (url.pathname === "/health") return send(response, 200, "ok", "text/plain");
    if (request.method === "GET" && url.pathname === "/status") {
      const status = await rpc("admin_status");
      return send(response, 200, JSON.stringify({ online: !status.persistence_stale, players: status.players_online, zombies_alive: status.zombies_alive, zombies_total: status.zombies_total }), "application/json; charset=utf-8");
    }
    if (request.method === "GET" && url.pathname === "/landing") return send(response, 200, landingPage());
    if (request.method === "GET" && url.pathname === "/login") return send(response, 200, loginPage());
    if (request.method === "POST" && url.pathname === "/login") return login(request, response);
    const session = readSession(request);
    if (!session) return redirect(response, "/admin/login");
    if (request.method === "POST" && url.pathname === "/logout") {
      const body = await readForm(request);
      if (!safeEqual(body.get("csrf") || "", session.csrf)) return send(response, 403, errorPage("CSRF validation failed"));
      sessions.delete(session.id);
      response.setHeader("Set-Cookie", "deadworld_admin=; Path=/admin; HttpOnly; Secure; SameSite=Strict; Max-Age=0");
      return redirect(response, "/admin/login");
    }
    if (request.method === "POST" && url.pathname === "/respawn-zombies") {
      const body = await readForm(request);
      if (!safeEqual(body.get("csrf") || "", session.csrf)) return send(response, 403, errorPage("CSRF validation failed"));
      const result = await rpc("admin_respawn_zombies", { actor: username });
      return redirect(response, `/admin/?notice=${encodeURIComponent(`Respawned: ${result.respawned ?? 0}`)}`);
    }
    if (request.method === "GET" && url.pathname === "/") {
      const status = await rpc("admin_status");
      return send(response, 200, dashboard(status, session.csrf, url.searchParams.get("notice") || ""));
    }
    return send(response, 404, errorPage("Not found"));
  } catch (error) {
    console.error(JSON.stringify({ event: "admin_request_failed", error: String(error) }));
    return send(response, 502, errorPage("Backend temporarily unavailable"));
  }
}).listen(port, "0.0.0.0", () => console.log(JSON.stringify({ event: "admin_started", port })));

async function login(request, response) {
  const ip = request.socket.remoteAddress || "unknown";
  const now = Date.now();
  const attempts = (loginAttempts.get(ip) || []).filter((at) => now - at < 300000);
  if (attempts.length >= 5) return send(response, 429, errorPage("Too many login attempts"));
  const body = await readForm(request);
  if (!safeEqual(body.get("username") || "", username) || !safeEqual(body.get("password") || "", password)) {
    attempts.push(now); loginAttempts.set(ip, attempts);
    console.warn(JSON.stringify({ event: "admin_login_failed", ip }));
    return send(response, 401, loginPage("Invalid credentials"));
  }
  loginAttempts.delete(ip);
  const id = randomBytes(24).toString("hex");
  const csrf = randomBytes(24).toString("hex");
  sessions.set(id, { id, csrf, expires: now + 8 * 60 * 60 * 1000 });
  const value = `${id}.${sign(id)}`;
  response.setHeader("Set-Cookie", `deadworld_admin=${value}; Path=/admin; HttpOnly; Secure; SameSite=Strict; Max-Age=28800`);
  console.log(JSON.stringify({ event: "admin_login", actor: username, ip }));
  return redirect(response, "/admin/");
}

function readSession(request) {
  const value = parseCookies(request.headers.cookie || "").deadworld_admin || "";
  const separator = value.lastIndexOf(".");
  if (separator < 1) return null;
  const id = value.slice(0, separator);
  if (!safeEqual(value.slice(separator + 1), sign(id))) return null;
  const session = sessions.get(id);
  if (!session || session.expires < Date.now()) { sessions.delete(id); return null; }
  return session;
}

async function rpc(id, input = {}) {
  const url = new URL(`/v2/rpc/${id}`, nakamaUrl);
  url.searchParams.set("http_key", nakamaHttpKey);
  url.searchParams.set("payload", JSON.stringify(input));
  const response = await fetch(url, { signal: AbortSignal.timeout(5000) });
  if (!response.ok) throw new Error(`Nakama RPC ${id} returned ${response.status}`);
  const envelope = await response.json();
  const payload = typeof envelope.payload === "string" ? JSON.parse(envelope.payload) : envelope.payload;
  if (payload?.ok === false) throw new Error(payload.error || "Admin command failed");
  return payload;
}

async function readForm(request) {
  const chunks = [];
  let size = 0;
  for await (const chunk of request) {
    size += chunk.length;
    if (size > 8192) throw new Error("Request body too large");
    chunks.push(chunk);
  }
  return new URLSearchParams(Buffer.concat(chunks).toString("utf8"));
}

function dashboard(status, csrf, notice) {
  const events = (status.events || []).map((event) => `<tr><td>${escapeHtml(new Date(event.at).toISOString())}</td><td>${escapeHtml(eventName(event.event))}</td><td>${escapeHtml(event.actor || "")}</td><td>${escapeHtml(event.target || "")}</td><td>${escapeHtml(event.detail || "")}</td></tr>`).join("");
  return page("Панель управления", `<header><div><span class="eyebrow">DEADWORLD / УПРАВЛЕНИЕ</span><h1>Состояние мира</h1></div><form method="post" action="/admin/logout"><input type="hidden" name="csrf" value="${escapeHtml(csrf)}"><button class="quiet">Выйти</button></form></header>${notice ? `<p class="notice">${escapeHtml(notice)}</p>` : ""}<section class="stats"><article><b>${Number(status.players_online || 0)}</b><span>игроков онлайн</span></article><article><b>${Number(status.zombies_alive || 0)} / ${Number(status.zombies_total || 0)}</b><span>живых зомби</span></article><article><b>${Number(status.world_items || 0)}</b><span>предметов в мире</span></article><article><b>${status.persistence_stale ? "СБОЙ" : "НОРМА"}</b><span>сохранение мира</span></article></section><section class="actions"><div><h2>Тестовое управление</h2><p>Возвращает мёртвых зомби на серверные точки появления и сохраняет результат.</p></div><form method="post" action="/admin/respawn-zombies"><input type="hidden" name="csrf" value="${escapeHtml(csrf)}"><button class="danger">Возродить мёртвых зомби</button></form></section><section><h2>Последние серверные события</h2><div class="table"><table><thead><tr><th>UTC</th><th>Событие</th><th>Инициатор</th><th>Цель</th><th>Детали</th></tr></thead><tbody>${events || "<tr><td colspan=5>Событий пока нет</td></tr>"}</tbody></table></div></section><script>setTimeout(()=>location.reload(),5000)</script>`);
}

function loginPage(error = "") { return page("Вход в админку", `<main class="login"><span class="eyebrow">DEADWORLD / ЗАКРЫТАЯ ЗОНА</span><h1>Управление миром</h1><p>Серверные события и временные инструменты тестирования.</p>${error ? `<p class="error">${escapeHtml(error)}</p>` : ""}<form method="post" action="/admin/login"><label>Логин<input name="username" autocomplete="username" required autofocus></label><label>Пароль<input type="password" name="password" autocomplete="current-password" required></label><button>Войти</button></form></main>`); }
function errorPage(message) { return page("Ошибка", `<main class="login"><span class="eyebrow">DEADWORLD</span><h1>${escapeHtml(message)}</h1><a href="/admin/">Вернуться</a></main>`); }
function landingPage() {
  const base = `https://github.com/${repository}/releases/download/${releaseTag}`;
  return `<!doctype html><html lang="ru"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width"><meta name="description" content="Project Deadworld — сетевой survival tech test"><title>Project Deadworld — Pre-alpha</title><style>:root{color-scheme:dark;--bg:#070a08;--paper:#d9ddc7;--acid:#c9e36b;--rust:#ba5d48;--line:#2b372f;--muted:#819087}*{box-sizing:border-box}body{margin:0;background:linear-gradient(110deg,rgba(16,31,21,.9),transparent 42%),repeating-linear-gradient(90deg,transparent 0 79px,rgba(255,255,255,.025) 80px),var(--bg);color:var(--paper);font:16px/1.55 ui-monospace,SFMono-Regular,Menlo,monospace}main{max-width:1240px;margin:auto;padding:clamp(24px,5vw,76px)}nav{display:flex;justify-content:space-between;align-items:center;border-bottom:1px solid var(--line);padding-bottom:18px}.mark{color:var(--acid);letter-spacing:.18em;font-size:12px}.version{color:var(--muted)}.hero{min-height:62vh;display:grid;grid-template-columns:1.3fr .7fr;gap:7vw;align-items:center}.kicker{color:var(--rust);letter-spacing:.15em;font-size:12px}.hero h1{font:800 clamp(64px,12vw,158px)/.76 system-ui;margin:25px 0;letter-spacing:-.075em}.hero h1 i{display:block;color:transparent;-webkit-text-stroke:1px var(--paper);font-style:normal}.lead{max-width:650px;color:#9ca9a0;font-size:clamp(17px,2vw,23px)}.signal{border:1px solid var(--line);padding:26px;background:rgba(11,17,13,.75);position:relative}.signal:before{content:"";position:absolute;inset:-1px auto -1px -1px;width:4px;background:var(--acid)}.status-line{display:flex;align-items:center;gap:12px}.dot{width:10px;height:10px;border-radius:50%;background:#777}.dot.on{background:var(--acid);box-shadow:0 0 18px var(--acid)}.big{font:800 56px system-ui;margin:16px 0 0}.label{color:var(--muted)}section{border-top:1px solid var(--line);padding:50px 0}.downloads{display:grid;grid-template-columns:repeat(3,1fr);gap:14px}.card{display:flex;flex-direction:column;min-height:220px;padding:24px;border:1px solid var(--line);color:inherit;text-decoration:none;background:#0d130f;transition:.2s}.card:hover{border-color:var(--acid);transform:translateY(-3px)}.card b{font:700 28px system-ui}.card span{margin-top:auto;color:var(--acid)}.foot{display:flex;justify-content:space-between;color:var(--muted);font-size:13px}@media(max-width:800px){.hero{grid-template-columns:1fr;padding:70px 0}.downloads{grid-template-columns:1fr}.hero h1{font-size:21vw}.foot{display:block}}</style></head><body><main><nav><span class="mark">PROJECT DEADWORLD</span><span class="version">${escapeHtml(releaseTag)} / PRE-ALPHA</span></nav><div class="hero"><div><span class="kicker">ПЕРСИСТЕНТНЫЙ ONLINE SURVIVAL</span><h1>МЁРТВЫЙ<i>МИР</i></h1><p class="lead">Маленький общий мир, где сервер решает всё: движение, бой, добычу, смерть и сохранение. Технический тест для 2–5 выживших.</p></div><aside class="signal"><div class="status-line"><span id="dot" class="dot"></span><b id="state">ПРОВЕРКА СЕРВЕРА</b></div><p id="players" class="big">—</p><span class="label">ИГРОКОВ СЕЙЧАС</span><p id="zombies" class="label">Зомби: —</p></aside></div><section><span class="kicker">СБОРКИ ДЛЯ ТЕСТА</span><h2>Выбери платформу</h2><div class="downloads"><a class="card" href="${base}/deadworld-linux-x86_64.zip"><b>Linux</b><p>x86_64 · executable + PCK</p><span>СКАЧАТЬ ZIP →</span></a><a class="card" href="${base}/deadworld-windows-x86_64.zip"><b>Windows</b><p>x86_64 · portable pre-alpha</p><span>СКАЧАТЬ ZIP →</span></a><a class="card" href="${base}/deadworld-android-arm64.apk"><b>Android</b><p>arm64 · debug signed APK</p><span>СКАЧАТЬ APK →</span></a></div></section><section class="foot"><span>WASD / TOUCH · E ВЗЯТЬ · ЛКМ АТАКА · R ПЕРЕЗАРЯДКА</span><span>НЕ ФИНАЛЬНАЯ ИГРА. PRE-ALPHA TECH TEST.</span></section></main><script>async function poll(){try{const r=await fetch('/status',{cache:'no-store'}),s=await r.json();document.querySelector('#dot').classList.toggle('on',s.online);document.querySelector('#state').textContent=s.online?'СЕРВЕР В СЕТИ':'СЕРВЕР НЕДОСТУПЕН';document.querySelector('#players').textContent=s.players;document.querySelector('#zombies').textContent='Зомби: '+s.zombies_alive+' / '+s.zombies_total}catch{document.querySelector('#state').textContent='СЕРВЕР НЕДОСТУПЕН'}}poll();setInterval(poll,10000)</script></body></html>`;
}
function eventName(value) { return ({ player_join: "Игрок вошёл", player_leave: "Игрок вышел", attack: "Атака", zombie_death: "Зомби убит", player_death: "Игрок погиб", item_pickup: "Предмет подобран", item_drop: "Предмет выброшен", container_take: "Взято из контейнера", container_deposit: "Положено в контейнер", admin_respawn_zombies: "Админ: возрождение зомби" })[value] || value; }
function page(title, content) { return `<!doctype html><html lang="ru"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>${title} | Deadworld</title><style>:root{color-scheme:dark;--bg:#090d0b;--panel:#111914;--line:#26352b;--ink:#dbe9d9;--muted:#789080;--acid:#b9d45d;--danger:#c85b4d}*{box-sizing:border-box}body{margin:0;background:radial-gradient(circle at 15% 0,#19271d 0,transparent 35%),var(--bg);color:var(--ink);font:15px/1.5 ui-monospace,SFMono-Regular,Menlo,monospace;min-height:100vh;padding:clamp(20px,4vw,64px)}body>header,body>section,body>.notice{max-width:1180px;margin:0 auto 28px}header{display:flex;justify-content:space-between;align-items:end;border-bottom:1px solid var(--line);padding-bottom:22px}.eyebrow{color:var(--acid);font-size:12px;letter-spacing:.16em}h1{font:700 clamp(36px,7vw,80px)/.95 system-ui;margin:12px 0}h2{font:650 20px system-ui}.stats{display:grid;grid-template-columns:repeat(4,1fr);gap:12px}.stats article,.actions,.login{background:color-mix(in srgb,var(--panel) 90%,transparent);border:1px solid var(--line);padding:24px}.stats b{display:block;font:700 34px system-ui;color:var(--acid)}.stats span,p{color:var(--muted)}.actions{display:flex;align-items:center;justify-content:space-between}.table{overflow:auto;border:1px solid var(--line)}table{border-collapse:collapse;width:100%;background:var(--panel)}th,td{text-align:left;padding:12px;border-bottom:1px solid var(--line);white-space:nowrap}th{color:var(--muted);font-size:12px}button{border:0;background:var(--acid);color:#10150e;font:700 14px ui-monospace;padding:13px 18px;cursor:pointer}.danger{background:var(--danger);color:white}.quiet{background:transparent;color:var(--muted);border:1px solid var(--line)}.login{max-width:460px;margin:10vh auto}.login form{display:grid;gap:18px;margin-top:30px}label{display:grid;gap:7px;color:var(--muted)}input{width:100%;background:#080c09;color:var(--ink);border:1px solid var(--line);padding:13px;font:inherit}.error{color:#ff8c7c}.notice{border-left:3px solid var(--acid);background:var(--panel);padding:12px 18px;color:var(--ink)}a{color:var(--acid)}@media(max-width:760px){.stats{grid-template-columns:1fr 1fr}.actions{align-items:stretch;flex-direction:column;gap:18px}.actions button{width:100%}header{align-items:start}}</style></head><body>${content}</body></html>`; }

function required(name) { const value = process.env[name]; if (!value) throw new Error(`${name} is required`); return value; }
function sign(value) { return createHmac("sha256", sessionKey).update(value).digest("hex"); }
function safeEqual(left, right) { const a = Buffer.from(left); const b = Buffer.from(right); return a.length === b.length && timingSafeEqual(a, b); }
function parseCookies(value) { return Object.fromEntries(value.split(";").map((part) => part.trim().split(/=(.*)/s).slice(0, 2)).filter(([key]) => key)); }
function escapeHtml(value) { return String(value).replace(/[&<>"']/g, (character) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[character]); }
function securityHeaders(response) { response.setHeader("Content-Security-Policy", "default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline'; connect-src 'self'; form-action 'self'; frame-ancestors 'none'; base-uri 'none'"); response.setHeader("Referrer-Policy", "no-referrer"); response.setHeader("X-Content-Type-Options", "nosniff"); response.setHeader("Cache-Control", "no-store"); }
function send(response, status, body, type = "text/html; charset=utf-8") { response.writeHead(status, { "Content-Type": type }); response.end(body); }
function redirect(response, location) { response.writeHead(303, { Location: location }); response.end(); }
