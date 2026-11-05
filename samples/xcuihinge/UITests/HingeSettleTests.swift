import XCTest

final class HingeSettleTests: XCTestCase {
    /// Polls until the label stops changing for 2 s (max 10 s).
    @MainActor
    func settledLabel(_ app: XCUIApplication) -> String {
        var last = app.staticTexts["sizeClass"].label
        var stableSince = Date()
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            usleep(250_000)
            let now = app.staticTexts["sizeClass"].label
            if now != last { last = now; stableSince = Date() }
            else if Date().timeIntervalSince(stableSince) >= 2 { break }
        }
        return last + " " + app.staticTexts["width"].label
    }

    @MainActor
    func testSettledSweep() throws {
        let app = XCUIApplication()
        app.launch()
        let hinge = try XCTUnwrap(XCUIDevice.shared.hinge)
        // upward from 0, then downward from 180, then approach 90 from both sides
        let plan: [Double] = [0, 30, 45, 60, 90, 120, 150, 165, 180,
                              165, 150, 120, 90, 60, 45, 30, 0,
                              90, 180, 90, 0, 90]
        for degrees in plan {
            hinge.angle = degrees * .pi / 180
            let label = settledLabel(app)
            print(String(format: "SETTLE set %5.1f -> read %6.2f deg | %@",
                         degrees, hinge.angle * 180 / .pi, label))
        }
    }
}
