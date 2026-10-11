# Relay internet (opzionale, portata illimitata)

Con il collegamento diretto (Multipeer) la portata è ~30–100 m. Per veicoli distanti, o case diverse, i due telefoni usano un piccolo **relay WebSocket** che inoltra audio tra i partecipanti della stessa stanza. Serve **connessione dati su entrambi** i telefoni; non funziona in aereo senza Wi‑Fi di bordo.

## Come funziona
- Modo **Auto** (default): se i telefoni si vedono direttamente usa il link vicino, altrimenti passa su internet. Il passaggio è automatico. Modo **Vicino** = solo diretto, **Internet** = solo relay.
- L'URL del relay contiene solo un hash anonimo della stanza. L'audio è **cifrato end-to-end** (ChaCha20‑Poly1305) con una chiave derivata dal codice stanza: il relay vede solo byte cifrati. **Usa un codice lungo e segreto** per internet (es. `moto-7f3k9x2q-claudia`); un codice corto come "moto" è indovinabile.
- Consumo dati: PCM 24 kHz ≈ 48 KB/s (~170 MB/ora) **solo mentre si parla**. Compressione Opus in roadmap.

## Deploy gratuito su Cloudflare Workers (consigliato, ~5 minuti)

**Istanza attiva:** `https://airwalkie-relay.galiv04.workers.dev` (usata come default dal workflow Build IPA se la variabile `RELAY_URL` non è impostata).
Serve un account Cloudflare gratuito (il piano free include i Durable Objects SQLite usati qui).
1. Su <https://dash.cloudflare.com> › Profile › API Tokens › crea un token con template **Edit Cloudflare Workers**; annota anche l'**Account ID**.
2. Nella repo GitHub › Settings › Secrets and variables › Actions: secrets `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`.
3. Actions › **Deploy relay** › Run workflow. Il log mostra l'URL `https://airwalkie-relay.<tuo-subdominio>.workers.dev`.
4. Nella stessa pagina Settings › Variables (non secrets) crea la variabile `RELAY_URL` con quell'URL; rilancia **Build IPA**: l'indirizzo viene incorporato nell'app e non devi digitarlo. In alternativa incollalo in Walkie › Impostazioni.

Alternativa locale: `cd relay && npm install && node server.js` (porta 8787); serve TLS (wss://) davanti, ad esempio un tunnel Cloudflare o Fly.io/Render.

## Test
`relay/test.js` verifica lo scambio di messaggi; la CI lo esegue a ogni modifica di `relay/`.
