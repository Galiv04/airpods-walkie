# Installazione (senza App Store)

## 1. Ottenere l'IPA
La CI (`Build IPA`) compila ad ogni push su `main` e pubblica `AirPodsWalkie.ipa` nella release **latest**:
`https://github.com/Galiv04/airpods-walkie/releases/tag/latest`

## 2. Installarlo (scegli)
| Metodo | Costo | Validità | Note |
|---|---|---|---|
| **SideStore** (consigliato) | gratis | 7 giorni, rinnovo automatico via app | Setup iniziale con un computer una tantum, poi tutto da iPhone |
| **AltStore** | gratis | 7 giorni | Serve AltServer su Mac/PC in rete locale per rinnovare |
| **Sideloadly** | gratis | 7 giorni | Cavo + PC/Mac, rifare ogni settimana |
| **TestFlight** | $99/anno (Apple Developer) | 90 giorni per build | Il più comodo; richiede firma in CI (secrets certificato/profilo) – vedi ROADMAP |

Passi (SideStore/AltStore): scarica l'IPA sull'iPhone → apri con SideStore/AltStore → accedi con Apple ID → installa. Ripeti per l'iPhone di Claudia (può usare il proprio Apple ID). Poi: Impostazioni › Generali › VPN e gestione dispositivi › autorizza lo sviluppatore. Attiva Modalità sviluppatore se richiesto (iOS 16+).

## 3. Primo uso
1. Collega gli AirPods a ciascun iPhone. 2. Apri Walkie su entrambi, stesso codice stanza. 3. Concedi microfono e rete locale. 4. Avvia. 5. Appena compare "Collegato", puoi bloccare lo schermo.
