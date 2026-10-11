# Live Activity / Dynamic Island (archiviata)

Funzionalità sviluppata nella v0.6 e **rimossa nella v0.7** (decisione: poco beneficio rispetto alla complessità; costava anche un App ID in più nel sideload). Il codice qui **non è compilato**: è conservato per riprenderla in futuro. Ultimo commit in cui era attiva: `9bf677c` (build CI verde, IPA verificata con l'estensione dentro; mai provata su device).

## Contenuto
- `RogerWidget/RogerWidget.swift` – estensione widget: `ActivityConfiguration` (schermata di blocco + Dynamic Island compatta/espansa/minima), stile Roger, pulsante «Parla/Chiudi» (iOS 17+).
- `RogerActivity.swift` – `RogerAttributes` (stato in `ContentState`, nessun App Group), `RogerBridge`, `ToggleTalkIntent` (`LiveActivityIntent`, gira nel processo dell'app). Va compilato **sia nell'app sia nel widget** (era in `AirPodsWalkie/Shared/`).
- `LiveActivityController.swift` – avvio in primo piano, aggiornamenti solo ai cambi di stato, chiusura allo stop (target app).

## Come riattivarla
1. `git mv archive/live-activity/RogerWidget RogerWidget`; `mkdir AirPodsWalkie/Shared && git mv archive/live-activity/RogerActivity.swift AirPodsWalkie/Shared/`; `git mv archive/live-activity/LiveActivityController.swift AirPodsWalkie/`.
2. `project.yml`: nel target app aggiungere `dependencies: [- target: RogerWidget]` e in `info.properties` `NSSupportsLiveActivities: true`; aggiungere il target:
```yaml
  RogerWidget:
    type: app-extension
    platform: iOS
    deploymentTarget: "16.2"
    sources: [RogerWidget, AirPodsWalkie/Shared]
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.galiv04.airpodswalkie.widget
        GENERATE_INFOPLIST_FILE: NO
        SKIP_INSTALL: YES
        ASSETCATALOG_COMPILER_APPICON_NAME: ""
        ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME: ""
    info:
      path: RogerWidget/Info.plist
      properties:
        CFBundleDisplayName: Roger
        CFBundleShortVersionString: "$(MARKETING_VERSION)"
        CFBundleVersion: "$(CURRENT_PROJECT_VERSION)"
        NSExtension:
          NSExtensionPointIdentifier: com.apple.widgetkit-extension
```
3. `WalkieModel.swift`: `import ActivityKit`; aggiungere `didSet { if oldValue != X { syncLiveActivity() } }` a `isRunning`, `nearbyName`, `relayPeer`, `talking`, `remoteTalking`, `echoTest` (e `partnerName`); proprietà `private var liveActivity: AnyObject?`, `private var phaseSince = Date()`, `private var lastPhase = ""`; in fondo a `init()` e come metodi:
```swift
        if #available(iOS 16.2, *) { liveActivity = LiveActivityController() }
        RogerBridge.toggleTalk = { [weak self] in
            guard let self, self.isRunning, !self.handsFree else { return }
            self.setTalking(!self.talking)
        }
    }

    // MARK: Live Activity

    private var livePhase: String {
        if echoTest { return "echo" }
        if talking { return "talking" }
        if remoteTalking { return "remote" }
        return linked ? "linked" : "waiting"
    }

    private func syncLiveActivity() {
        guard !demo else { return }
        if #available(iOS 16.2, *), let c = liveActivity as? LiveActivityController {
            let phase = livePhase
            if phase != lastPhase { lastPhase = phase; phaseSince = Date() }
            let state = RogerAttributes.ContentState(phase: phase, partner: partnerName,
                                                     viaInternet: nearbyName == nil && relayPeer, since: phaseSince)
            c.sync(running: isRunning, state: state, myName: displayName)
        }
    }

```

## Note dalla ricerca (ottobre 2026)
- Funziona con Apple ID gratuito: nessun entitlement, solo `NSSupportsLiveActivities`; +1 App ID per l'estensione; iLoader ≥ 2.3.0; AltStore/SideStore rinominano gli App Group (per questo non li usa).
- Rischio: segnalazioni di aggiornamenti in background ignorati quando l'app è viva solo per l'audio (forum Apple 717701).
- I pulsanti funzionano solo a telefono sbloccato; avvio dell'attività solo con app in primo piano.
