---
title: 'When @MainActor tests run in parallel in Swift Testing, AsyncStream values arrive later in proportion to the number of tests using main'
description: 'Swift Testing runs @MainActor tests at the same time, but there is only one main thread, so they take turns. When the waiting test is on main, values arrived late by the time other tests spent on main, and a custom 1 second timeout sometimes fired. While main was blocked, a test that went over .timeLimit did not end.'
lang: en
translationKey: swift-testing-mainactor-contention
publishDate: 2026-11-07
tags: ['Swift', 'Testing']
draft: false
---

I build [FirnPlanner](https://firnplanner.l4l4.dev/), a macOS day planner, as a personal project, and many of its tests are marked `@MainActor`. The question came up whether tests that wait on an AsyncStream with a custom timeout would time out more often on a slower machine such as CI. I wrote a small package to measure how late values arrive when `@MainActor` tests run at the same time.

## @MainActor tests run at the same time, but there is only one main thread

Unless told otherwise, Swift Testing runs tests at the same time. Tests marked `@MainActor` also start together, but all of them run on the main thread. Calling `pthread_main_np()` inside those tests reported main every time. With only one main thread, `@MainActor` tests take turns on it, handing it over at each `await`.

To see how much this waiting delays a value, I measured the following.

- The waiting test receives one value from an AsyncStream. The producer task sends it 300 ms after it starts. If nothing arrives within 1 second, a timer finishes the stream (a custom timeout). This repeats 5 times, and each time the test records how many ms after 300 ms the value arrived
- Each busy test is `@MainActor`. It keeps main for 50 ms and then gives it up with `Task.yield()`, for about 4 seconds. I ran 0, 2, 4, or 8 of them at the same time

```swift
let (stream, continuation) = AsyncStream<Int>.makeStream()
Task { @MainActor in            // when the producer is on main
    try? await Task.sleep(for: .milliseconds(300))
    continuation.yield(1)
}
Task.detached {                 // the custom 1 second timeout
    try? await Task.sleep(for: .seconds(1))
    continuation.finish()
}
for await _ in stream { received = true; break }
```

There were three waiting tests: consumer and producer both off main, only the consumer on main, and consumer and producer both on main.

## With the consumer on main, the delay was the number of busy tests times 50 ms

Across 3 runs, the delays were:

| Busy tests at the same time | Consumer and producer off main | Only the consumer on main | Consumer and producer on main |
|---|---|---|---|
| 0 | 0–14 ms | 0–14 ms | 0–14 ms |
| 2 | 0–16 ms | 50–100 ms | 200–300 ms |
| 4 | 0–19 ms | 200 ms | 500–600 ms |
| 8 | 0–20 ms | 350–400 ms | 2 of 5 hit the 1 s timeout |

With only the consumer on main, most waits were 100 ms late with 2 busy tests, 200 ms with 4, and 400 ms with 8. That is the number of busy tests times 50 ms. My reading is that after the value arrives, the consumer waits behind the busy tests for its turn on main. With the consumer off main, the delay stayed under 20 ms even with 8 busy tests.

With the producer on main too, the delay roughly doubled. I think this is because the producer also waits for its turn on main before it sends the value. With 8 busy tests, 2 of 5 waits hit the custom 1 second timeout in all 3 runs.

The last one or two waits in a row were sometimes shorter. The busy tests end after about 4 seconds, so later waits no longer queue for main. The ranges in the table leave those short values out.

![Delay when waiting on an AsyncStream for a value sent after 300 ms. With only the consumer on main, 0, 2, 4, and 8 busy @MainActor tests running at the same time gave delays of about 0, 100 ms, 200 ms, and 400 ms. With the producer also on main, the delays were about 0, 200 to 300 ms, and 500 to 600 ms, and with 8 busy tests 2 of 5 waits hit the custom 1 second timeout. Each busy test uses main for 50 ms and then yields. With 8 busy tests, the 400 ms delay matches the consumer waiting behind all 8, 8 times 50 ms. Off main, the delay stayed under 20 ms even with 8 busy tests.](/TIL/images/swift-testing-mainactor-en.svg)

## Doubling how long each turn on main lasts doubled the delay

To imitate the same work on a slower machine, I made 4 busy tests keep main for 100 ms per turn instead of 50 ms. Across 3 runs, the delay with only the consumer on main became 400 ms, twice the 200 ms seen with 50 ms turns. With consumer and producer on main, 1 or 2 of 5 waits hit the 1 second timeout in all 3 runs. With 50 ms turns and 4 busy tests, none had timed out.

## --num-workers did not change how many tests ran at the same time

Running fewer tests at the same time should mean less waiting for main, so I tried ways to limit it.

With `swift test --parallel --num-workers 2`, the results were the same as without a limit. With 8 busy tests, the delay with only the consumer on main was 400 ms, and with consumer and producer on main 2 of 5 waits timed out. Passing `--num-workers` without `--parallel` stopped with `error: --num-workers must be used with --parallel`.

The number of tests running at the same time changed only with the environment variable `SWT_EXPERIMENTAL_MAXIMUM_PARALLELIZATION_WIDTH=2`. The busy tests ran two at a time, and finishing 8 tests of 4 seconds each took about 21 seconds. In 2 runs, every waiting test was 50 ms late or less. However, in both runs the waiting tests ran before the busy ones, so the order also explains part of the smaller delay. This variable is a name found inside Testing.framework and, as the name says, experimental. The official document [Running tests serially or in parallel](https://github.com/swiftlang/swift-testing/blob/main/Sources/Testing/Testing.docc/Parallelization.md) only says that the Swift runtime controls how many tests run concurrently.

## While main is blocked, a test that goes over .timeLimit does not end

I also checked whether `.timeLimit` stops a wait on an AsyncStream. I put `.timeLimit(.minutes(1))` on a test that waits with `for await` on a stream that never sends a value and never finishes.

```swift
@Test(.timeLimit(.minutes(1))) @MainActor func waitsOnSilentStream() async {
    let (stream, continuation) = AsyncStream<Int>.makeStream()
    for await _ in stream {}
    continuation.finish()
}
```

Run alone, the test was cancelled after about 64 seconds, left the loop, and failed with `Time limit was exceeded: 60.000 seconds`.

Next, I put three more tests in the same suite: a `@MainActor` test that blocks main for 90 seconds (`Thread.sleep(forTimeInterval: 90)`), a `@MainActor` test that needs 1 second, and a test off main that needs 1 second. All 3 runs went the same way.

- The waiting test and the blocking test both recorded a time limit issue
- But the waiting test left the loop and failed only after about 90 seconds. Even after cancellation, it needs main to be free to leave the loop and continue
- The `@MainActor` test that needs 1 second also finished only after about 90 seconds
- The test off main finished in 1 second

In the first run, the body of the waiting test only started after about 90 seconds, and the time limit issue was still recorded. The limit appears to be counted from when the test starts, not from when its body first runs on main.

## When timeouts become more likely on CI

From here on is my inference from the results above. I did not try it on an actual CI machine.

The delay depended on how many `@MainActor` tests ran at the same time and how long each kept main per turn. On a slower CI machine, each turn lasts longer, so I expect the delay to grow as the product of the two. Since there is only one main thread, more cores on CI should not reduce this waiting.

When writing tests, I think these steps help, in this order.

- Move the AsyncStream producer and the logic under test off main. In these runs, a consumer off main was never more than 20 ms late
- Stop waiting with a custom timeout in seconds, and wait until the value arrives. Leave failing a test that hangs to `.timeLimit`. The Hacking with Swift article also recommends checking an AsyncStream with `for await` inside `confirmation(expectedCount:)`
- Put tests that hold main for long into a `.serialized` suite so they do not run at the same time
- Keep code that blocks main synchronously out of tests. While main is blocked, neither `.timeLimit` nor other `@MainActor` tests make progress

`confirmation` runs its body on the caller's actor (`isolation: isolated (any Actor)? = #isolation`). Called from a `@MainActor` test, its body runs on main too, so I expect the same waiting for main.

## Summary

- `@MainActor` tests run at the same time but take turns on the single main thread. With the waiting test on main, the delay was the number of busy tests times how long each turn on main lasted
- With the producer also on main, the delay roughly doubled and the custom 1 second timeout fired
- `--num-workers` did not change how many tests ran at the same time. Only an experimental environment variable limited it
- `.timeLimit` cancels and stops a wait on an AsyncStream, but while main is blocked, the test does not end even after the time limit issue is recorded

The package I used is in [samples/swift-testing-mainactor](https://github.com/l4l4dev/TIL/tree/main/samples/swift-testing-mainactor). `LOAD=8 swift test --filter ContentionTests` runs the waiting experiment, and `swift test --filter BlockedMainTests` runs the `.timeLimit` experiment. `BlockedMainTests` fails on purpose and takes about 90 seconds.

Environment:

- Xcode 27.2 (27B52)
- Swift 6.4.2
- macOS 27.2
- Run with `swift test`
- A Mac with Apple silicon (18 logical CPUs)

References:

- [Running tests serially or in parallel](https://github.com/swiftlang/swift-testing/blob/main/Sources/Testing/Testing.docc/Parallelization.md) (Swift Testing documentation)
- [Testing asynchronous code](https://github.com/swiftlang/swift-testing/blob/main/Sources/Testing/Testing.docc/testing-asynchronous-code.md) (Swift Testing documentation)
- [How to force concurrent tests to run on a specific actor](https://www.hackingwithswift.com/quick-start/concurrency/how-to-force-concurrent-tests-to-run-on-a-specific-actor) (Hacking with Swift)
- [How to test AsyncSequence and AsyncStream](https://www.hackingwithswift.com/quick-start/concurrency/how-to-test-asyncsequence-and-asyncstream) (Hacking with Swift)
