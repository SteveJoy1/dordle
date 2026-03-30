import SwiftUI

@main
struct DordleApp: App {
    var body: some Scene {
        WindowGroup {
            GameView()
                .preferredColorScheme(nil)
        }
    }
}
