import Foundation
import Testing
import MainActorLab

/// Number of busy MainActor tests that run next to the waiting tests. Set with LOAD=<n> (0...16).
let load = Int(ProcessInfo.processInfo.environment["LOAD"] ?? "0") ?? 0
/// How long each busy test holds the main thread before it yields (ms). Set with CHUNK=<ms>.
let chunk = Int(ProcessInfo.processInfo.environment["CHUNK"] ?? "50") ?? 50

/// Each busy test holds the main thread for `chunk` ms, then yields, for about 4 seconds.
@Suite @MainActor struct Busy {
    @Test(arguments: 0..<16) func busy(_ index: Int) async {
        guard index < load else { return }
        let end = ContinuousClock.now + .seconds(4)
        while ContinuousClock.now < end {
            spin(milliseconds: chunk)
            await Task.yield()
        }
    }
}

/// Waits five times for a value that the producer sends 300 ms after it starts,
/// with a custom 1-second timeout, and prints how late each value arrived.
func measure(_ label: String, producerOnMain: Bool,
             isolation: isolated (any Actor)? = #isolation) async {
    try? await Task.sleep(for: .milliseconds(500)) // let the busy tests start
    var delays: [Int] = []
    var timeouts = 0
    for _ in 0..<5 {
        let (stream, continuation) = AsyncStream<Int>.makeStream()
        if producerOnMain {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
                continuation.yield(1)
            }
        } else {
            Task.detached {
                try? await Task.sleep(for: .milliseconds(300))
                continuation.yield(1)
            }
        }
        // The custom timeout: a timer finishes the stream after 1 second.
        Task.detached {
            try? await Task.sleep(for: .seconds(1))
            continuation.finish()
        }
        let start = ContinuousClock.now
        var received = false
        for await _ in stream {
            received = true
            break
        }
        let waited = (ContinuousClock.now - start) / .milliseconds(1)
        if received { delays.append(Int(waited) - 300) } else { timeouts += 1 }
    }
    let list = delays.map(String.init).joined(separator: ",")
    probe("RESULT \(label) load=\(load) chunk=\(chunk)ms delay(ms)=[\(list)] timeouts=\(timeouts)/5")
}

@Suite struct Waiters {
    @Test @MainActor func consumerOnMainProducerOnMain() async {
        await measure("consumer=main producer=main", producerOnMain: true)
    }

    @Test @MainActor func consumerOnMainProducerOff() async {
        await measure("consumer=main producer=off ", producerOnMain: false)
    }

    @Test func consumerOffProducerOff() async {
        await measure("consumer=off  producer=off ", producerOnMain: false)
    }
}
