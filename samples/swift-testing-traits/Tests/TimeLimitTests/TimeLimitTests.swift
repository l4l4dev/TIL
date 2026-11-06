import Foundation
import Testing
import TraitsLab

// Sleeps 90 seconds with a 1-minute limit.
@Test(.timeLimit(.minutes(1))) func sleepsPastLimit() async throws {
    probe("tl.past start")
    do {
        try await Task.sleep(for: .seconds(90))
    } catch {
        probe("tl.past caught \(type(of: error)) cancelled=\(Task.isCancelled)")
        throw error
    }
    probe("tl.past end")
}

// The suite limit applies to each test, not to the suite as a whole.
@Suite(.serialized, .timeLimit(.minutes(1))) struct SuiteLimitPerTest {
    @Test func first() async throws { try await work("tl.suite.first", seconds: 40) }
    @Test func second() async throws { try await work("tl.suite.second", seconds: 40) }
}

// Suite 1 minute, test 3 minutes.
@Suite(.timeLimit(.minutes(1))) struct SuiteShorter {
    @Test(.timeLimit(.minutes(3))) func sleeps90() async throws {
        try await work("tl.suiteShorter", seconds: 90)
    }
}

// Suite 3 minutes, test 1 minute.
@Suite(.timeLimit(.minutes(3))) struct TestShorter {
    @Test(.timeLimit(.minutes(1))) func sleeps90() async throws {
        try await work("tl.testShorter", seconds: 90)
    }
}

// Each argument gets its own limit.
@Test(.serialized, .timeLimit(.minutes(1)), arguments: [1, 2])
func perCase(n: Int) async throws {
    try await work("tl.case.\(n)", seconds: 40)
}

// Blocks the thread instead of awaiting, so cancellation cannot stop it.
@Test(.timeLimit(.minutes(1))) func blocksThread() {
    probe("tl.block start")
    Thread.sleep(forTimeInterval: 90)
    probe("tl.block end cancelled=\(Task.isCancelled)")
}

// .minutes(0) compiles. `.seconds(30)` does not:
// "'seconds' is unavailable: Time limit must be specified in minutes"
@Test(.timeLimit(.minutes(0))) func zeroMinutes() async throws {
    try await Task.sleep(for: .seconds(3))
}
