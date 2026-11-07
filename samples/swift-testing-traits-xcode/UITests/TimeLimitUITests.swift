import Testing
import XCUIAutomation

@MainActor
struct TimeLimitUITests {
    // Waits with Task.sleep, which reacts to cancellation.
    @Test(.timeLimit(.minutes(1))) func sleepsPastLimit() async throws {
        log("ui.sleep start")
        XCUIApplication().launch()
        defer { log("ui.sleep end cancelled=\(Task.isCancelled)") }
        try await Task.sleep(for: .seconds(90))
    }

    // Waits with an XCUIElement wait for an element that never appears.
    @Test(.timeLimit(.minutes(1))) func waitsForMissingElement() async throws {
        log("ui.wait start")
        let app = XCUIApplication()
        app.launch()
        let found = app.staticTexts["never"].waitForExistence(timeout: 90)
        log("ui.wait end found=\(found) cancelled=\(Task.isCancelled)")
    }

    @Test func quick() async throws {
        log("ui.quick start")
        try await Task.sleep(for: .seconds(1))
        log("ui.quick end")
    }
}
