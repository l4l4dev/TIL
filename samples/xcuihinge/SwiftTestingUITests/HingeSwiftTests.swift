import Foundation
import Testing
import XCUIAutomation

@MainActor
struct HingeSwiftTests {
    @Test func openFlatShowsRegularWidth() async throws {
        let app = XCUIApplication()
        app.launch()

        let hinge = try #require(XCUIDevice.shared.hinge)
        hinge.angle = .pi
        try await Task.sleep(for: .seconds(1))

        print("SWIFT-TESTING angle", hinge.angle, app.staticTexts["width"].label, app.staticTexts["sizeClass"].label)
        #expect(app.staticTexts["sizeClass"].label == "regular")
    }
}
