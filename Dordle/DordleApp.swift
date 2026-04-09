import SwiftUI

@main
struct DordleApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                GameView()
                    .tabItem {
                        Label("Dordle", systemImage: "rectangle.split.2x1")
                    }
                WordleGameView()
                    .tabItem {
                        Label("Wordle", systemImage: "square")
                    }
            }
            .preferredColorScheme(nil)
        }
    }
}
