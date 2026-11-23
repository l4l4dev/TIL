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

    /// Writes only if the generation read at the start is still current.
    public static func gated(
        store: GuardedKeyStore, log: Log, afterCheck: (@Sendable () async -> Void)? = nil
    ) async {
        let generation = store.currentGeneration
        log("job: started with generation \(generation)")
        _ = await slowCheck()
        log("job: slow check returned, Task.isCancelled = \(Task.isCancelled)")
        await afterCheck?()
        let wrote = store.write("secret-key", ifGeneration: generation)
        log(wrote ? "job: wrote the key" : "job: generation changed, did not write")
    }
}
