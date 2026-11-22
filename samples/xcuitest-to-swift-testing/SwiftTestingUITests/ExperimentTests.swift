import Testing
import XCUIAutomation

// The tests in this file fail on purpose. Select them with -only-testing.
extension UITests {
    /// The second test taps an element that does not exist.
    @MainActor
    struct TapMissingTests {
        static var counter = 0

        @Test func test1First() {
            let app = launchApp()
            defer { log("st.tapMissing.1 cleanup"); app.terminate() }
            Self.counter += 1
            log("st.tapMissing.1 counter=\(Self.counter)")
        }

        @Test func test2TapMissing() {
            let app = launchApp()
            defer { log("st.tapMissing.2 cleanup state=\(app.state.rawValue)"); app.terminate() }
            Self.counter += 1
            log("st.tapMissing.2 counter=\(Self.counter) before tap")
            app.buttons["missing"].tap()
            log("st.tapMissing.2 after tap")
        }

        @Test func test3Third() {
            let app = launchApp()
            defer { log("st.tapMissing.3 cleanup"); app.terminate() }
            Self.counter += 1
            log("st.tapMissing.3 counter=\(Self.counter)")
        }
    }

    /// The second test only waits for a missing element and checks the result.
    @MainActor
    struct WaitMissingExpectTests {
        static var counter = 0

        @Test func test1First() {
            let app = launchApp()
            defer { app.terminate() }
            Self.counter += 1
            log("st.waitExpect.1 counter=\(Self.counter)")
        }

        @Test func test2WaitMissing() {
            let app = launchApp()
            defer { log("st.waitExpect.2 cleanup"); app.terminate() }
            Self.counter += 1
            log("st.waitExpect.2 counter=\(Self.counter) before wait")
            #expect(app.buttons["missing"].waitForExistence(timeout: 2))
            log("st.waitExpect.2 after expect")
        }

        @Test func test3Third() {
            let app = launchApp()
            defer { app.terminate() }
            Self.counter += 1
            log("st.waitExpect.3 counter=\(Self.counter)")
        }
    }

    @MainActor
    struct WaitMissingRequireTests {
        static var counter = 0

        @Test func test1First() {
            let app = launchApp()
            defer { app.terminate() }
            Self.counter += 1
            log("st.waitRequire.1 counter=\(Self.counter)")
        }

        @Test func test2WaitMissing() throws {
            let app = launchApp()
            defer { log("st.waitRequire.2 cleanup"); app.terminate() }
            Self.counter += 1
            log("st.waitRequire.2 counter=\(Self.counter) before wait")
            try #require(app.buttons["missing"].waitForExistence(timeout: 2))
            log("st.waitRequire.2 after require")
        }

        @Test func test3Third() {
            let app = launchApp()
            defer { app.terminate() }
            Self.counter += 1
            log("st.waitRequire.3 counter=\(Self.counter)")
        }
    }

    /// Launches right after terminate(), 20 times, with and without waiting for the app to stop.
    @MainActor
    struct RelaunchTests {
        @Test func relaunchWithoutWait() {
            let app = XCUIApplication()
            for i in 1...20 {
                app.launch()
                app.terminate()
                log("st.relaunchNoWait \(i) state=\(app.state.rawValue)")
            }
        }

        @Test func relaunchWithWait() {
            let app = XCUIApplication()
            for i in 1...20 {
                app.launch()
                app.terminate()
                #expect(app.wait(for: .notRunning, timeout: 10))
                log("st.relaunchWait \(i) state=\(app.state.rawValue)")
            }
        }
    }

    /// Same as TapMissingTests, but nothing terminates the app. The third test checks
    /// whether the app that the first test launched is still running after the runner restarted.
    @MainActor
    struct TapMissingNoCleanupTests {
        @Test func test1Launch() {
            let app = launchApp()
            log("st.noCleanup.1 launched state=\(app.state.rawValue)")
        }

        @Test func test2TapMissing() {
            let app = XCUIApplication()
            log("st.noCleanup.2 state=\(app.state.rawValue) before tap")
            app.buttons["missing"].tap()
        }

        @Test func test3CheckState() {
            let app = XCUIApplication()
            log("st.noCleanup.3 state=\(app.state.rawValue) (4 = runningForeground, 1 = notRunning)")
        }
    }
}
