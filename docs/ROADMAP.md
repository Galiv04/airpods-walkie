# Roadmap / TODO

- [x] MVP: Multipeer + PTT/latch/VOX + play/pausa AirPods + CI IPA
- [x] Build CI verde, IPA pubblicato in release `latest`
- [ ] Test su dispositivi reali: latenza, qualità HFP, comportamento in background
- [ ] Icona app e nome
- [x] Trasporto internet (relay WebSocket + E2E) con selezione automatica (da testare con relay reale: serve deploy, vedi docs/RELAY.md)
- [ ] Codec Opus per ridurre banda su rete mobile (ora PCM ≈ 48 KB/s)
- [x] Relay deployato su https://airwalkie-relay.galiv04.workers.dev (URL di default nel workflow Build IPA); da testare con due telefoni
- [ ] Valutare WebRTC P2P (STUN/TURN) al posto del relay
- [ ] Verificare su device l'opzione alta qualità iOS 26 e il tasto AirPods in background
- [ ] Source AltStore/SideStore (JSON) per aggiornamenti OTA
- [ ] Firma + TestFlight in CI (richiede Apple Developer Program)
- [ ] Beep roger/inizio trasmissione, indicatore batteria AirPods

- [ ] Pubblicazione store: vedi docs/STORE.md

- [x] UI ridisegnata (v0.3): pulsante centrale Avvia/Parla, impostazioni in sheet, icona app (tools/make_icon.py); rimosso il pulsante «Isolamento voce» in-app (apriva la UI di sistema che bloccava lo schermo sfocato) → usare Centro di Controllo › Modalità microfono
