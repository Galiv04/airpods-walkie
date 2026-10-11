import ActivityKit
import UIKit

/// Gestisce la Live Activity di Roger (Dynamic Island / schermata di blocco).
/// - si avvia solo con l'app in primo piano (limite di iOS);
/// - si aggiorna solo quando cambia lo stato (mai per pacchetto audio);
/// - nessun App Group: lo stato è tutto in `ContentState`.
@available(iOS 16.2, *)
@MainActor
final class LiveActivityController {
    private var activity: Activity<RogerAttributes>?
    private var last: RogerAttributes.ContentState?

    init() {
        // Attività rimaste da un'esecuzione precedente (es. app chiusa dal sistema).
        for a in Activity<RogerAttributes>.activities {
            Task { await a.end(nil, dismissalPolicy: .immediate) }
        }
    }

    func sync(running: Bool, state: RogerAttributes.ContentState, myName: String) {
        guard running else { end(); return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        if activity == nil {
            guard UIApplication.shared.applicationState == .active else { return }
            activity = try? Activity.request(attributes: RogerAttributes(myName: myName),
                                             content: ActivityContent(state: state, staleDate: nil),
                                             pushType: nil)
            last = state
            return
        }
        guard state != last, let a = activity else { return }
        last = state
        Task { await a.update(ActivityContent(state: state, staleDate: nil)) }
    }

    func end() {
        guard let a = activity else { return }
        activity = nil
        last = nil
        Task { await a.end(nil, dismissalPolicy: .immediate) }
    }
}
