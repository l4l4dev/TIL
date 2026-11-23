/// "Do a slow check, then save the key." Three versions of the same job.
public enum SaveJob {
    /// No cancellation handling at all.
    public static func unchecked(store: KeyStore, log: Log) async {
        log("job: slow check starts")
        _ = await slowCheck()
        log("job: slow check returned, Task.isCancelled = \(Task.isCancelled)")
        store.write("secret-key")
        log("job: wrote the key")
    }

    /// Looks at `Task.isCancelled` right before writing.
    /// `afterCheck` runs between the check and the write so a test can interleave there.
    public static func checked(
        store: KeyStore, log: Log, afterCheck: (@Sendable () async -> Void)? = nil
    ) async {
        log("job: slow check starts")
        _ = await slowCheck()
        log("job: slow check returned, Task.isCancelled = \(Task.isCancelled)")
        guard !Task.isCancelled else {
            log("job: cancelled, not writing")
            return
        }
        log("job: isCancelled was false, about to write")
        await afterCheck?()
        store.write("secret-key")
        log("job: wrote the key (Task.isCancelled = \(Task.isCancelled) now)")
    }

    /// Writes only if `generation` is still current.
    /// The caller reads the generation before it creates the task and passes it in.
    /// Passing `nil` makes the job read the generation itself, which is too late
    /// when the removal lands before the job starts (experiment 5a).
    /// `beforeStart` runs first so a test can hold the job before it does anything.
    public static func gated(
        store: GuardedKeyStore, generation captured: Int?, log: Log,
        beforeStart: (@Sendable () async -> Void)? = nil,
        afterCheck: (@Sendable () async -> Void)? = nil
    ) async {
        await beforeStart?()
        let generation = captured ?? store.currentGeneration
        log("job: started with generation \(generation), Task.isCancelled = \(Task.isCancelled)")
        _ = await slowCheck()
        log("job: slow check returned, Task.isCancelled = \(Task.isCancelled)")
        await afterCheck?()
        let wrote = store.write("secret-key", ifGeneration: generation)
        log(wrote ? "job: wrote the key" : "job: generation changed, did not write")
    }
}
