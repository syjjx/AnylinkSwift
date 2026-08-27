import SwiftUI

@main
struct AnyLinkApp: App {
    @StateObject private var manager = ConnectionManager(service: StubConnectionService())

    var body: some Scene {
        WindowGroup {
            MainWindow()
                .environmentObject(manager)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 820, height: 600)
    }
}
