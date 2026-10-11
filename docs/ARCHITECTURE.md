# Architettura

```
mic AirPods (HFP) → voice processing (AEC/NS/AGC) → tap AVAudioEngine → converter → PCM Int16 24kHz mono
   → [gate: PTT / latch / VOX] → Multipeer (.unreliable)  se vicino
                               → WebSocket relay (ChaChaPoly E2E) altrimenti ──► altro iPhone → pre-roll 80ms → AVAudioPlayerNode → AirPods
```

## Scelte
- **Trasporto: MultipeerConnectivity.** Peer‑to‑peer, cifrato (`encryptionPreference .required`), zero server, funziona offline/in aereo. Limite: portata ~30–100 m (Bluetooth/Wi‑Fi diretto), non adatto a due moto distanti. Per distanze maggiori vedi ROADMAP (trasporto internet via WebRTC/LiveKit).
- **Pairing**: codice "stanza" nel discoveryInfo + contesto invito; ognuno annuncia e cerca, invita solo chi ha nome minore (evita inviti incrociati).
- **Audio**: sessione `.playAndRecord` + `.voiceChat` + `.allowBluetooth` (AirPods usano HFP, 16 kHz mono: qualità da telefonata, ma è l'unico modo di usare il mic AirPods). `setVoiceProcessingEnabled(true)` per AEC e soppressione rumore. PCM grezzo 32 KB/s: banda irrilevante, nessun codec (latenza minima). Pacchetti ~20 ms, invio `unreliable` (come UDP), buffer di riproduzione limitato a ~250 ms con scarto oltre soglia per non accumulare latenza.
- **Background**: `UIBackgroundModes=audio` + schermo mantenuto acceso; `MPRemoteCommandCenter` intercetta play/pausa AirPods per toggle parla. In background Multipeer non può cercare nuovi peer: avviare e collegare con app in primo piano, poi si può bloccare lo schermo.
- **Isolamento voce**: pulsante che apre il selettore di sistema "Modalità microfono" (Voice Isolation).
- **Distribuzione**: IPA non firmato da GitHub Actions; la firma avviene lato utente (SideStore/AltStore) – nessun certificato/secret nel repo.

## Aggiornamenti v0.2
- **Trasporto internet**: `RelayTransport` (URLSessionWebSocketTask, nessuna dipendenza) verso `relay/` (Cloudflare Worker + Durable Object per stanza, oppure Node). Scelto un relay WebSocket invece di WebRTC/LiveKit: zero dipendenze e server banale; compromesso = latenza leggermente maggiore e niente P2P. Cifratura E2E con chiave derivata dal codice stanza (`Wire.swift`, CryptoKit). Modo Auto: vicino se connesso, altrimenti internet (un solo canale alla volta per non duplicare l'audio).
- **Qualità**: wire a 24 kHz (sfrutta super‑wideband quando disponibile). Limite fisico: in HFP il link AirPods è 16 kHz mono sia in ingresso sia in uscita; l'opzione sperimentale iOS 26 `bluetoothHighQualityRecording` migliora solo la cattura, è documentata come compatibile solo con mode `.default` (quindi senza voice processing) e segnalata con problemi (latenza maggiore, nessun audio in alcuni stack). Default = `.voiceChat` + voice processing: voce più pulita e link più robusto. L'opzione è un toggle sperimentale.
- **Robustezza**: pre‑roll di ~80 ms a inizio frase, tetto a ~300 ms di coda (scarta), reset dopo 200 ms di silenzio; riconnessione relay con backoff; ping WebSocket ogni 20 s.
