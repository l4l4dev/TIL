import Foundation

public struct Outcome: Sendable {
    public let name: String
    public let fileContents: String?
    public var keyIsBack: Bool { fileContents != nil }
}

public enum Experiments {
    private static func finish(_ name: String, _ store: KeyStore, _ log: Log) -> Outcome {
        let contents = store.read()
        log("file after: \(contents.map { "\"\($0)\"" } ?? "(absent)")")
        store.cleanUp()
        return Outcome(name: name, fileContents: contents)
    }

    /// 1. Cancel, then remove right away.
    public static func cancelThenRemove(log: Log) async -> Outcome {
        let store = KeyStore.temporary()
        let task = Task { await SaveJob.unchecked(store: store, log: log) }
        try? await Task.sleep(for: .milliseconds(50))
        log("main: cancel(), then remove()")
        task.cancel()
        store.remove()
        await task.value
        return finish("1", store, log)
    }

    /// 2a. Same flow, but the job checks `Task.isCancelled` before writing.
    public static func checkedBeforeWrite(log: Log) async -> Outcome {
        let store = KeyStore.temporary()
        let task = Task { await SaveJob.checked(store: store, log: log) }
        try? await Task.sleep(for: .milliseconds(50))
        log("main: cancel(), then remove()")
        task.cancel()
        store.remove()
        await task.value
        return finish("2a", store, log)
    }

    /// 2b. Cancel and remove land between the check and the write, forced by a hook.
    public static func checkedButInterrupted(log: Log) async -> Outcome {
        let store = KeyStore.temporary()
        let reached = Gate()
        let proceed = Gate()
        let task = Task {
            await SaveJob.checked(store: store, log: log) {
                await reached.open()
                await proceed.wait()
            }
        }
        await reached.wait()
        log("main: job is between the check and the write; cancel(), then remove()")
        task.cancel()
        store.remove()
        await proceed.open()
        await task.value
        return finish("2b", store, log)
    }

    /// 3. Cancel, wait for the task to finish, then remove.
    public static func awaitThenRemove(log: Log) async -> Outcome {
        let store = KeyStore.temporary()
        let task = Task { await SaveJob.unchecked(store: store, log: log) }
        try? await Task.sleep(for: .milliseconds(50))
        log("main: cancel(), await task.value")
        let waitStart = ContinuousClock.now
        task.cancel()
        await task.value
        let waited = ContinuousClock.now - waitStart
        let ms = Int(waited.components.seconds * 1000 + waited.components.attoseconds / 1_000_000_000_000_000)
        log("main: task finished after waiting \(ms) ms, now remove()")
        store.remove()
        try? await Task.sleep(for: .milliseconds(100))
        return finish("3", store, log)
    }

    /// 4. Synchronous "invalidate and remove" with a generation gate, same interruption as 2b.
    public static func generationGate(log: Log) async -> Outcome {
        let store = KeyStore.temporary()
        let guarded = GuardedKeyStore(store: store)
        let reached = Gate()
        let proceed = Gate()
        let generation = guarded.currentGeneration
        let task = Task {
            await SaveJob.gated(store: guarded, generation: generation, log: log, afterCheck: {
                await reached.open()
                await proceed.wait()
            })
        }
        await reached.wait()
        log("main: job is about to write; cancel(), then invalidateAndRemove() (no await)")
        task.cancel()
        guarded.invalidateAndRemove()
        await proceed.open()
        await task.value
        return finish("4", store, log)
    }

    /// 5a. The removal lands before the job starts, and the job reads the generation itself.
    public static func generationReadInsideTask(log: Log) async -> Outcome {
        await removeBeforeJobStarts(name: "5a", captureBeforeTask: false, log: log)
    }

    /// 5b. Same ordering, but the generation is read before the task is created.
    public static func generationReadBeforeTask(log: Log) async -> Outcome {
        await removeBeforeJobStarts(name: "5b", captureBeforeTask: true, log: log)
    }

    private static func removeBeforeJobStarts(
        name: String, captureBeforeTask: Bool, log: Log
    ) async -> Outcome {
        let store = KeyStore.temporary()
        let guarded = GuardedKeyStore(store: store)
        let proceed = Gate()
        let generation: Int? = captureBeforeTask ? guarded.currentGeneration : nil
        if let generation { log("main: read generation \(generation) before creating the task") }
        let task = Task {
            await SaveJob.gated(store: guarded, generation: generation, log: log, beforeStart: {
                await proceed.wait()
            })
        }
        log("main: job has not started yet; cancel(), then invalidateAndRemove() (no await)")
        task.cancel()
        guarded.invalidateAndRemove()
        await proceed.open()
        await task.value
        return finish(name, store, log)
    }
}
