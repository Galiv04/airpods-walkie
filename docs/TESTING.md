# Come si verifica Roger

## Oggi (automatico, a ogni push)
- **Build IPA** (runner macOS): compila l'app per iPhone.
- **Screenshot UI** (job `screenshots` di Build IPA): compila per il simulatore, apre l'app in
  modalità demo (`-demo off|waiting|linked|talking|remote|settings`) su un iPhone piccolo e uno grande,
  salva gli screenshot come artifact `screenshots` (solo iPhone piccolo; `SCREENSHOT_BIG=1` aggiunge il Pro Max). Il boot del simulatore in CI richiede ~10 min. Così layout e stile si controllano prima di installare.
  In locale su un Mac: `xcodegen generate && tools/ci-screenshots.sh out/`.
- **Relay**: `relay/test.js` (CI di Deploy relay) e test end-to-end sul relay reale dal container di sviluppo.

- **Unit test** (job `test`): `Tests/RogerTests.swift` – codice coppia, formato messaggi, cifratura, logica tocco/pressione lunga.
- **Test eco** (anche dall'app: Impostazioni › «Prova da solo»): endpoint `/echo/<id>` del relay che rimanda i pacchetti cifrati al mittente dopo 1,5 s. Verificato dal container con `RELAY=wss://airwalkie-relay.galiv04.workers.dev node relay/test.js`.

## Cosa NON si può verificare senza telefoni
Audio reale con AirPods (HFP, voice processing, isolamento vocale), Multipeer tra due dispositivi,
tasto AirPods in background. Il simulatore non ha Bluetooth né AirPods.

## Proposte per il futuro
1. ~~Test unitari~~ (fatti). Da aggiungere: jitter buffer di `AudioEngine` con pacchetti finti.
2. **Test di loopback audio nel simulatore**: due istanze dell'app (due simulatori) collegate via relay
   locale (`relay/server.js`), con un file WAV al posto del microfono; si misura che l'audio arrivi e la latenza.
3. ~~Telefono finto~~ → fatto come **test eco** sul relay.
4. **TestFlight** (con Apple Developer Program): installazione con un link e log di crash automatici.
