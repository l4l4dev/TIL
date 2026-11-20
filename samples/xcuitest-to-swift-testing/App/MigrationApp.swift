import SwiftUI

@main
struct MigrationApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

struct ContentView: View {
    @State private var count = 0

    var body: some View {
        VStack(spacing: 24) {
            Text("Count: \(count)").accessibilityIdentifier("label")
            Button("Increment") { count += 1 }.accessibilityIdentifier("button")
        }
    }
}
