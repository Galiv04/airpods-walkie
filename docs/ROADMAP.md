# Roadmap / TODO

- [x] MVP: Multipeer + PTT/latch/VOX + play/pausa AirPods + CI IPA
- [x] Build CI verde, IPA pubblicato in release `latest`
- [ ] Test su dispositivi reali: latenza, qualità HFP, comportamento in background
- [x] Icona app: AirPods + walkie-talkie stile cartoon/inchiostro (tools/make_icon.py)
- [x] Trasporto internet (relay WebSocket + E2E) con selezione automatica (da testare con relay reale: serve deploy, vedi docs/RELAY.md)
- [x] Compressione audio (ADPCM, v0.5): 48 → 12 KB/s. Opus resta un'opzione se servisse ancora meno banda.
- [x] Relay deployato su https://airwalkie-relay.galiv04.workers.dev (URL di default nel workflow Build IPA); da testare con due telefoni
- [ ] Valutare WebRTC P2P (STUN/TURN) al posto del relay
- [ ] Verificare su device l'opzione alta qualità iOS 26 e il tasto AirPods in background
- [ ] Source AltStore/SideStore (JSON) per aggiornamenti OTA
- [ ] Firma + TestFlight in CI (richiede Apple Developer Program)
- [ ] Indicatore batteria AirPods (non esposto da API pubbliche: probabilmente non fattibile)

- [ ] Pubblicazione store: vedi docs/STORE.md

- [x] UI ridisegnata (v0.3): pulsante centrale Avvia/Parla, impostazioni in sheet, icona app (tools/make_icon.py); rimosso il pulsante «Isolamento voce» in-app (apriva la UI di sistema che bloccava lo schermo sfocato) → usare Centro di Controllo › Modalità microfono
- [x] Robustezza (v0.3.1): l'audio riparte da solo dopo cambio route/modalità microfono/interruzioni; il link vicino si ricollega dopo una disconnessione; stato Now Playing = playing per il tasto AirPods (da verificare su device)
- [x] UI v0.4: stile cartoon/inchiostro coerente con l'icona (palette crema/terracotta/inchiostro in `Theme`, ContentView.swift)
- [x] v0.4: home senza sbordamenti (layout proporzionale), un solo pulsante impostazioni, parlato unico (tocca = parla/smetti, tieni premuto = parla finché tieni; «Mani libere» nelle impostazioni), **codice coppia personale e unico** (10 caratteri, condivisibile via link roger://pair?code=…), nome visibile all'altro, impostazioni sempre modificabili (riavvio automatico alla chiusura), screenshot UI automatici in CI (docs/TESTING.md)
- [x] Test unitari XCTest in CI; test eco via relay; onboarding; beep roger/inizio/fine; vibrazione; gestione permesso microfono
- [ ] Prove su due iPhone reali (audio AirPods, Multipeer, tasto AirPods in background) → raccogliere feedback
- [x] Siri/Comandi rapidi «Avvia/Spegni Roger» (v0.5)
- [ ] Live Activity / Dynamic Island con stato collegamento (richiede un'estensione widget: valutare impatto sul sideload gratuito)
- [ ] Indicatore qualità link (latenza/perdite) e riconnessione visibile
