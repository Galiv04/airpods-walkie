// Test di integrazione del relay: (1) due client nella stessa stanza si scambiano un messaggio binario;
// (2) l'endpoint /echo rimanda indietro il messaggio. URL base: RELAY (default ws://localhost:PORT).
const WebSocket = require("ws");
const base = process.env.RELAY || "ws://localhost:" + (process.env.PORT || 8787);
const id = "0123456789abcdef0123456789abcdef";

function roomTest() {
  return new Promise((ok, fail) => {
    const url = base + "/room/" + id;
    const a = new WebSocket(url), b = new WebSocket(url);
    let ready = false;
    a.on("message", (d, bin) => {
      if (!bin) {
        if (JSON.parse(d.toString()).peers === 2 && !ready) {
          ready = true;
          const go = () => b.send(Buffer.from([1, 2, 3]));
          b.readyState === 1 ? go() : b.on("open", go);
        }
        return;
      }
      if (Buffer.compare(d, Buffer.from([1, 2, 3])) === 0) { a.close(); b.close(); ok("room"); }
    });
    a.on("error", fail); b.on("error", fail);
  });
}

function echoTest() {
  return new Promise((ok, fail) => {
    const ws = new WebSocket(base + "/echo/" + id);
    const t0 = Date.now();
    ws.on("message", (d, bin) => {
      if (!bin) { if (JSON.parse(d.toString()).peers === 2) ws.send(Buffer.from([9, 8, 7])); return; }
      if (Buffer.compare(d, Buffer.from([9, 8, 7])) === 0) { ws.close(); ok("echo " + (Date.now() - t0) + "ms"); }
    });
    ws.on("error", fail);
  });
}

setTimeout(() => { console.error("FAIL timeout"); process.exit(1); }, 10000);
roomTest().then((r) => { console.log("OK", r); return echoTest(); })
  .then((r) => { console.log("OK", r); console.log("OK relay"); process.exit(0); })
  .catch((e) => { console.error("FAIL", e.message); process.exit(1); });
