import SwiftUI

@main
struct AnyLinkApp: App {
    var body: some Scene {
        WindowGroup {
            MainWindow()
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 820, height: 600)
    }
}
