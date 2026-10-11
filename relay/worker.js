// Relay WebSocket per AirPods Walkie su Cloudflare Workers (Durable Object per stanza).
// Inoltra i messaggi binari (già cifrati end-to-end dai client) agli altri nella stanza
// e comunica il numero di partecipanti come testo {"peers":N}.
const MAX_PEERS = 8;

export class Room {
  constructor() {
    this.sockets = new Set();
  }

  async fetch(request) {
    if (request.headers.get("Upgrade") !== "websocket") return new Response("websocket only", { status: 426 });
    if (this.sockets.size >= MAX_PEERS) return new Response("room full", { status: 429 });
    const [client, server] = Object.values(new WebSocketPair());
    server.accept();
    this.sockets.add(server);
    this.notify();
    server.addEventListener("message", (e) => {
      for (const s of this.sockets) if (s !== server) { try { s.send(e.data); } catch {} }
    });
    const close = () => { this.sockets.delete(server); this.notify(); };
    server.addEventListener("close", close);
    server.addEventListener("error", close);
    return new Response(null, { status: 101, webSocket: client });
  }

  notify() {
    const msg = JSON.stringify({ peers: this.sockets.size });
    for (const s of this.sockets) { try { s.send(msg); } catch {} }
  }
}

// Test eco: rimanda al mittente i suoi stessi messaggi (ancora cifrati) dopo ECHO_DELAY_MS.
// Serve a provare microfono/audio/internet con un solo telefono. Il server non decifra nulla.
const ECHO_DELAY_MS = 1500;
function echo(request) {
  if (request.headers.get("Upgrade") !== "websocket") return new Response("websocket only", { status: 426 });
  const [client, server] = Object.values(new WebSocketPair());
  server.accept();
  server.send(JSON.stringify({ peers: 2 }));
  let pending = 0;
  server.addEventListener("message", (e) => {
    if (typeof e.data === "string" || pending > 400) return;
    pending++;
    setTimeout(() => { pending--; try { server.send(e.data); } catch {} }, ECHO_DELAY_MS);
  });
  return new Response(null, { status: 101, webSocket: client });
}

export default {
  async fetch(request, env) {
    const path = new URL(request.url).pathname;
    if (/^\/echo\/[0-9a-f]{16,64}$/.test(path)) return echo(request);
    const m = path.match(/^\/room\/([0-9a-f]{16,64})$/);
    if (!m) return new Response("airpods-walkie relay ok");
    return env.ROOM.get(env.ROOM.idFromName(m[1])).fetch(request);
  },
};
