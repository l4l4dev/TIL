---
title: 'Two write paths racing in a save that never overwrites external edits, and how a sequence number stops it'
description: 'My app treats Markdown files in a user folder as the source of truth and does not overwrite changes made in other editors (compare-and-save). Then the autosave after typing and the final write on quit started overtaking each other. Here is how a sequence number checked just before the write fixed it, and what still remains.'
lang: en
translationKey: compare-and-save-two-write-paths
publishDate: 2026-10-01
tags: ['Swift', 'macOS', 'Design']
draft: false
---

I build [FirnPlanner](https://firnplanner.l4l4.dev/), a daily planner for macOS, as a personal project. It treats Markdown files in a folder the user chooses as the source of truth. There is one file per day, and users also open the same files in other editors.

So saving follows one rule: if the file changed outside the app, do not overwrite it. The save that keeps this rule ran into a race between two write paths. The conclusion is that I check a sequence number just before the write, and a stale request returns without writing.

## Write only when the file is as I last saw it

Saving is compare-and-save. The app holds the text that it last knew to be in sync with the disk (call it the baseline). On save, it reads the file. If the content equals the baseline, it writes. If not, it writes nothing, because the only way they differ is that someone outside the app wrote the file, and writing would silently erase that edit.

The read, the compare and the write happen inside one call with no suspension point. If they were separate calls, an outside edit could slip in between the read and the write. The comments in the code give this reason.

That is why the `save` function stays synchronous instead of async. The comments give two reasons.

- `applicationShouldTerminate` must finish writing before it returns. Making save async would need a round trip where the app postpones quitting and replies later.
- An await between the check and the write would create a suspension point, and the comparison would lose its meaning.

The `load` function is async, so that it does not block the main thread at launch.

## With two paths, an old write can land last

There are two save paths.

- The autosave that runs a moment after typing stops. Its file I/O runs off the main thread.
- The final write on quit, on switching dates, on leaving a page and on switching the storage folder. It runs synchronously on the main actor.

Writes to the same file are already queued one at a time by a per-file lock. That was not enough. The autosave cuts out the text to write and then waits for its turn at the lock. If a newer final write finishes while it waits, the old content gets its turn afterwards and overwrites the newer one.

Normally compare-and-save rejects the old request. The case where it does not is when the edit has returned to its original form before the final write. Say the disk holds `A`, and after typing a request to write `B` starts waiting. The user then undoes back to `A` and quits, and the final write writes `A`. The disk is still `A`, so the waiting old request passes its comparison (is it still `A`?) and `B` lands. The screen shows `A`, and the file holds `B`. A comment in the code describes this case.

The separate file that holds placement information (task start times) has no comparison at all. For it, only the ordering prevents a late old write.

![Autosave B waits while the final save writes A. Without tickets, old B overwrites A. With tickets, the stale request is superseded and disk remains A.](/TIL/images/save-order-en.svg)

## Take a sequence number when cutting out the text, compare it just before writing

I stopped it with a sequence number (a ticket).

- Take the number at the same place where the text to write is cut out. If it is taken later, an earlier request would hold newer content, and the overtaking could not be told apart.
- Inside the lock, which is just before the write, check whether a larger number has already entered its write. If so, return without writing.
- A check after the write is too late, because the old content is already on the disk.

Both paths take numbers from the same ledger, so an older request can no longer write after a newer one has written. That is the only direction the numbers protect. The other order is covered under the limits below.

I wrote a small example that extracts only the mechanism and ran it (Swift 6 mode, not the real code).

```swift
import Foundation

enum Outcome: Sendable, Equatable {
    case wrote
    case skipped(currentOnDisk: String?)
    case superseded
}

struct Ticket: Sendable {
    let key: String
    let sequence: UInt64
}

/// ファイル 1 つ分の保存先と、通し番号の台帳。
final class Store: @unchecked Sendable {
    private let lock = NSLock()
    private var disk: String?
    private var nextSequence: UInt64 = 0
    private var lastClaimed: UInt64 = 0

    init(disk: String?) { self.disk = disk }

    var onDisk: String? { lock.withLock { disk } }

    /// 書く内容を切り出すのと同じ場所で呼ぶ。
    func ticket() -> Ticket {
        lock.withLock {
            nextSequence += 1
            return Ticket(key: "day", sequence: nextSequence)
        }
    }

    /// 読む -> 比べる -> 書く を、中断点のない 1 回の同期呼び出しにする。
    /// ticket を渡すと、より新しい番号が先に書き込みへ入っていた場合は書かない。
    func saveIfCurrent(_ text: String, ticket: Ticket?, isCurrent: (String?) -> Bool) -> Outcome {
        lock.withLock {
            if let ticket {
                if lastClaimed > ticket.sequence { return .superseded }
                lastClaimed = ticket.sequence
            }
            let current = disk
            guard isCurrent(current) else { return .skipped(currentOnDisk: current) }
            disk = text
            return .wrote
        }
    }
}
```

It runs the overtaking scenario with and without the numbers.

```swift
func run(label: String, useTickets: Bool) async {
    let store = Store(disk: "A")

    // 1. 打鍵が止まった。"B" を切り出して、メインの外で書く順番を待つ。
    let asyncTicket = useTickets ? store.ticket() : nil
    let background = Task.detached { () -> Outcome in
        try? await Task.sleep(for: .milliseconds(100)) // 順番待ちの代わり
        return store.saveIfCurrent("B", ticket: asyncTicket) { $0 == "A" }
    }

    // 2. その間にユーザーが "A" に戻し、アプリを終了する。書き切りは同期で走る。
    try? await Task.sleep(for: .milliseconds(20))
    let syncTicket = useTickets ? store.ticket() : nil
    let flush = store.saveIfCurrent("A", ticket: syncTicket) { $0 == "A" }

    let late = await background.value
    print("[\(label)] flush=\(flush) late=\(late) disk=\(store.onDisk ?? "nil") (screen=A)")
}
```

The output is below.

```text
[no ticket] flush=wrote late=wrote disk=B (screen=A)
[ticket   ] flush=wrote late=superseded disk=A (screen=A)
```

Without the numbers, the late `B` is written and the file disagrees with the screen. With them, the late request returns as `superseded` and the disk stays `A`. The `Task.sleep` in the example stands in for waiting for the lock.

## Two kinds of skipping, and an overtaken write touches nothing

A save has three results.

- `wrote`: it passed the check and wrote.
- `skipped`: the check failed and nothing was written. The disk differed from the baseline, meaning it changed outside.
- `superseded`: a newer request had already entered its write, so this one did not write.

`skipped` and `superseded` mean different things, so the cleanup differs. With `skipped`, the result carries the disk content used in the check back to the caller. A comment in the code says that reading again would open a gap in which another write could slip in after the check. The baseline is reset from that content, and the screen tells the user that the file changed outside. The edits on screen are not thrown away.

With `superseded`, nothing is touched, neither the baseline nor the screen. The newer request has already reset them. Touching them here would misread the situation as an outside change and wrongly show the notice.

Generations decide the order in which the baseline is updated. Results of async writes do not necessarily arrive in the order the saves started. Updating the baseline in arrival order lets an old result roll back a newer one. Applying a result only when its generation is newer avoids that. The division is this: the sequence number decides whether to write, and the generation decides how far the baseline has advanced.

## The wait has a limit, and only writes inside the process are covered

The final write waits for the lock on the main thread. If the storage sits on a network and never answers, a waiting app that is trying to quit would hang. So the wait has a limit (5 seconds by default). Past it, the write is abandoned with an error and goes down the same path as "could not save". On quit, the user can choose to quit without saving.

The limits are clear.

- Neither the sequence number nor the lock can order anything except writes inside the same process. Conflicts with external editors belong to compare-and-save.
- Even compare-and-save is two separate operations on the file system between the read and the write. If an external editor saves in that gap, its save is overwritten. File locks or `NSFileCoordinator` could close it, but both only work if the other app follows the same mechanism.
- The sequence number only stops an older request from writing after a newer one. If the older request finishes writing first, the newer request still compares against the baseline it captured, which is now stale, so it can be skipped by the comparison. The minimal example in this post has no way to tell the app's own earlier write apart from an outside change. Loosening the comparison to let it through would defeat the purpose of protecting outside changes.
- The comparison only checks whether the disk equals the baseline. If the disk happens to have returned to the same content as the baseline, it passes.

What this defense is meant to remove is the long window between loading a file and saving it, while a person is editing. That window is gone. The small gap between the read and the write remains.

## With two write paths, decide the order when you cut out the content

What I would take to another app is this.

- For a file that can change outside, write only when it is as you last saw it. Make read, compare and write one call with no suspension point, and for that reason keep the save synchronous.
- With two write paths, queueing by a per-file lock is not enough. Take a sequence number where the content is cut out, and just before writing check whether a newer number has already gone in.
- Return the reason for not writing separately. Whether the file changed outside or a newer request overtook this one calls for opposite cleanup.
- Put a limit on the wait and treat passing it as a failure. Write down what the defense does not cover.

Judging the overtaking just before the write was the part that mattered most.
