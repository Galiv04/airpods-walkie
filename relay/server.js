// Relay self-hosted (Node 18+): `npm install && node server.js` (porta PORT o 8787).
// Stesso protocollo di worker.js. Mettilo dietro TLS (Caddy/nginx/Fly/Render) per avere wss://.
const { WebSocketServer } = require("ws");
const http = require("http");

const rooms = new Map();
const server = http.createServer((_, res) => res.end("airpods-walkie relay ok"));
const wss = new WebSocketServer({ noServer: true });

server.on("upgrade", (req, socket, head) => {
  if (/^\/echo\/[0-9a-f]{16,64}$/.test(req.url)) return wss.handleUpgrade(req, socket, head, echo);
  const m = req.url.match(/^\/room\/([0-9a-f]{16,64})$/);
  if (!m) return socket.destroy();
  wss.handleUpgrade(req, socket, head, (ws) => join(m[1], ws));
});

function join(id, ws) {
  const set = rooms.get(id) || new Set();
  rooms.set(id, set);
  if (set.size >= 8) return ws.close();
  set.add(ws);
  const notify = () => { const msg = JSON.stringify({ peers: set.size }); for (const s of set) s.send(msg); };
  notify();
  ws.on("message", (data, isBinary) => { for (const s of set) if (s !== ws && s.readyState === 1) s.send(data, { binary: isBinary }); });
  ws.on("close", () => { set.delete(ws); if (!set.size) rooms.delete(id); else notify(); });
  ws.on("error", () => ws.close());
}

// Test eco (vedi worker.js): rimanda i messaggi binari al mittente dopo 1,5 s.
function echo(ws) {
  ws.send(JSON.stringify({ peers: 2 }));
  ws.on("message", (data, isBinary) => {
    if (isBinary) setTimeout(() => ws.readyState === 1 && ws.send(data, { binary: true }), 1500);
  });
  ws.on("error", () => ws.close());
}

server.listen(process.env.PORT || 8787, () => console.log("relay on", server.address().port));
