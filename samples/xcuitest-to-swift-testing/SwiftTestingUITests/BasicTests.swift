import Foundation
import Testing
import XCUIAutomation

// Tests that should pass.
extension UITests {
    @MainActor
    struct BasicTests {
        @Test func labelStartsAtZero() throws {
            let app = launchApp()
            defer { app.terminate() }
            #expect(app.staticTexts["label"].label == "Count: 0")
        }

        @Test func tapIncrementsLabel() throws {
            let app = launchApp()
            defer { app.terminate() }
            app.buttons["button"].tap()
            try #require(app.staticTexts["Count: 1"].waitForExistence(timeout: 5))
        }

        @Test func attachesScreenshot() {
            let app = launchApp()
            defer { app.terminate() }
            Attachment.record(XCUIScreen.main.screenshot().pngRepresentation, named: "x.png")
        }
    }

    // Runs only when RUN_GATED is set (xcodebuild ... with TEST_RUNNER_RUN_GATED=1).
    @MainActor
    @Suite(.enabled(if: ProcessInfo.processInfo.environment["RUN_GATED"] != nil))
    struct GatedTests {
        @Test func runsOnlyWhenGated() {
            let app = launchApp()
            defer { app.terminate() }
            #expect(app.buttons["button"].exists)
        }
    }

    // Launches the app three times in a row. Should pass.
    @MainActor
    struct ProbeTests {
        @Test func probeA() async throws { try await probe("st.probeA") }
        @Test func probeB() async throws { try await probe("st.probeB") }
        @Test func probeC() async throws { try await probe("st.probeC") }
    }
}

extension UnserializedUITests {
    // Same as ProbeTests, under a parent without `.serialized`.
    @MainActor
    struct ProbeTests {
        @Test func probeA() async throws { try await probe("st.unser.probeA") }
        @Test func probeB() async throws { try await probe("st.unser.probeB") }
        @Test func probeC() async throws { try await probe("st.unser.probeC") }
    }
}

@MainActor
func probe(_ name: String) async throws {
    log("\(name) start")
    let app = launchApp()
    defer { app.terminate(); log("\(name) end") }
    try await Task.sleep(for: .seconds(3))
}
