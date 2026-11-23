---
title: 'Removing data right after cancelling a Task let the late-finishing work write the removed data back'
description: 'Cancelling a Task returns without waiting for the work to stop. When I removed a key file right after cancel, the work finished late and wrote the same key back. Waiting on task.value after cancel, or checking a generation under a lock before writing, kept the key removed.'
lang: en
translationKey: cancelled-task-writes-late
publishDate: 2026-11-23
tags: ['Swift', 'Concurrency']
draft: false
---

I build [FirnPlanner](https://firnplanner.l4l4.dev/), a macOS day planner, as a personal project, and I am developing sync that keeps data the same across devices. This sync has an operation that removes the key used to encrypt data from the device. Sometimes the key came back after it had been removed.

The key was written by a Task that had been cancelled just before the removal. The Task kept going to the end after it was cancelled and wrote the key where it had just been removed. I rebuilt the same sequence in a small package and checked which ways of writing it keep the key removed.

## The cancelled Task ran to the end and wrote the key

The job is "do a slow check, then write the key to a file". For the check, I wrapped an API that returns its result through a completion handler in `withCheckedContinuation`. It returns after 0.3 seconds and does not react to cancellation.

```swift
func slowCheck(delay: Double = 0.3) async -> Bool {
    await withCheckedContinuation { continuation in
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
            continuation.resume(returning: true)
        }
    }
}

static func unchecked(store: KeyStore, log: Log) async {
    log("job: slow check starts")
    _ = await slowCheck()
    log("job: slow check returned, Task.isCancelled = \(Task.isCancelled)")
    store.write("secret-key")
    log("job: wrote the key")
}
```

I start this job in a Task, cancel it after 50 milliseconds, and remove the key file right away.

```swift
let task = Task { await SaveJob.unchecked(store: store, log: log) }
try? await Task.sleep(for: .milliseconds(50))
task.cancel()
store.remove()
```

```
[+   1 ms] job: slow check starts
[+  51 ms] main: cancel(), then remove()
[+ 321 ms] job: slow check returned, Task.isCancelled = true
[+ 321 ms] job: wrote the key
[+ 321 ms] file after: "secret-key"
```

`cancel()` returned immediately. On the Task side, the only change was that `Task.isCancelled` became `true`. The check took its 0.3 seconds, and then the job wrote the key. The removed file was back with its old contents 270 milliseconds later.

## Checking isCancelled before writing still let the key come back when the removal landed between the check and the write

I changed the job to look at `Task.isCancelled` right before writing, and to skip the write when cancelled.

```swift
_ = await slowCheck()
guard !Task.isCancelled else {
    log("job: cancelled, not writing")
    return
}
store.write("secret-key")
```

With the same flow, the key did not come back.

```
[+   0 ms] job: slow check starts
[+  55 ms] main: cancel(), then remove()
[+ 320 ms] job: slow check returned, Task.isCancelled = true
[+ 320 ms] job: cancelled, not writing
[+ 320 ms] file after: (absent)
```

But the `guard` and `store.write` are separate lines. I built a sequence where cancel and the removal land after the `guard` passes and before the write. So that it does not depend on timing, the job waits for a signal from outside right after the `guard`.

```
[+   0 ms] job: slow check starts
[+ 320 ms] job: slow check returned, Task.isCancelled = false
[+ 321 ms] job: isCancelled was false, about to write
[+ 321 ms] main: job is between the check and the write; cancel(), then remove()
[+ 327 ms] job: wrote the key (Task.isCancelled = true now)
[+ 327 ms] file after: "secret-key"
```

The key came back. I have not measured how often this sequence happens in real code, where nothing waits for a signal. There is nothing between the `guard` and the write, so I expect it to be rare. Still, when the side that cancels and the side that writes run on different threads, I cannot say it never happens.

## Waiting on task.value after cancel kept the key removed

Back to the first job, the one that does not look at `Task.isCancelled`. After cancel, I waited for the job to finish with `await task.value`, and removed the key after that.

```swift
task.cancel()
await task.value
store.remove()
```

```
[+   1 ms] job: slow check starts
[+  54 ms] main: cancel(), await task.value
[+ 323 ms] job: slow check returned, Task.isCancelled = true
[+ 324 ms] job: wrote the key
[+ 324 ms] main: task finished after waiting 269 ms, now remove()
[+ 429 ms] file after: (absent)
```

The job did write the key, but the removal came after it, so the file stayed removed. The wait was 269 milliseconds. The removing side waits for as long as the check still has to run.

## Where waiting is not possible, I checked a generation under a lock before writing

Sometimes the removing side is a function that is not async and cannot use `await`. For that case, I gave the key store a generation number. The removing side takes a lock, advances the generation by one, and then removes the key. The writing side reads the generation before it creates the Task and hands it to the job. When it writes, it takes the same lock, checks that the generation has not changed, and then writes.

```swift
final class GuardedKeyStore: Sendable {
    private let store: KeyStore
    private let generation = Mutex(0)

    var currentGeneration: Int { generation.withLock { $0 } }

    func invalidateAndRemove() {
        generation.withLock { value in
            value += 1
            store.remove()
        }
    }

    func write(_ key: String, ifGeneration expected: Int) -> Bool {
        generation.withLock { value in
            guard value == expected else { return false }
            store.write(key)
            return true
        }
    }
}
```

The job does not look at `Task.isCancelled`. It decides by the generation it was given.

```swift
let generation = store.currentGeneration
let task = Task {
    await SaveJob.gated(store: store, generation: generation, log: log)
}
```

```swift
// SaveJob.gated
_ = await slowCheck()
let wrote = store.write("secret-key", ifGeneration: generation)
log(wrote ? "job: wrote the key" : "job: generation changed, did not write")
```

I tried it with the same sequence that brought the key back earlier. Cancel and the removal land after the check finishes, right before the write.

```
[+   0 ms] job: started with generation 0, Task.isCancelled = false
[+ 319 ms] job: slow check returned, Task.isCancelled = false
[+ 319 ms] main: job is about to write; cancel(), then invalidateAndRemove() (no await)
[+ 320 ms] job: generation changed, did not write
[+ 320 ms] file after: (absent)
```

The key did not come back. The generation check and the write are inside one lock, and the removal takes the same lock, so the removal cannot land between them.

## Reading the generation inside the Task let the key come back when the removal finished before the Task started running

The generation is read before the Task is created. At first I read it on the first line inside the Task, and the review of this post pointed out a sequence where that is too late. It is the sequence where cancel and the removal finish after the Task is created and before its body starts running. I built it by making the job wait for a signal at its very start.

```
[+   0 ms] main: job has not started yet; cancel(), then invalidateAndRemove() (no await)
[+   0 ms] job: started with generation 1, Task.isCancelled = true
[+ 319 ms] job: slow check returned, Task.isCancelled = true
[+ 320 ms] job: wrote the key
[+ 320 ms] file after: "secret-key"
```

The job read generation 1, the value after the removal advanced it. The generation at write time is also 1, so the check passed and the job wrote the key. In the same sequence, reading the generation before creating the Task kept the key removed.

```
[+   0 ms] main: read generation 0 before creating the task
[+   0 ms] main: job has not started yet; cancel(), then invalidateAndRemove() (no await)
[+   0 ms] job: started with generation 0, Task.isCancelled = true
[+ 319 ms] job: slow check returned, Task.isCancelled = true
[+ 319 ms] job: generation changed, did not write
[+ 319 ms] file after: (absent)
```

The job holds generation 0, from before the removal, so the write was refused.

## In FirnPlanner, I wait where waiting is possible and use a generation where it is not

FirnPlanner uses both.

The operation that erases sync data and the one that restarts sync are async. They now keep track of the cancelled work and wait for all of it to finish before removing the key. There can be more than one cancelled job, so they are chained in the order they were cancelled and awaited together.

The operation that removes the key while sync is unavailable removes it right away without waiting. For this one, I added the generation check where the key is written. The generation is read outside the Task, at the point where the work is requested, and handed to it.

## Summary

- `Task.cancel()` returns without waiting for the work to stop. A job sitting in a wait that does not react to cancellation ran to the end
- A file removed right after cancel was written back by the job that finished late
- Looking at `Task.isCancelled` right before writing kept the key removed in this flow. The key came back when the removal landed between the check and the write
- Waiting with `await task.value` after cancel, and removing after that, kept the key removed
- Where waiting is not possible, advancing a generation on removal and checking it under the same lock on write kept the key removed
- Read the generation before creating the Task. When it was read inside the Task and the removal finished before the Task started running, the job read the new generation and wrote the key

The package I used is in [samples/cancelled-task-writes-late](https://github.com/l4l4dev/TIL/tree/main/samples/cancelled-task-writes-late). `swift run cancel-demo` prints logs in the same order as shown here. The times change a little from run to run. I ran it three times, and whether the key came back was the same every time.

Environment: Xcode 27.3 beta 2 (27C5035i), Swift 6.4.4, macOS 27.3, run with `swift run`.
