# Ricerca (ottobre 2026)

Ricerca su GitHub (walkie‑talkie + MultipeerConnectivity / AVAudioEngine) e web: nessun progetto pubblico rilevante riusabile trovato (la ricerca GitHub via API ha restituito 0 risultati; il web solo guide generiche di sideloading).

Alternative note (non verificate in dettaglio): Zello, Walkie‑Talkie di Apple (watchOS/FaceTime, richiede internet), intercom Bluetooth da casco (Sena/Cardo, hardware dedicato). Questo progetto copre il caso AirPods + offline + zero costi.

Tecnologie valutate: MultipeerConnectivity (scelta MVP), WebRTC/LiveKit (futuro, per distanza), Nearby Interaction/UWB (non per audio), BLE GATT (banda troppo bassa per audio decente).
Da approfondire: ricerca più mirata di progetti open source (es. ricerca per "PushToTalk framework", Apple PushToTalk framework iOS 16 – richiede entitlement/server, non adatto a uso personale offline).

## Aggiornamento (v0.2)
- Sideloading: SideStore (rinnovo da telefono con LocalDevVPN), AltStore (serve AltServer), TrollStore (solo iOS ≤17.0, inutilizzabile su iOS recenti). Dettagli in INSTALL-SENZA-DEVELOPER.md. Fonte: docs.sidestore.io, guide terze parti (da verificare sul dispositivo).
- Qualità AirPods: iOS 26 `bluetoothHighQualityRecording` (WWDC25 sessione 251); issue note: livekit/client-sdk-react-native#467 (nessun audio / uscita HFP 16 kHz), thread forum su latenza più alta.
- Concorrenti sullo store: vedi docs/STORE.md (Talky, Mini Walkie Talkie, Crew Comms, Zello…).
