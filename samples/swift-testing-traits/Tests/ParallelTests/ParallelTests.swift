import Synchronization
import Testing
import TraitsLab

// Each test reads the counter, yields, then writes back value + 1.
// When tests overlap, one test's write can overwrite another's.
final class Counter: Sendable {
    private let value = Mutex(0)
    func read() -> Int { value.withLock { $0 } }
    func write(_ newValue: Int) { value.withLock { $0 = newValue } }
}

func bump(_ counter: Counter, label: String) async {
    for _ in 0..<1000 {
        let value = counter.read()
        await Task.yield()
        counter.write(value + 1)
    }
    probe("\(label) counter=\(counter.read())")
}

let parallelCounter = Counter()
let serialCounter = Counter()

@Suite struct ParallelByDefault {
    @Test func a() async throws { try await work("parallel.a"); await bump(parallelCounter, label: "parallel.a") }
    @Test func b() async throws { try await work("parallel.b"); await bump(parallelCounter, label: "parallel.b") }
    @Test func c() async throws { try await work("parallel.c"); await bump(parallelCounter, label: "parallel.c") }
}

@Suite(.serialized) struct Serialized {
    @Test func a() async throws { try await work("serial.a"); await bump(serialCounter, label: "serial.a") }
    @Test func b() async throws { try await work("serial.b"); await bump(serialCounter, label: "serial.b") }
    @Test func c() async throws { try await work("serial.c"); await bump(serialCounter, label: "serial.c") }
}

@Suite struct Parameterized {
    @Test(arguments: 1...3) func byDefault(n: Int) async throws {
        try await work("param.default.\(n)")
    }

    @Test(.serialized, arguments: 1...3) func serialized(n: Int) async throws {
        try await work("param.serial.\(n)")
    }
}

@Suite(.serialized) struct Outer {
    @Test func outerTest() async throws { try await work("outer.test") }

    @Suite struct Inner {
        @Test func x() async throws { try await work("outer.inner.x") }
        @Test func y() async throws { try await work("outer.inner.y") }
    }
}
