import SwiftUI

@main
struct TraitsXcodeApp: App {
    var body: some Scene {
        WindowGroup {
            Text("ready").accessibilityIdentifier("status")
        }
    }
}
