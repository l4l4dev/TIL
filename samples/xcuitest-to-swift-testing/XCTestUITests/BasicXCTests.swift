import XCTest

// Tests that should pass.
@MainActor
final class BasicXCTests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = launchApp()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    func testLabelStartsAtZero() {
        XCTAssertEqual(app.staticTexts["label"].label, "Count: 0")
    }

    func testTapIncrementsLabel() {
        app.buttons["button"].tap()
        XCTAssertTrue(app.staticTexts["Count: 1"].waitForExistence(timeout: 5))
    }

    func testAttachesScreenshot() {
        let attachment = XCTAttachment(data: XCUIScreen.main.screenshot().pngRepresentation,
                                       uniformTypeIdentifier: "public.png")
        attachment.name = "x.png"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

// Runs only when RUN_GATED is set (xcodebuild ... with TEST_RUNNER_RUN_GATED=1).
@MainActor
final class GatedXCTests: XCTestCase {
    override func setUp() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["RUN_GATED"] != nil,
                          "RUN_GATED is not set")
        continueAfterFailure = false
    }

    func testRunsOnlyWhenGated() {
        let app = launchApp()
        defer { app.terminate() }
        XCTAssertTrue(app.buttons["button"].exists)
    }
}

// Launches the app three times in a row, waiting for it to stop each time. Should pass.
@MainActor
final class ProbeXCTests: XCTestCase {
    func testProbeA() async throws { try await probe("xct.probeA") }
    func testProbeB() async throws { try await probe("xct.probeB") }
    func testProbeC() async throws { try await probe("xct.probeC") }

    private func probe(_ name: String) async throws {
        log("\(name) start")
        let app = launchApp()
        try await Task.sleep(for: .seconds(3))
        app.terminate()
        log("\(name) end")
    }
}
