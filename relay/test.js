// Test di integrazione: due client sulla stessa stanza si scambiano un messaggio binario.
const WebSocket = require("ws");
const id = "0123456789abcdef0123456789abcdef";
const url = "ws://localhost:" + (process.env.PORT || 8787) + "/room/" + id;
const a = new WebSocket(url), b = new WebSocket(url);
let peersSeen = 0;
a.on("message", (d, bin) => {
  if (!bin) { if (JSON.parse(d.toString()).peers === 2) { peersSeen++; const go = () => b.send(Buffer.from([1, 2, 3])); b.readyState === 1 ? go() : b.on("open", go); } return; }
  if (Buffer.compare(d, Buffer.from([1, 2, 3])) === 0 && peersSeen) { console.log("OK relay"); process.exit(0); }
});
setTimeout(() => { console.error("FAIL timeout"); process.exit(1); }, 5000);
