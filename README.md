# AirPods Walkie

Walkie-talkie iPhone ↔ iPhone pensato per **AirPods con cancellazione del rumore** in ambienti rumorosi (moto, aereo, cantiere). Uso personale, installazione fuori dall'App Store.

> Stato: **v0.1 (MVP)** – vedi [docs/ROADMAP.md](docs/ROADMAP.md).

## Come funziona
- Ogni iPhone ha i suoi AirPods; il microfono AirPods (con voice processing: AEC + riduzione rumore) cattura la voce.
- L'audio (PCM 16 kHz mono) viaggia **direttamente tra i due iPhone** via MultipeerConnectivity (Bluetooth / Wi‑Fi peer‑to‑peer): niente internet, funziona in modalità aereo.
- Tre modi: **Premi** (push‑to‑talk), **Tocca** (latch), **Voce** (VOX a mani libere, ideale con i guanti).
- **Play/Pausa sugli AirPods** (stem/tasto) = parla / smetti, anche a schermo bloccato.
- Stessa "stanza" (codice) sui due telefoni = si collegano da soli e solo tra loro.

## Installazione sui due iPhone
Vedi [docs/INSTALL.md](docs/INSTALL.md): GitHub Actions compila un `.ipa` non firmato (release `latest`), poi lo installi con SideStore/AltStore/Sideloadly (Apple ID gratuito, rinnovo ogni 7 giorni) oppure TestFlight con account developer a pagamento.

## Documentazione
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) – architettura e scelte tecniche
- [docs/INSTALL.md](docs/INSTALL.md) – build e installazione
- [docs/RESEARCH.md](docs/RESEARCH.md) – ricerca su soluzioni esistenti
- [docs/ROADMAP.md](docs/ROADMAP.md) – cosa manca / prossimi passi
- [CLAUDE.md](CLAUDE.md) – contesto per agenti AI che lavorano sul progetto

## Sviluppo
Richiede macOS+Xcode 15.3+ e [XcodeGen](https://github.com/yonaskolb/XcodeGen): `xcodegen generate && open AirPodsWalkie.xcodeproj`. Il `.xcodeproj` non è versionato (generato da `project.yml`). In assenza di Mac la CI GitHub fa la build.
