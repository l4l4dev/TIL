---
title: 'A per-file watcher goes quiet after an atomic replace, so I watch the whole folder with one FSEvents stream'
description: 'How a macOS app that treats a user-chosen folder of Markdown files as its source of truth notices outside changes. A per-file DispatchSource stopped reporting after an atomic replace, and a per-directory one missed in-place appends. The output of a small experiment, and the key points of watching the root with a single FSEvents stream.'
lang: en
translationKey: fsevents-watch-storage-folder
publishDate: 2026-10-01
tags: ['macOS', 'Swift', 'FSEvents']
draft: false
---

I build [FirnPlanner](https://firnplanner.l4l4.dev/), a daily planner for macOS, as a personal project. The Markdown files in a folder the user picks are the source of truth: each day plan and the inbox is a plain file under that folder. When an outside editor or a sync tool changes a file, the app has to read it again.

The part that notices those changes uses FSEvents. DispatchSource is the first thing most people reach for, and I do not use it. Here is why, as far as a small experiment let me confirm.

## A per-file DispatchSource stopped reporting after the first replace

The app saves with an atomic write: it writes a temporary file and then swaps it into place. According to the comment in the implementation, this is why DispatchSource is avoided. The first replace removes the inode being watched, and later writes never arrive.

I checked that in a separate script. For one file it sets up three watchers at the same time:

- a `DispatchSource.makeFileSystemObjectSource` on a descriptor opened on the file (per-file)
- the same kind of DispatchSource on the parent directory (per-directory)
- FSEvents on the directory, with `kFSEventStreamCreateFlagFileEvents`

The script then does an in-place append, three replaces with `write(to:atomically: true)`, and one more append, and counts the notifications after each step. For FSEvents it counts only events whose path is the file in question.

```text
1 append in place      : file-source=1 dir-source=0 fsevents(note.md)=1
2 atomic replace #1    : file-source=1 dir-source=2 fsevents(note.md)=2
3 atomic replace #2    : file-source=0 dir-source=2 fsevents(note.md)=2
4 atomic replace #3    : file-source=0 dir-source=2 fsevents(note.md)=2
5 append after replace : file-source=0 dir-source=0 fsevents(note.md)=1
```

I ran it three times on macOS 27.2 and got the same result each time. Three things can be read from it:

- The per-file DispatchSource got one notification for the first replace, then nothing for the later replaces or for the append after them. The descriptor is probably still attached to the old file, but I did not verify that the inode changed.
- The per-directory DispatchSource picked up the replaces but not the in-place append (`dir-source=0` on line 1).
- FSEvents kept reporting the append, all three replaces, and the append after them.

What the experiment shows is limited to the counts for these three kinds of operation. I did not look at the order in which particular sync tools write files.

## One atomic replace produces two notifications for the same file

The table shows something else too. A single atomic replace reached FSEvents as two notifications with the same file name. I think the creation of the temporary file and the swap are seen as separate events, though I did not confirm that.

For the reader of these notifications, both lead to the same reload. So the implementation merges equal notifications within one callback. If two notifications for the same day arrive together, only one is passed on.

## One FSEvents stream on the root

The comment in the implementation says there is exactly one FSEvents stream, on the root of the storage folder. The daily files and the inbox all sit under that folder, so nothing has to be re-attached when the day on screen changes. A separate component turns each path into a `StorageChange` and decides which file it was about.

That component only looks at path strings and never touches the file system. As far as I checked, it drops:

- paths outside the storage folder
- the temporary files of atomic writes (rejected by the shape of the name and the extension)
- names that do not fit where a daily file belongs, and files whose year and month folders disagree with the date in the name

Paths from the watcher arrive with symlinks already resolved. The root has to be put in the same form before comparing, or `/var` versus `/private/var` makes events slip through. For a file that no longer exists (a delete notification) the resolution does not drop `/private`, so the same cleanup is applied to both sides. These reasons are in the code comments.

## Notifications that cannot name a file become a full re-read

When there are too many events, FSEvents can return a flag (`MustScanSubDirs`) that means "look at everything under here" instead of giving individual paths. Mounting or unmounting a volume, or moving the watched folder itself, likewise leaves no way to tell which files changed.

If any of `MustScanSubDirs`, `RootChanged`, `Mount` or `Unmount` is set, the implementation emits a single "re-read everything" notification (`needsFullRecheck`). The receiver then looks again at every file it cares about. The stream also gets `WatchRoot`, so that a move of the root is reported.

## The callback outlives the watcher, so it gets its own object

FSEvents callbacks run on a queue of their own. The watcher itself, the side that is released when you call `stop()`, can be gone by the time one last callback arrives late.

So the notification side is split into a small separate class (called `Sink` in the implementation). The callback only touches the Sink, and the Sink also holds the continuations of the subscribed `AsyncStream`s.

- The Sink is kept alive through the `info` pointer. The retain is done by hand exactly once, and the release is left to FSEvents through its release callback. The comment says that if FSEvents is also asked to retain, the number of releases depends on whether the implementation calls retain.
- Calling `stop()` twice has no extra effect. It stops and releases the stream and marks the Sink as finished. A subscriber that arrives after that finishes immediately.

This part is less about FSEvents and more about lifetimes when you hand a Swift object to a C API.

## If the watcher cannot start, saving still works

When the stream cannot be created, for example on a volume where FSEvents is unavailable, the only effect is that no notifications flow. The app has a separate mechanism that compares the content at save time with what it loaded, and that is not affected. Outside changes are picked up later, but the check that keeps a save from overwriting a file changed outside still works.

## The latency is 0.1 seconds, and the first event after a quiet period is not delayed

The coalescing delay is 0.1 seconds, combined with `NoDefer`. With that flag, the first event after a quiet period is delivered right away, and only the events that follow are grouped at that interval. The code does not say why 0.1 seconds was chosen, so I will not guess here.

## The experiment, trimmed

The experiment looks roughly like this (only the DispatchSource and FSEvents parts):

```swift
// Per-file: a DispatchSource on a descriptor opened on the file
let fd = open(file.path, O_EVTONLY)
let source = DispatchSource.makeFileSystemObjectSource(
    fileDescriptor: fd, eventMask: [.write, .delete, .rename, .extend], queue: .global())
source.setEventHandler { /* bump a counter */ }
source.resume()

// FSEvents: one stream on the directory, with file-level events
let stream = FSEventStreamCreate(
    kCFAllocatorDefault, callback, &context, [dir.path] as CFArray,
    FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 0.1,
    FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents
        | kFSEventStreamCreateFlagNoDefer
        | kFSEventStreamCreateFlagUseCFTypes))
```

Even when I only care about a file, watching its folder with FSEvents and sorting by path held up better against replaces.
