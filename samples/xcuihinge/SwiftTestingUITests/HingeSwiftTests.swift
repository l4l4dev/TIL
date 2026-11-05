import Testing
import XCUIAutomation

@MainActor
struct HingeSwiftTests {
    @Test func openFlatShowsRegularWidth() throws {
        let app = XCUIApplication()
        app.launch()

        let hinge = try #require(XCUIDevice.shared.hinge)
        hinge.angle = .pi

        let sizeClass = app.staticTexts["sizeClass"]
        #expect(sizeClass.wait(for: \.label, toEqual: "regular", timeout: 5))
    }
}
