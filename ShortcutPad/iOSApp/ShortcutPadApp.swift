import SwiftUI

@main
struct ShortcutPadApp: App {
    @StateObject private var model = PadModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
        }
    }
}
