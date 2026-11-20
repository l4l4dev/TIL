import XCTest

// The tests in this file fail on purpose. Select them with -only-testing.

/// The second test taps an element that does not exist.
@MainActor
final class TapMissingXCTests: XCTestCase {
    static var counter = 0
    var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = launchApp()
    }

    override func tearDown() async throws {
        log("xct.tapMissing tearDown")
        app.terminate()
    }

    func test1First() {
        Self.counter += 1
        log("xct.tapMissing.1 counter=\(Self.counter)")
    }

    func test2TapMissing() {
        Self.counter += 1
        log("xct.tapMissing.2 counter=\(Self.counter) before tap")
        app.buttons["missing"].tap()
        log("xct.tapMissing.2 after tap")
    }

    func test3Third() {
        Self.counter += 1
        log("xct.tapMissing.3 counter=\(Self.counter)")
    }
}

/// The second test only waits for a missing element and asserts on the result.
@MainActor
final class WaitMissingXCTests: XCTestCase {
    static var counter = 0
    var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = launchApp()
    }

    override func tearDown() async throws {
        log("xct.waitMissing tearDown")
        app.terminate()
    }

    func test1First() {
        Self.counter += 1
        log("xct.waitMissing.1 counter=\(Self.counter)")
    }

    func test2WaitMissing() {
        Self.counter += 1
        log("xct.waitMissing.2 counter=\(Self.counter) before wait")
        XCTAssertTrue(app.buttons["missing"].waitForExistence(timeout: 2))
        log("xct.waitMissing.2 after assert")
    }

    func test3Third() {
        Self.counter += 1
        log("xct.waitMissing.3 counter=\(Self.counter)")
    }
}

/// Launches right after terminate(), 20 times, with and without waiting for the app to stop.
@MainActor
final class RelaunchXCTests: XCTestCase {
    func testRelaunchWithoutWait() {
        let app = XCUIApplication()
        for i in 1...20 {
            app.launch()
            app.terminate()
            log("xct.relaunchNoWait \(i) state=\(app.state.rawValue)")
        }
    }

    func testRelaunchWithWait() {
        let app = XCUIApplication()
        for i in 1...20 {
            app.launch()
            app.terminate()
            XCTAssertTrue(app.wait(for: .notRunning, timeout: 10))
            log("xct.relaunchWait \(i) state=\(app.state.rawValue)")
        }
    }
}

/// Same as TapMissingXCTests, but nothing terminates the app. The third test checks
/// whether the app that the first test launched is still running after the runner restarted.
@MainActor
final class TapMissingNoCleanupXCTests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
    }

    func test1Launch() {
        let app = launchApp()
        log("xct.noCleanup.1 launched state=\(app.state.rawValue)")
    }

    func test2TapMissing() {
        let app = XCUIApplication()
        log("xct.noCleanup.2 state=\(app.state.rawValue) before tap")
        app.buttons["missing"].tap()
    }

    func test3CheckState() {
        let app = XCUIApplication()
        log("xct.noCleanup.3 state=\(app.state.rawValue) (4 = runningForeground, 1 = notRunning)")
    }
}

/// Compares where `continueAfterFailure` is set. The tests run in alphabetical order.
/// TestA uses the default (true), TestB sets false in the test body, TestC only logs the pid.
@MainActor
final class ContinueAfterFailureXCTests: XCTestCase {
    func testA_defaultTrue() {
        log("xct.caf.A continueAfterFailure=\(continueAfterFailure) before tap")
        let app = launchApp()
        defer { app.terminate() }
        app.buttons["missing"].tap()
        log("xct.caf.A after tap")
    }

    func testB_falseInBody() {
        continueAfterFailure = false
        log("xct.caf.B continueAfterFailure=\(continueAfterFailure) before tap")
        let app = launchApp()
        defer { app.terminate() }
        app.buttons["missing"].tap()
        log("xct.caf.B after tap")
    }

    func testC_pid() {
        log("xct.caf.C")
    }
}

/// Finds what makes the runner restart after a failed tap. Each class has a failing test
/// and a second test that logs the pid. The app is launched and terminated in the test body.
@MainActor
final class RestartAsyncSetUpFalseXCTests: XCTestCase {
    override func setUp() async throws { continueAfterFailure = false }
    func test1Tap() { tapMissing("xct.restart.asyncSetUpFalse") }
    func test2Pid() { log("xct.restart.asyncSetUpFalse.2") }
}

@MainActor
final class RestartSyncSetUpFalseXCTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }
    func test1Tap() { tapMissing("xct.restart.syncSetUpFalse") }
    func test2Pid() { log("xct.restart.syncSetUpFalse.2") }
}

@MainActor
final class RestartAsyncSetUpDefaultXCTests: XCTestCase {
    override func setUp() async throws {}
    func test1Tap() { tapMissing("xct.restart.asyncSetUpDefault") }
    func test2Pid() { log("xct.restart.asyncSetUpDefault.2") }
}

@MainActor
final class RestartAsyncTearDownXCTests: XCTestCase {
    override func tearDown() async throws {}
    func test1Tap() { tapMissing("xct.restart.asyncTearDown") }
    func test2Pid() { log("xct.restart.asyncTearDown.2") }
}

@MainActor
private func tapMissing(_ name: String) {
    let app = launchApp()
    defer { app.terminate() }
    log("\(name) before tap")
    app.buttons["missing"].tap()
    log("\(name) after tap")
}
