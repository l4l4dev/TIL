import Dispatch
import Foundation
import Synchronization

/// A tiny store that keeps one key in a file.
public final class KeyStore: Sendable {
    public let url: URL

    public init(url: URL) { self.url = url }

    public static func temporary() -> KeyStore {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("cancel-lab-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return KeyStore(url: dir.appendingPathComponent("key.txt"))
    }

    public func write(_ key: String) {
        try? key.write(to: url, atomically: true, encoding: .utf8)
    }

    public func remove() {
        try? FileManager.default.removeItem(at: url)
    }

    public func read() -> String? {
        try? String(contentsOf: url, encoding: .utf8)
    }

    public func cleanUp() {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}

/// Prints timestamped lines, and also appends them to a file when a directory is given.
public final class Log: Sendable {
    private let start = ContinuousClock.now
    private let echo: Bool
    private let fileURL: URL?
    private let lock = Mutex(())

    public init(name: String, directory: URL? = nil, echo: Bool = true) {
        self.echo = echo
        if let directory {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            fileURL = directory.appendingPathComponent("\(name).log")
            try? Data().write(to: fileURL!)
        } else {
            fileURL = nil
        }
    }

    public func callAsFunction(_ message: String) {
        let elapsed = (ContinuousClock.now - start).components
        let ms = Int(elapsed.seconds * 1000 + elapsed.attoseconds / 1_000_000_000_000_000)
        let line = "[+\(String(format: "%4d", ms)) ms] \(message)\n"
        lock.withLock { _ in
            if echo { print(line, terminator: "") }
            if let fileURL, let handle = try? FileHandle(forWritingTo: fileURL) {
                handle.seekToEndOfFile()
                handle.write(Data(line.utf8))
                try? handle.close()
            }
        }
    }
}

/// A one-shot signal: `wait()` suspends until `open()` is called.
public actor Gate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    public init() {}

    public func open() {
        isOpen = true
        for waiter in waiters { waiter.resume() }
        waiters.removeAll()
    }

    public func wait() async {
        if isOpen { return }
        await withCheckedContinuation { waiters.append($0) }
    }
}

/// A completion-handler API wrapped in a continuation. It does not react to cancellation,
/// like many callback-based APIs (a network check, a permission prompt, a legacy SDK call).
func slowCheck(delay: Double = 0.3) async -> Bool {
    await withCheckedContinuation { continuation in
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
            continuation.resume(returning: true)
        }
    }
}

/// A store whose "invalidate and remove" and "write if still current" run under one lock.
public final class GuardedKeyStore: Sendable {
    private let store: KeyStore
    private let generation = Mutex(0)

    public init(store: KeyStore) { self.store = store }

    public var currentGeneration: Int { generation.withLock { $0 } }

    /// Synchronous: bumps the generation and removes the key atomically.
    public func invalidateAndRemove() {
        generation.withLock { value in
            value += 1
            store.remove()
        }
    }

    /// Writes only if no `invalidateAndRemove()` happened since `generation` was read.
    @discardableResult
    public func write(_ key: String, ifGeneration expected: Int) -> Bool {
        generation.withLock { value in
            guard value == expected else { return false }
            store.write(key)
            return true
        }
    }
}
