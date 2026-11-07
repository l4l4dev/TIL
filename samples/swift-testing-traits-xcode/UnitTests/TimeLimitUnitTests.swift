import Testing
import Foundation

struct TimeLimitUnitTests {
    @Test(.timeLimit(.minutes(1))) func sleepsPastLimit() async throws {
        log("unit.sleep start")
        defer { log("unit.sleep end cancelled=\(Task.isCancelled)") }
        try await Task.sleep(for: .seconds(90))
    }

    @Test(.timeLimit(.minutes(1))) func blocksThread() throws {
        log("unit.block start")
        Thread.sleep(forTimeInterval: 90)
        log("unit.block end ")
    }

    @Test func quick() async throws {
        log("unit.quick start")
        try await Task.sleep(for: .seconds(1))
        log("unit.quick end")
    }
}
