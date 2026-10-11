# Architettura

```
mic AirPods (HFP) → voice processing (AEC/NS/AGC) → tap AVAudioEngine → converter → PCM Int16 16kHz mono
   → [gate: PTT / latch / VOX] → MCSession.send(.unreliable) ──► altro iPhone → AVAudioPlayerNode → AirPods
```

## Scelte
- **Trasporto: MultipeerConnectivity.** Peer‑to‑peer, cifrato (`encryptionPreference .required`), zero server, funziona offline/in aereo. Limite: portata ~30–100 m (Bluetooth/Wi‑Fi diretto), non adatto a due moto distanti. Per distanze maggiori vedi ROADMAP (trasporto internet via WebRTC/LiveKit).
- **Pairing**: codice "stanza" nel discoveryInfo + contesto invito; ognuno annuncia e cerca, invita solo chi ha nome minore (evita inviti incrociati).
- **Audio**: sessione `.playAndRecord` + `.voiceChat` + `.allowBluetooth` (AirPods usano HFP, 16 kHz mono: qualità da telefonata, ma è l'unico modo di usare il mic AirPods). `setVoiceProcessingEnabled(true)` per AEC e soppressione rumore. PCM grezzo 32 KB/s: banda irrilevante, nessun codec (latenza minima). Pacchetti ~20 ms, invio `unreliable` (come UDP), buffer di riproduzione limitato a ~250 ms con scarto oltre soglia per non accumulare latenza.
- **Background**: `UIBackgroundModes=audio` + schermo mantenuto acceso; `MPRemoteCommandCenter` intercetta play/pausa AirPods per toggle parla. In background Multipeer non può cercare nuovi peer: avviare e collegare con app in primo piano, poi si può bloccare lo schermo.
- **Isolamento voce**: pulsante che apre il selettore di sistema "Modalità microfono" (Voice Isolation).
- **Distribuzione**: IPA non firmato da GitHub Actions; la firma avviene lato utente (SideStore/AltStore) – nessun certificato/secret nel repo.
