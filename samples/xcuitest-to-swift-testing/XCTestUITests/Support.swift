import Foundation
import XCTest

/// Appends a line with the wall clock time and the runner pid to /tmp/xcuitest-migration.log
/// and prints it. The file is needed because xcodebuild does not show the output of tests
/// that run on cloned simulators.
func log(_ label: String) {
    let line = String(format: "%.2f", Date().timeIntervalSince1970)
        + " \(label) pid=\(ProcessInfo.processInfo.processIdentifier)\n"
    if let file = fopen("/tmp/xcuitest-migration.log", "a") { fputs(line, file); fclose(file) }
    print("LAB " + line, terminator: "")
}

@MainActor
func launchApp() -> XCUIApplication {
    let app = XCUIApplication()
    app.launch()
    return app
}
