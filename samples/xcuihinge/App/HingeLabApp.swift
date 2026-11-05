import SwiftUI

@main
struct HingeLabApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var hSize

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 12) {
                Text("width \(Int(proxy.size.width))")
                    .accessibilityIdentifier("width")
                Text(hSize == .regular ? "regular" : "compact")
                    .accessibilityIdentifier("sizeClass")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
