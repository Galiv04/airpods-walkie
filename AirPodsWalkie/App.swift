import SwiftUI

@main
struct AirPodsWalkieApp: App {
    @StateObject private var model = WalkieModel()
    @State private var pairedAlert = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .preferredColorScheme(.light)
                // Link ricevuto dall'altro telefono: roger://pair?code=XXXXXXXXXX
                .onOpenURL { url in
                    if url.host == "pair", model.joinPair(url.absoluteString) {
                        if model.isRunning { model.stop(); model.start() }
                        pairedAlert = true
                    }
                }
                .alert("Telefoni collegati ✓", isPresented: $pairedAlert) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text("Ora avete lo stesso codice coppia. Accendete Roger su entrambi.")
                }
                .onAppear {
                    if let d = UserDefaults.standard.string(forKey: "demo") { model.applyDemo(d) }
                }
        }
    }
}
