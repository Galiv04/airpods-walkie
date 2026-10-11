# Installare Walkie su iPhone senza Apple Developer Program

Guida pratica per installare l'app sul tuo iPhone e su quello di Claudia **gratis**, senza App Store.

## Prerequisiti
- iPhone con **iOS 16 o successivo** (verificato come requisito del progetto).
- Un **Apple ID** (gratuito). Meglio usarne uno dedicato/secondario: i tool di sideloading ti chiedono le credenziali per ottenere un certificato di sviluppo personale.
- Un computer (Mac o Windows) **solo per il setup iniziale** di SideStore.
- Gli AirPods già associati a ciascun iPhone.

## Il vincolo da conoscere
Senza account developer a pagamento ($99/anno) Apple firma le app con un certificato "personale" che **scade dopo 7 giorni**. Allo scadere l'app non si apre più finché non viene **ri-firmata** (basta un tap "Refresh" o avviene in automatico, vedi sotto: i dati e le impostazioni restano). Limiti dell'account gratuito: massimo 3 app sideloaded attive e 10 nuovi App ID a settimana (per noi è un'app sola).

## Opzioni per evitare/ridurre il rinnovo
| Opzione | Rinnovo | Costo | Valutazione |
|---|---|---|---|
| **SideStore** | Automatico/1 tap dal telefono | gratis | **Consigliata.** Setup una tantum con PC, poi tutto da iPhone |
| AltStore classico | Automatico ma serve AltServer acceso su Mac/PC in Wi‑Fi | gratis | Più scomodo (computer sempre acceso) |
| Sideloadly | Manuale con cavo ogni 7 giorni | gratis | Solo per prove |
| **TestFlight** | 90 giorni per build | **$99/anno** | L'unico modo "ufficiale" senza rinnovo settimanale |
| TrollStore | Nessuno (permanente) | gratis | **Non utilizzabile**: funziona solo su iOS 14–16.6.1 e 17.0; da 17.0.1 in poi mai supportato |
| Marketplace alternativi (AltStore PAL…) | — | — | Solo nell'UE |

Non esiste un modo gratuito e ufficiale per evitare del tutto la ri-firma: con SideStore la riduci a una cosa automatica o a un tap.

## Procedura con SideStore (consigliata)
Fai questi passi **una volta per ogni iPhone** (ognuno con il proprio Apple ID, oppure lo stesso). La guida ufficiale aggiornata è su <https://docs.sidestore.io/docs/installation/install> e prevale su quanto scritto qui se differiscono (l'installer cambia spesso).

1. **Installa SideStore** seguendo la guida ufficiale (installer su PC/Mac come *iloader*, collegando l'iPhone via cavo). Durante il setup:
   - attiva **Modalità sviluppatore**: Impostazioni › Privacy e sicurezza › Modalità sviluppatore (riavvio richiesto);
   - installa **LocalDevVPN** (VPN locale sul telefono, non instrada traffico verso internet): serve a SideStore per rinnovare le app senza computer;
   - autorizza il profilo: Impostazioni › Generali › VPN e gestione dispositivi › tocca il tuo Apple ID › Autorizza.
2. **Scarica l'IPA di Walkie** dal telefono: <https://github.com/Galiv04/airpods-walkie/releases/tag/latest> (file `AirPodsWalkie.ipa`).
3. **Apri l'IPA con SideStore** (tasto Condividi › SideStore) oppure in SideStore tab *My Apps* › **+** › scegli il file. Inserisci l'Apple ID se richiesto e attendi l'installazione.
4. Apri **Walkie**, concedi **Microfono** e **Rete locale**.

### Rinnovo (ogni 7 giorni)
- Con **LocalDevVPN attiva**, SideStore può rinnovare in background; se vedi che l'app sta per scadere: apri SideStore › *My Apps* › tocca il contatore "**7 DAYS**" o **Refresh All** (circa 10–30 secondi, serve internet). Le impostazioni dell'app restano.
- Abitudine pratica: un tap di refresh la domenica sera, prima di un viaggio. Non rinnovare mentre sei in volo senza internet: fallo prima di partire.
- Se l'app scade comunque: riapri SideStore, fai Refresh, riparte (non serve reinstallare).

## Aggiornare Walkie a una nuova versione
Scarica il nuovo `AirPodsWalkie.ipa` dalla release e installalo con SideStore sopra la versione esistente (stesso bundle ID: dati e impostazioni restano).

## Se in futuro vuoi la strada senza rinnovi: TestFlight
Serve l'Apple Developer Program ($99/anno). Con quello: firma automatica in CI, distribuzione via TestFlight (build valide 90 giorni, rinnovo = nuova build automatica), installazione con un link. È nella [roadmap](ROADMAP.md) e diventa anche il primo passo per un'eventuale pubblicazione sullo store ([STORE.md](STORE.md)).

## Problemi comuni
- *"Impossibile verificare l'app"*: autorizza il profilo (passo 1, ultimo punto).
- *L'app si chiude subito dopo 7 giorni*: è scaduta, fai Refresh in SideStore.
- *Installazione fallita "maximum number of apps"*: rimuovi un'altra app sideloaded (limite 3).
- *Il microfono non va*: Impostazioni › Walkie › Microfono; AirPods collegati prima di avviare.

## Primo uso di Walkie
1. Collega gli AirPods a ciascun iPhone. 2. Apri Walkie su entrambi con lo **stesso codice stanza**. 3. Avvia. 4. Appena compare "Vicino: …" o "Collegato via internet", puoi bloccare lo schermo. Per l'uso via internet vedi [RELAY.md](RELAY.md).
