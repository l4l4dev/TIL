import Foundation
import Testing
import XCUIAutomation

// Cleanup in deinit. The first class compiles with a warning (see README),
// the second uses `isolated deinit`.
extension UITests {
    @MainActor
    final class DeinitTests {
        let app: XCUIApplication

        init() {
            app = launchApp()
        }

        deinit {
            log("st.deinit main=\(Thread.isMainThread)")
            app.terminate()
        }

        @Test func runsWithDeinitCleanup() {
            log("st.deinit.test")
            #expect(app.buttons["button"].exists)
        }
    }

    @MainActor
    final class IsolatedDeinitTests {
        let app: XCUIApplication

        init() {
            app = launchApp()
        }

        isolated deinit {
            log("st.isolatedDeinit main=\(Thread.isMainThread)")
            app.terminate()
        }

        @Test func runsWithIsolatedDeinitCleanup() {
            log("st.isolatedDeinit.test")
            #expect(app.buttons["button"].exists)
        }
    }
}
