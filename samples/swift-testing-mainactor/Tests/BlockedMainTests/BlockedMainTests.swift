import Foundation
import Testing
import MainActorLab

@Suite struct BlockedMain {
    /// Waits on a stream that never sends a value and never finishes.
    @Test(.timeLimit(.minutes(1))) @MainActor func waitsOnSilentStream() async {
        let (stream, continuation) = AsyncStream<Int>.makeStream()
        probe("silentStream start")
        for await _ in stream {}
        probe("silentStream loop ended cancelled=\(Task.isCancelled)")
        continuation.finish()
    }

    /// Blocks the main thread for 90 seconds.
    @Test(.timeLimit(.minutes(1))) @MainActor func blocksMainThread() async {
        probe("blocksMain start")
        blockThread(seconds: 90)
        probe("blocksMain end")
    }

    /// A MainActor test that needs only 1 second.
    @Test @MainActor func shortOnMain() async throws {
        probe("shortOnMain start")
        try await Task.sleep(for: .seconds(1))
        probe("shortOnMain end")
    }

    /// A test without MainActor that needs only 1 second.
    @Test func shortOffMain() async throws {
        probe("shortOffMain start")
        try await Task.sleep(for: .seconds(1))
        probe("shortOffMain end")
    }
}
