# Roger (AirPods Walkie)

Walkie-talkie iPhone ↔ iPhone pensato per **AirPods con cancellazione del rumore** in ambienti rumorosi (moto, aereo, cantiere). Uso personale, installazione fuori dall'App Store.

> Stato: **v0.8** – provata su due iPhone (funziona); CI con test automatici e screenshot UI dal simulatore. Vedi [docs/ROADMAP.md](docs/ROADMAP.md).

**Requisiti**: iPhone con **iOS 16+**, AirPods (meglio Pro/Max/4 con ANC), un Apple ID gratuito per l'installazione.

## Come funziona
- Ogni iPhone ha i suoi AirPods; il microfono AirPods (con voice processing: AEC + riduzione rumore) cattura la voce.
- L'audio (PCM 24 kHz mono) viaggia **direttamente tra i due iPhone** via MultipeerConnectivity (Bluetooth / Wi‑Fi peer‑to‑peer, ~30–100 m): niente internet, funziona in modalità aereo.
- **Oltre i 100 m** (auto diverse, case diverse): passa da un piccolo relay internet con audio cifrato end‑to‑end; modo **Auto/Vicino/Internet** ([docs/RELAY.md](docs/RELAY.md)).
- **Un solo pulsante**: tocca = parla, ritocca = chiudi; oppure tieni premuto e rilascia. Opzione **Mani libere** (attivazione a voce) nelle impostazioni.
- **Play/Pausa sugli AirPods** (stem/tasto) = parla / smetti, anche a schermo bloccato.
- **Codice coppia** unico generato dal telefono: lo invii all'altro con un link (`roger://pair?code=…`) e da quel momento i due telefoni si riconoscono e si collegano solo tra loro. Il codice è anche la chiave di cifratura.
- Beep di inizio/fine e «roger» quando l'altro chiude, vibrazione al tocco.
- **Half-duplex anti-eco** (come i walkie-talkie veri): si parla uno alla volta; mentre trasmetti il tuo altoparlante tace, mentre l'altro parla il pulsante diventa «Ascolta». Funziona anche in vivavoce senza cuffie.
- **Test eco**: prova microfono/AirPods/internet con un solo telefono (il relay ti rimanda la voce dopo 1,5 s).

## Installazione sui due iPhone (senza Apple Developer Program)
Guida completa passo‑passo: **[docs/INSTALL-SENZA-DEVELOPER.md](docs/INSTALL-SENZA-DEVELOPER.md)**.

In breve: scarica `AirPodsWalkie.ipa` dalla [release `latest`](https://github.com/Galiv04/airpods-walkie/releases/tag/latest) (compilato da GitHub Actions) e installalo con **SideStore** (Apple ID gratuito). La firma gratuita dura 7 giorni: con SideStore il rinnovo è un tap "Refresh" (o automatico con LocalDevVPN). L'unico modo per non rinnovare mai è l'Apple Developer Program a pagamento + TestFlight.

## Documentazione
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) – architettura e scelte tecniche
- [docs/INSTALL-SENZA-DEVELOPER.md](docs/INSTALL-SENZA-DEVELOPER.md) – installazione gratis, rinnovo settimanale
- [docs/RELAY.md](docs/RELAY.md) – relay internet (Cloudflare Workers) per lunga distanza
- [docs/STORE.md](docs/STORE.md) – concorrenti e passi per l'App Store
- [docs/RESEARCH.md](docs/RESEARCH.md) – ricerca su soluzioni esistenti
- [docs/ROADMAP.md](docs/ROADMAP.md) – cosa manca / prossimi passi
- [docs/TESTING.md](docs/TESTING.md) – come si verifica (test, screenshot, test eco)
- [CLAUDE.md](CLAUDE.md) – contesto per agenti AI che lavorano sul progetto

## Sviluppo
Richiede macOS+Xcode 15.3+ e [XcodeGen](https://github.com/yonaskolb/XcodeGen): `xcodegen generate && open AirPodsWalkie.xcodeproj`. Il `.xcodeproj` non è versionato (generato da `project.yml`). In assenza di Mac la CI GitHub fa la build.
