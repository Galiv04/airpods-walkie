# Roadmap / TODO

- [x] MVP: Multipeer + PTT/latch/VOX + play/pausa AirPods + CI IPA
- [x] Build CI verde, IPA pubblicato in release `latest`
- [ ] Test su dispositivi reali: latenza, qualità HFP, comportamento in background
- [ ] Icona app e nome
- [x] Trasporto internet (relay WebSocket + E2E) con selezione automatica (da testare con relay reale: serve deploy, vedi docs/RELAY.md)
- [ ] Codec Opus per ridurre banda su rete mobile (ora PCM ≈ 48 KB/s)
- [ ] Deploy del relay su Cloudflare (richiede token dell'utente) e variabile RELAY_URL
- [ ] Valutare WebRTC P2P (STUN/TURN) al posto del relay
- [ ] Verificare su device l'opzione alta qualità iOS 26 e il tasto AirPods in background
- [ ] Source AltStore/SideStore (JSON) per aggiornamenti OTA
- [ ] Firma + TestFlight in CI (richiede Apple Developer Program)
- [ ] Beep roger/inizio trasmissione, indicatore batteria AirPods

- [ ] Pubblicazione store: vedi docs/STORE.md
