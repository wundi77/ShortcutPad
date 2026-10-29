import SwiftUI

@main
struct ShortcutPadHelperApp: App {
    @StateObject private var controller = HelperController()

    var body: some Scene {
        WindowGroup("ShortcutPad Helper") {
            HelperView()
                .environmentObject(controller)
        }
    }
}
