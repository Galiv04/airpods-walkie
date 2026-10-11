import SwiftUI

@main
struct AirPodsWalkieApp: App {
    @StateObject private var model = WalkieModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .preferredColorScheme(.dark)
        }
    }
}
