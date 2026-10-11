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

export default {
  async fetch(request, env) {
    const m = new URL(request.url).pathname.match(/^\/room\/([0-9a-f]{16,64})$/);
    if (!m) return new Response("airpods-walkie relay ok");
    return env.ROOM.get(env.ROOM.idFromName(m[1])).fetch(request);
  },
};
