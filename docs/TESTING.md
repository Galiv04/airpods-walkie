# Come si verifica Roger

## Oggi (automatico, a ogni push)
- **Build IPA** (runner macOS): compila l'app per iPhone.
- **Screenshot UI** (job `screenshots` di Build IPA): compila per il simulatore, apre l'app in
  modalità demo (`-demo off|waiting|linked|talking|remote|settings`) su un iPhone piccolo e uno grande,
  salva gli screenshot come artifact `screenshots`. Così layout e stile si controllano prima di installare.
  In locale su un Mac: `xcodegen generate && tools/ci-screenshots.sh out/`.
- **Relay**: `relay/test.js` (CI di Deploy relay) e test end-to-end sul relay reale dal container di sviluppo.

## Cosa NON si può verificare senza telefoni
Audio reale con AirPods (HFP, voice processing, isolamento vocale), Multipeer tra due dispositivi,
tasto AirPods in background. Il simulatore non ha Bluetooth né AirPods.

## Proposte per il futuro
1. **Test unitari** (XCTest nel simulatore in CI): formato messaggi `Wire`, cifratura `RoomCrypto`,
   `PairCode`, logica tocco/pressione lunga, jitter buffer di `AudioEngine` (alimentandolo con pacchetti finti).
2. **Test di loopback audio nel simulatore**: due istanze dell'app (due simulatori) collegate via relay
   locale (`relay/server.js`), con un file WAV al posto del microfono; si misura che l'audio arrivi e la latenza.
3. **Client di test da riga di comando** (Node) che parla col relay con lo stesso protocollo/cifratura:
   permette di provare un singolo iPhone reale contro il "telefono finto" nel cloud, senza Claudia.
4. **TestFlight** (con Apple Developer Program): installazione con un link e log di crash automatici.
