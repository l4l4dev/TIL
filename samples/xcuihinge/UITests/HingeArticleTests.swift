import XCTest

final class HingeArticleTests: XCTestCase {
    @MainActor
    func testOpenFlat() throws {
        let app = XCUIApplication()
        app.launch()

        let hinge = try XCTUnwrap(XCUIDevice.shared.hinge)
        hinge.angle = .pi // 平らに開く

        let sizeClass = app.staticTexts["sizeClass"]
        XCTAssertTrue(sizeClass.wait(for: \.label, toEqual: "regular", timeout: 5))
    }
}
