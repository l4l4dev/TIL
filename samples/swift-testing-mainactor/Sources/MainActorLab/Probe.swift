import Foundation

private let origin = ContinuousClock.now

/// Prints a line with the elapsed time since the first call, the ID of the
/// thread the caller is running on, and whether it is the main thread.
public func probe(_ label: String) {
    let elapsed = (ContinuousClock.now - origin) / .seconds(1)
    let thread = pthread_mach_thread_np(pthread_self())
    let main = pthread_main_np() != 0 ? "yes" : "no "
    print(String(format: "LAB %7.2fs thread=%-6u main=%@ %@", elapsed, thread, main, label))
}

/// Keeps the current thread busy for the given time without suspending.
public func spin(milliseconds: Int) {
    let end = ContinuousClock.now + .milliseconds(milliseconds)
    var count = 0
    while ContinuousClock.now < end { count &+= 1 }
    _ = count
}

/// Blocks the current thread. Kept synchronous so async tests can call it.
public func blockThread(seconds: Double) {
    Thread.sleep(forTimeInterval: seconds)
}
