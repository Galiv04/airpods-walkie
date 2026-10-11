import AppIntents

/// «Ehi Siri, avvia Roger» / «spegni Roger»: comodo col casco o i guanti.
@available(iOS 16.0, *)
struct StartRogerIntent: AppIntent {
    static var title: LocalizedStringResource = "Avvia Roger"
    static var description = IntentDescription("Accende il walkie-talkie e si collega all'altro telefono.")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        if let m = WalkieModel.shared, !m.isRunning { m.start() }
        return .result()
    }
}

@available(iOS 16.0, *)
struct StopRogerIntent: AppIntent {
    static var title: LocalizedStringResource = "Spegni Roger"
    static var description = IntentDescription("Spegne il walkie-talkie.")

    @MainActor
    func perform() async throws -> some IntentResult {
        if let m = WalkieModel.shared, m.isRunning { m.stop() }
        return .result()
    }
}

@available(iOS 16.0, *)
struct RogerShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: StartRogerIntent(), phrases: [
            "Avvia \(.applicationName)",
            "Accendi \(.applicationName)",
            "Apri \(.applicationName) e collegati",
        ])
        AppShortcut(intent: StopRogerIntent(), phrases: [
            "Spegni \(.applicationName)",
            "Ferma \(.applicationName)",
        ])
    }
}
