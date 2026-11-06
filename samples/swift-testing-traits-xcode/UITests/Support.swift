import Foundation
import XCUIAutomation

/// Appends a line with the wall clock time to /tmp/traits-xcode.log and prints it.
/// The file is needed because xcodebuild does not show the output of tests
/// that run on cloned simulators.
func log(_ label: String) {
    let line = String(format: "%.2f", Date().timeIntervalSince1970)
        + " \(label) main=\(Thread.isMainThread) pid=\(ProcessInfo.processInfo.processIdentifier)\n"
    if let file = fopen("/tmp/traits-xcode.log", "a") { fputs(line, file); fclose(file) }
    print("LAB " + line, terminator: "")
}

@MainActor
func launchAndWait(_ label: String) async throws {
    log("\(label) start")
    let app = XCUIApplication()
    app.launch()
    log("\(label) launched")
    try await Task.sleep(for: .seconds(5))
    log("\(label) end")
}
