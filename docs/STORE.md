# Pubblicazione su App Store: ricerca e passi

## Concorrenti già presenti (ottobre 2026, ricerca web; non verificati sull'app)
- **Talky** – walkie-talkie senza internet via Multipeer, compatibile AirPods: stesso approccio del nostro link vicino.
- **Mini Walkie Talkie** (lancio 22/05/2026) – passa tra Bluetooth/Wi‑Fi vicino e internet (WebRTC), audio cifrato end-to-end: **il più vicino a Walkie**.
- **Crew Comms** – per set/eventi, AirPods + Wi‑Fi locale, PTT a bassa latenza.
- **Zello**, Two Way, WaveTalk, Voxer, Zello Work – PTT via internet/canali, orientati a team.
- Apple *Walkie-Talkie* (watchOS): richiede internet/FaceTime; segnalata come rimossa in watchOS 27 beta.
- Hardware per moto (Sena, Cardo): intercom Bluetooth dedicati.

**Conclusione**: il mercato non è vuoto, ma Walkie ha una nicchia: pensato per ambienti rumorosi (moto/aereo), AirPods ANC, **offline + internet con passaggio automatico**, cifratura E2E, tasto AirPods, VOX con guanti. Per differenziarsi bene servono: Opus a basso bitrate, qualità voce curata, uso hands‑free affidabile in background, UX da moto (pulsanti grandi, Siri/Shortcuts, CarPlay non necessario).

## Cosa serve per pubblicare
1. **Apple Developer Program** ($99/anno).
2. Icona, screenshot, privacy policy (l'app non raccoglie dati; il relay vede solo byte cifrati e hash di stanza), descrizioni IT/EN.
3. Firma e upload da CI (certificato distribuzione, profilo, API key App Store Connect in GitHub Secrets) → TestFlight → review.
4. Attenzione review: uso del microfono in background (`UIBackgroundModes=audio`) va giustificato; stringhe di permesso chiare.
5. Valutare di sostituire il relay personale con uno scalabile (costi) o P2P WebRTC con STUN/TURN.

Passo intermedio consigliato: TestFlight (anche solo per noi due) prima di decidere per lo store pubblico.
