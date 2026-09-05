import SwiftUI

@main
struct PrismApp: App {
    @StateObject private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            PrismRootView()
                .environmentObject(container)
                .onAppear { container.initialize() }
        }
    }
}
