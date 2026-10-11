import ActivityKit
import AppIntents
import Foundation

/// Live Activity (schermata di blocco + Dynamic Island). File compilato sia nell'app sia nel widget.
/// Nessun App Group: tutto lo stato viaggia in `ContentState` (funziona anche con il sideload gratuito).
@available(iOS 16.1, *)
struct RogerAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// "waiting", "linked", "talking", "remote", "echo"
        var phase: String
        var partner: String
        var viaInternet: Bool
        /// Inizio della fase attuale (per il cronometro disegnato dal sistema).
        var since: Date
    }

    var myName: String
}

/// Ponte verso il modello dell'app: l'intent gira nel processo dell'app, ma il file è compilato anche nel widget.
enum RogerBridge {
    @MainActor static var toggleTalk: (() -> Void)?
}

/// Pulsante "Parla / Chiudi" nella Dynamic Island espansa e sulla schermata di blocco (iOS 17+).
@available(iOS 17.0, *)
struct ToggleTalkIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Parla / chiudi"
    static var description = IntentDescription("Apre o chiude la trasmissione di Roger.")

    init() {}

    func perform() async throws -> some IntentResult {
        await MainActor.run { RogerBridge.toggleTalk?() }
        return .result()
    }
}
