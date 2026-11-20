import Testing
import XCUIAutomation

/// Launches the app before each test and terminates it afterwards.
/// Attached to a suite, `isRecursive = true` makes it apply to every test inside.
/// A trait cannot hand a value to the test, so the tests create their own `XCUIApplication()`,
/// which refers to the same app.
struct AppScope: TestTrait, SuiteTrait, TestScoping {
    var isRecursive: Bool { true }

    func provideScope(for test: Test, testCase: Test.Case?,
                      performing function: @Sendable () async throws -> Void) async throws {
        // Called once for the suite (testCase == nil) and once per test case.
        guard testCase != nil else {
            try await function()
            return
        }
        log("st.trait \(test.name) setUp")
        let app = await MainActor.run { launchApp() }
        do {
            try await function()
        } catch {
            await MainActor.run { app.terminate() }
            throw error
        }
        await MainActor.run { app.terminate() }
        log("st.trait \(test.name) tearDown")
    }
}

extension UITests {
    @MainActor
    @Suite(AppScope())
    struct TraitScopedTests {
        @Test func labelStartsAtZero() {
            let app = XCUIApplication()
            log("st.trait.test state=\(app.state.rawValue)")
            #expect(app.staticTexts["label"].label == "Count: 0")
        }

        @Test func tapIncrementsLabel() {
            let app = XCUIApplication()
            app.buttons["button"].tap()
            #expect(app.staticTexts["Count: 1"].waitForExistence(timeout: 5))
        }
    }
}
