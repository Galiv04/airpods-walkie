# Architettura

```
mic AirPods (HFP) → voice processing (AEC/NS/AGC) → tap AVAudioEngine → converter → PCM Int16 24kHz mono
   → [gate: PTT / latch / VOX] → Multipeer (.unreliable)  se vicino
                               → WebSocket relay (ChaChaPoly E2E) altrimenti ──► altro iPhone → pre-roll 80ms → AVAudioPlayerNode → AirPods
```

## Scelte
- **Trasporto: MultipeerConnectivity.** Peer‑to‑peer, cifrato (`encryptionPreference .required`), zero server, funziona offline/in aereo. Limite: portata ~30–100 m (Bluetooth/Wi‑Fi diretto), non adatto a due moto distanti. Per distanze maggiori vedi ROADMAP (trasporto internet via WebRTC/LiveKit).
- **Pairing (v0.4)**: ogni installazione genera un **codice coppia** casuale di 10 caratteri (~50 bit). Uno dei due lo invia all'altro (link `roger://pair?code=…` o digitandolo): da quel momento hanno lo stesso codice. Dal codice derivano l'hash `roomId` (usato nel discovery Bluetooth e nell'URL del relay: il codice non viaggia mai in chiaro) e la chiave ChaCha20‑Poly1305. Il nome scelto dall'utente è il displayName Multipeer e viaggia nel messaggio `hello` via relay. Ognuno annuncia e cerca, invita solo chi ha nome minore (evita inviti incrociati).
- **Audio**: sessione `.playAndRecord` + `.voiceChat` + `.allowBluetooth` (AirPods usano HFP, 16 kHz mono: qualità da telefonata, ma è l'unico modo di usare il mic AirPods). `setVoiceProcessingEnabled(true)` per AEC e soppressione rumore. PCM grezzo 32 KB/s: banda irrilevante, nessun codec (latenza minima). Pacchetti ~20 ms, invio `unreliable` (come UDP), buffer di riproduzione limitato a ~250 ms con scarto oltre soglia per non accumulare latenza.
- **Background**: `UIBackgroundModes=audio` + schermo mantenuto acceso; `MPRemoteCommandCenter` intercetta play/pausa AirPods per toggle parla. In background Multipeer non può cercare nuovi peer: avviare e collegare con app in primo piano, poi si può bloccare lo schermo.
- **Isolamento voce**: dal Centro di Controllo (Modalità microfono). Il pulsante in app che apriva il selettore di sistema è stato rimosso: lasciava lo schermo sfocato/bloccato.
- **Parlato (v0.4)**: un solo modo sul pulsante: tocco breve = accendi/spegni trasmissione, pressione lunga (>0,4 s) = trasmette finché tieni. «Mani libere» (VOX) è un'opzione nelle impostazioni.
- **Distribuzione**: IPA non firmato da GitHub Actions; la firma avviene lato utente (SideStore/AltStore) – nessun certificato/secret nel repo.

## Aggiornamenti v0.2
- **Trasporto internet**: `RelayTransport` (URLSessionWebSocketTask, nessuna dipendenza) verso `relay/` (Cloudflare Worker + Durable Object per stanza, oppure Node). Scelto un relay WebSocket invece di WebRTC/LiveKit: zero dipendenze e server banale; compromesso = latenza leggermente maggiore e niente P2P. Cifratura E2E con chiave derivata dal codice stanza (`Wire.swift`, CryptoKit). Modo Auto: vicino se connesso, altrimenti internet (un solo canale alla volta per non duplicare l'audio).
- **Qualità**: wire a 24 kHz (sfrutta super‑wideband quando disponibile). Limite fisico: in HFP il link AirPods è 16 kHz mono sia in ingresso sia in uscita; l'opzione sperimentale iOS 26 `bluetoothHighQualityRecording` migliora solo la cattura, è documentata come compatibile solo con mode `.default` (quindi senza voice processing) e segnalata con problemi (latenza maggiore, nessun audio in alcuni stack). Default = `.voiceChat` + voice processing: voce più pulita e link più robusto. L'opzione è un toggle sperimentale.
- **Robustezza**: pre‑roll di ~80 ms a inizio frase, tetto a ~300 ms di coda (scarta), reset dopo 200 ms di silenzio; riconnessione relay con backoff; ping WebSocket ogni 20 s.

## Aggiornamenti v0.5
- **Compressione ADPCM** (`ADPCM.swift`): IMA ADPCM 4 bit/campione, ~4× meno dati (12 KB/s a 24 kHz), SNR ~32 dB su voce sintetica (verificato con test). Scelto al posto di Opus: zero dipendenze, latenza zero (nessun frame di codec), CPU trascurabile, ogni pacchetto contiene lo stato del codec → la perdita di un pacchetto non si propaga. Wire tipo 4; il tipo 1 (PCM) resta decodificabile.
- **Siri/Comandi rapidi** (`Intents.swift`, AppIntents iOS 16, nessuna estensione): «Avvia Roger», «Spegni Roger». Lingua di sviluppo del progetto = italiano, perché le frasi di Siri sono in italiano.
- **Livello voce remota**: calcolato in riproduzione, anima gli anelli quando parla l'altro.

## Aggiornamenti v0.6
- **Buffer anti-jitter nuovo** (`JitterBuffer.swift` + `AVAudioSourceNode`): la voce in arrivo va in un buffer circolare letto direttamente dal motore audio (prima: un `scheduleBuffer` per pacchetto, fragile con la rete a raffiche). Ispirato a Chromium remoting / Mumble / NetEQ in forma semplice:
  - pre-roll a inizio frase: 60 ms da vicino, 120 ms via internet;
  - underrun a metà frase → dissolvenza, silenzio e ri-riempimento del pre-roll (non audio a scatti); il pre-roll cresce di 20 ms a ogni underrun (max 160/300 ms) e cala di 10 ms ogni 3 frasi pulite;
  - overrun (raffica dopo uno stallo TCP del relay) → si scartano i campioni più vecchi tornando al target, la latenza non si accumula;
  - fine frase (messaggio «ha smesso di parlare») o 150 ms senza pacchetti → suona il resto senza aspettare.
  Testato con unit test (`JitterBufferTests`). Non fatti (per ora): riordino con numeri di sequenza (TCP è ordinato; Multipeer di rado riordina), time-stretching tipo NetEQ, QUIC/UDP al posto del WebSocket.
- **Live Activity / Dynamic Island** (`RogerWidget/`, `Shared/RogerActivity.swift`, `LiveActivityController.swift`): estensione widget con `ActivityConfiguration`. Scelte per il sideload gratuito: nessun App Group (AltStore/SideStore rinominano i gruppi), nessuna push (solo aggiornamenti locali), solo `NSSupportsLiveActivities` in Info.plist. Avvio solo con app in primo piano (limite iOS), aggiornamenti solo ai cambi di stato, cronometro disegnato dal sistema (`Text(timerInterval:)`). Pulsante «Parla/Chiudi» con `LiveActivityIntent` (iOS 17+, gira nel processo dell'app; serve il telefono sbloccato). **Rischio noto**: alcuni sviluppatori riportano che gli aggiornamenti in background non arrivano se l'app è viva solo grazie all'audio (forum Apple 717701): da verificare sul telefono.
- **PushToTalk di Apple** scartato: richiede entitlement e push, non disponibili con account gratuito.

## Aggiornamenti v0.7
- **Live Activity / Dynamic Island rimossa** (beneficio basso rispetto alla complessità e all'App ID extra nel sideload). Codice e istruzioni per riattivarla in `archive/live-activity/` (non compilato).

## Aggiornamenti v0.8 – eco in vivavoce: half-duplex
Problema (test reale senza cuffie, modalità «tocca e resta aperto»): eco/feedback della voce dell'altro. Causa: trasmissione contemporanea dai due lati → l'altoparlante di ciascuno rientra nel proprio microfono; l'AEC di Apple (voice processing, come FaceTime) riduce ma in vivavoce ad alto volume lascia eco residua.
Soluzione (come walkie-talkie veri e Zello), sopra all'AEC che resta attiva:
- **mentre trasmetti l'altoparlante tace** (`JitterBuffer.muted`: l'uscita è silenziosa ma il buffer avanza, così non si accumula ritardo; i beep locali restano udibili);
- **controllo del turno**: mentre l'altro parla e per 0,6 s dopo (coda del buffer + beep «roger» + riverbero) non si apre la trasmissione; tocco/AirPod → segnale di «occupato» (vibrazione + doppio bip grave + pulsante che oscilla); il pulsante diventa «ASCOLTA» azzurro;
- **mani libere**: non si attivano con la voce/beep dell'altro che esce dall'altoparlante (stessa finestra);
- collisione (entrambi premono insieme): entrambi gli altoparlanti tacciono → nessun anello di feedback possibile.
Il test eco è escluso (lì la voce che torna è la propria).
