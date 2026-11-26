// 방귀 대결 온라인 서버
//  - HTTP: 게임 페이지(web/fart_battle.html)를 그대로 내려준다 → 주소 하나로 접속
//  - WebSocket(/ws): 로비(접속자 수·공개방 목록), 방 만들기(공개/비밀 코드), 코드 입장, 랜덤 매칭,
//    경기 중 메시지 중계. 게임 규칙 계산은 방장(host) 브라우저가 하고 서버는 중계만 한다.
// 실행: npm install && npm start   (PORT 환경변수, 기본 8080)
"use strict";
const http = require("http");
const fs = require("fs");
const path = require("path");
const { WebSocketServer } = require("ws");

const PORT = Number(process.env.PORT) || 8080;
const PAGE = process.env.GAME_PAGE || path.join(__dirname, "..", "web", "fart_battle.html");
const MAX_MSG = 16 * 1024;
const RELAY_DELAY_MS = Number(process.env.RELAY_DELAY_MS) || 0; // 테스트용: 네트워크 지연 흉내
const FIGHTERS = ["puang", "kid", "grandma", "muscle", "doctor", "king"];

const MANIFEST = JSON.stringify({
  name: "방귀 대결", short_name: "방귀 대결", start_url: "/", display: "standalone", orientation: "portrait",
  background_color: "#2A2138", theme_color: "#2A2138",
  icons: [{ src: "/icon.svg", sizes: "any", type: "image/svg+xml", purpose: "any" }],
});
const ICON = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128"><rect width="128" height="128" rx="28" fill="#2A2138"/><circle cx="54" cy="70" r="30" fill="#6B5A70"/><circle cx="80" cy="66" r="22" fill="#7A6A80"/><circle cx="104" cy="60" r="14" fill="#C8F07A"/><circle cx="114" cy="48" r="9" fill="#C8F07A"/><circle cx="40" cy="64" r="4" fill="#1A1A1A"/><circle cx="26" cy="74" r="7" fill="#FF8FB8"/></svg>`;

// ───── HTTP ─────
const server = http.createServer((req, res) => {
  const url = (req.url || "/").split("?")[0];
  if (url === "/" || url === "/index.html") {
    fs.readFile(PAGE, (err, buf) => {
      if (err) { res.writeHead(500, { "content-type": "text/plain; charset=utf-8" }); res.end("게임 페이지를 찾을 수 없어요: " + PAGE); return; }
      // 홈 화면에 추가했을 때 앱처럼 열리도록 manifest 연결
      const html = buf.toString("utf8").replace("<meta charset=\"utf-8\">", "<meta charset=\"utf-8\">\n<link rel=\"manifest\" href=\"/manifest.webmanifest\">\n<link rel=\"icon\" href=\"/icon.svg\">\n<meta name=\"theme-color\" content=\"#2A2138\">\n<meta name=\"apple-mobile-web-app-capable\" content=\"yes\">");
      res.writeHead(200, { "content-type": "text/html; charset=utf-8", "cache-control": "no-cache" }); res.end(html);
    });
  } else if (url === "/manifest.webmanifest") { res.writeHead(200, { "content-type": "application/manifest+json" }); res.end(MANIFEST); }
  else if (url === "/icon.svg") { res.writeHead(200, { "content-type": "image/svg+xml" }); res.end(ICON); }
  else if (url === "/health") { res.writeHead(200, { "content-type": "application/json" }); res.end(JSON.stringify({ ok: true, online: clients.size, rooms: rooms.size })); }
  else { res.writeHead(404); res.end(); }
});

// ───── 로비 상태 ─────
const clients = new Map(); // id → client { id, ws, name, fighter, room, queued, match }
const rooms = new Map();   // code → { code, public, host, created }
let queue = [];            // 랜덤 매칭 대기 (client id)
let nextId = 1;

