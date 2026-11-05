import XCTest

final class HingeSweepTests: XCTestCase {
    @MainActor
    func testSweep() throws {
        let app = XCUIApplication()
        app.launch()
        let hinge = try XCTUnwrap(XCUIDevice.shared.hinge)
        for degrees in stride(from: 0.0, through: 180.0, by: 15.0) + [90.0, 90.0, 200.0, -10.0] {
            hinge.angle = degrees * .pi / 180
            sleep(1)
            print(String(format: "SWEEP set %6.1f -> read %8.4f rad (%6.2f deg) | %@ | %@",
                         degrees, hinge.angle, hinge.angle * 180 / .pi,
                         app.staticTexts["width"].label, app.staticTexts["sizeClass"].label))
        }
    }

    @MainActor
    func testHingeIsNilWithoutHinge() {
        print("NILCHECK hinge:", String(describing: XCUIDevice.shared.hinge))
    }
}
