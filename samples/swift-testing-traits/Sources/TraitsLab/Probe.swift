import Foundation

private let origin = ContinuousClock.now

/// Prints a line with the elapsed time since the test process started
/// and the ID of the thread the caller is running on.
public func probe(_ label: String) {
    let elapsed = (ContinuousClock.now - origin) / .seconds(1)
    let thread = pthread_mach_thread_np(pthread_self())
    print(String(format: "LAB %7.2fs thread=%-6u %@", elapsed, thread, label))
}

/// Records the start, waits, and records the end.
public func work(_ label: String, seconds: Double = 1) async throws {
    probe("\(label) start")
    try await Task.sleep(for: .seconds(seconds))
    probe("\(label) end")
}
