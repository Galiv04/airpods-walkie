# Contesto progetto (per Claude / agenti)

**Obiettivo**: app iOS walkie-talkie tra due iPhone (utente + Claudia) con AirPods ANC, per ambienti rumorosi (moto, aereo). Uso personale, no App Store.

**Regole di lavoro**
- Lavorare in autonomia; l'utente (Gaetano) accetta decisioni ragionevoli e vuole essere informato nel riepilogo finale. Lingua: italiano.
- Mantenere aggiornati README.md, docs/*, e questo file a ogni modifica rilevante (stato, decisioni, TODO).
- Repo pubblica: niente segreti reali committati; i secrets vanno in GitHub Secrets.
- Nessun Mac/Xcode nell'ambiente cloud: il codice Swift NON è compilabile localmente. Verificare tramite GitHub Actions (`.github/workflows/build.yml`, runner macOS) e correggere gli errori dai log.

**Stack**: SwiftUI, iOS 16+, XcodeGen (`project.yml` → xcodeproj non versionato), AVAudioEngine, MultipeerConnectivity, URLSessionWebSocketTask, CryptoKit; relay JS (Cloudflare Workers).

**File chiave** (`AirPodsWalkie/`): `AudioEngine.swift` (cattura/riproduzione, Int16 16kHz), `PeerTransport.swift` (Multipeer, stanza), `WalkieModel.swift` (stato, PTT/latch/VOX, comandi remoti AirPods), `ContentView.swift` (UI), `Wire.swift` (formato messaggi + crypto stanza), `RelayTransport.swift` (WebSocket internet). Server: `relay/` (Cloudflare Worker `worker.js`, Node `server.js`, test `test.js`).

**Decisioni**: vedi docs/ARCHITECTURE.md. **Stato/TODO**: docs/ROADMAP.md.

**Stato corrente**: v0.3 (UI ridisegnata, icona in Assets.xcassets generata da tools/make_icon.py, niente più showSystemUserInterface(.microphoneModes)) – link vicino + relay internet implementati; CI iOS da verificare dopo ultimo push; relay deployato su https://airwalkie-relay.galiv04.workers.dev (default incorporato in build.yml; vedi docs/RELAY.md); mai testato su device. Requisito iOS 16+. Guida installazione gratuita: docs/INSTALL-SENZA-DEVELOPER.md.