function send(c, msg) { if (c && c.ws.readyState === 1) c.ws.send(JSON.stringify(msg)); }
function cleanName(s) { s = String(s || "").replace(/[\u0000-\u001f<>&"'`]/g, "").trim().slice(0, 12); return s || "뿡뿡이"; }
function newCode() { const A = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; for (;;) { let c = ""; for (let i = 0; i < 4; i++) c += A[Math.floor(Math.random() * A.length)]; if (!rooms.has(c)) return c; } }
function roomList() {
  return [...rooms.values()].filter(r => r.public).sort((a, b) => a.created - b.created).slice(0, 30)
    .map(r => { const h = clients.get(r.host); return { code: r.code, name: h ? h.name : "?", fighter: h ? h.fighter : "puang" }; });
}
let lobbyDirty = false;
function markLobby() { lobbyDirty = true; }
setInterval(() => {
  if (!lobbyDirty) return; lobbyDirty = false;
  const msg = { t: "lobby", online: clients.size, rooms: roomList(), waiting: queue.length };
  for (const c of clients.values()) if (!c.match) send(c, msg);
}, 300);

function leaveWaiting(c) {
  if (c.room) { rooms.delete(c.room); c.room = null; markLobby(); }
  if (c.queued) { queue = queue.filter(id => id !== c.id); c.queued = false; markLobby(); }
}
function startMatch(host, guest) {
  leaveWaiting(host); leaveWaiting(guest);
  host.match = guest.id; guest.match = host.id;
  const seed = Math.floor(Math.random() * 1e9);
  send(host, { t: "start", role: "host", opp: { name: guest.name, fighter: guest.fighter }, seed });
  send(guest, { t: "start", role: "guest", opp: { name: host.name, fighter: host.fighter }, seed });
  markLobby();
}
function endMatch(c, why) {
  const o = clients.get(c.match); c.match = null;
  if (o && o.match === c.id) { o.match = null; send(o, { t: "opp_left", why }); }
  markLobby();
}

// ───── WebSocket ─────
const wss = new WebSocketServer({ server, path: "/ws", maxPayload: MAX_MSG });
wss.on("connection", ws => {
  const c = { id: nextId++, ws, name: "뿡뿡이", fighter: "puang", room: null, queued: false, match: null, alive: true };
  clients.set(c.id, c);
  ws.on("pong", () => { c.alive = true; });
  ws.on("message", raw => {
    let m; try { m = JSON.parse(raw); } catch (e) { return; }
    if (!m || typeof m.t !== "string") return;
    switch (m.t) {
      case "hello":
        c.name = cleanName(m.name); c.fighter = FIGHTERS.includes(m.fighter) ? m.fighter : "puang";
        send(c, { t: "welcome", id: c.id }); markLobby(); break;
      case "ping": send(c, { t: "pong", at: m.at }); break;
      case "create": { // 방 만들기: public=true 면 목록에 공개, false 면 코드로만 입장
        if (c.match) return; leaveWaiting(c);
        const code = newCode(); rooms.set(code, { code, public: !!m.public, host: c.id, created: Date.now() }); c.room = code;
        send(c, { t: "room", code, public: !!m.public }); markLobby(); break;
      }
      case "join": { // 코드 입장 / 목록에서 입장
        if (c.match) return;
        const code = String(m.code || "").toUpperCase().trim(), r = rooms.get(code), h = r && clients.get(r.host);
        if (!r || !h || h === c) { send(c, { t: "error", msg: "방을 찾을 수 없어요 (이미 시작했거나 닫힌 방)" }); return; }
        startMatch(h, c); break;
      }
      case "quick": { // 랜덤 매칭: 대기열 상대 → 공개방 → 없으면 대기
        if (c.match) return; leaveWaiting(c);
        const other = queue.map(id => clients.get(id)).find(o => o && o !== c && !o.match);
        if (other) { startMatch(other, c); return; }
        const open = [...rooms.values()].filter(r => r.public).sort((a, b) => a.created - b.created)[0];
        if (open && clients.get(open.host)) { startMatch(clients.get(open.host), c); return; }
        queue.push(c.id); c.queued = true; send(c, { t: "queued" }); markLobby(); break;
      }
      case "cancel": leaveWaiting(c); send(c, { t: "cancelled" }); break;
      case "relay": { // 경기 중 메시지 중계 (방장 ↔ 손님)
        const o = clients.get(c.match); if (!o || o.match !== c.id) break;
        if (RELAY_DELAY_MS) setTimeout(() => send(o, { t: "relay", d: m.d }), RELAY_DELAY_MS); else send(o, { t: "relay", d: m.d });
        break;
      }
      case "leave": if (c.match) endMatch(c, "left"); break;
    }
  });
  ws.on("close", () => { leaveWaiting(c); if (c.match) endMatch(c, "disconnected"); clients.delete(c.id); markLobby(); });
  markLobby();
});
// 끊긴 연결 정리
setInterval(() => { for (const c of clients.values()) { if (!c.alive) { c.ws.terminate(); continue; } c.alive = false; try { c.ws.ping(); } catch (e) {} } }, 15000);

server.listen(PORT, () => console.log(`방귀 대결 서버: http://localhost:${PORT}  (게임 페이지: ${PAGE})`));
