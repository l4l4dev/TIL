---
title: 'Swift Testing .serialized runs tests one at a time but not on the same thread, and some tests keep running past .timeLimit'
description: 'Swift Testing runs tests in parallel unless you say otherwise. With .serialized they run one at a time, but the thread changed from test to test. A .timeLimit can only be written in minutes, and going over it cancels the task and fails the test. A test that blocks its thread kept running to the end after the limit passed.'
lang: en
translationKey: swift-testing-serialized-timelimit
publishDate: 2026-11-06
tags: ['Swift', 'Testing']
draft: false
---

I build [FirnPlanner](https://firnplanner.l4l4.dev/), a macOS day planner, as a personal project, and its test suites that touch shared state use `.serialized`. I wrote a small package to see how tests run without any traits, and what `.serialized` and `.timeLimit` change.

## Without traits, tests run in parallel

Swift Testing runs tests in parallel by default. I wrote three tests that share one number. Each one does the following 1,000 times: read the value, `await`, then write back the value plus one.

```swift
for _ in 0..<1000 {
    let value = counter.read()
    await Task.yield()
    counter.write(value + 1)
}
```

If the tests ran one at a time, the final value would be 3,000. Over three runs without traits, the value each test saw when it finished was between 1,011 and 1,056. Writes made by other tests between a read and its write-back were overwritten and lost. The three tests started at the same moment and, after a one-second wait, finished at the same moment.

`swift test --help` lists `--no-parallel` as the default for `--parallel/--no-parallel`. Even so, a plain `swift test` ran the tests in parallel. Only when I passed `--no-parallel` explicitly did they run one at a time and reach 3,000.

## .serialized runs tests one at a time, but the thread changes

I put the same three tests in a suite with `.serialized`.

```swift
@Suite(.serialized) struct Serialized {
    @Test func a() async throws { try await work("serial.a"); await bump(serialCounter, label: "serial.a") }
    @Test func b() async throws { try await work("serial.b"); await bump(serialCounter, label: "serial.b") }
    @Test func c() async throws { try await work("serial.c"); await bump(serialCounter, label: "serial.c") }
}
```

In all three runs, a ran from 0 to 1 second, b from 1 to 2, and c from 2 to 3, and the value went 1,000, 2,000, 3,000. The order was a, b, c every time, but I have not seen it documented as guaranteed, so I would not rely on it.

The threads, on the other hand, did not stay the same. I logged `pthread_mach_thread_np(pthread_self())` at the start and end of each test. In every run, each test ran on a different thread, and within a single test the thread sometimes changed across an `await`. `.serialized` controls the order tests run in, not the thread they run on. A test that assumes it stays on one thread will not get that from `.serialized`.

![Without traits, tests a, b and c all run from 0 to 1 second, and the values they finish with are 1,025, 1,056 and 1,013, short of 3,000. With .serialized, a runs from 0 to 1 second, b from 1 to 2 and c from 2 to 3, and the value goes 1,000, 2,000, 3,000. The threads were 9987 to 9731 for a, 4611 to 10499 for b and 3091 to 4867 for c, so they changed between tests and within a test.](/TIL/images/swift-testing-serialized-en.svg)

Other things I saw:

- Tests inside a `.serialized` suite ran one at a time, but they ran in parallel with tests in other suites
- Tests in a suite nested inside a `.serialized` suite also ran one at a time
- A parameterized test (`@Test(arguments:)`) with `.serialized` ran its cases one at a time. Without it, all three cases started together

## .timeLimit can only be written in minutes

The only way to make a `.timeLimit` value is `.minutes(_:)`. Writing `.seconds(30)` stops the build with this error:

```text
error: 'seconds' is unavailable: Time limit must be specified in minutes
```

`.minutes(0)` did build, though. On a test that waits 3 seconds, it failed right away with `Time limit was exceeded: 0.000 seconds`. The compiler stops you from using seconds, but not from using zero minutes.

## Going over the limit cancels the task and fails the test

With `.timeLimit(.minutes(1))` on a test that waits 90 seconds, the `Task.sleep` threw `CancellationError` and the test failed.

```swift
@Test(.timeLimit(.minutes(1))) func sleepsPastLimit() async throws {
    try await Task.sleep(for: .seconds(90))
}
```

The output said `Time limit was exceeded: 60.000 seconds`, but the failure was reported about 64 seconds after the test started. I have not looked into where the extra 4 seconds come from.

Here is what happened with limits on both the suite and the test, and with a parameterized test. I ran each three times and got the same results.

| What I tried | Limits | Result |
|---|---|---|
| A test that waits 90 seconds | 1 minute on the suite, 3 on the test | Failed at about 64 seconds |
| A test that waits 90 seconds | 3 minutes on the suite, 1 on the test | Failed at about 64 seconds |
| Two tests that wait 40 seconds each, run one at a time | 1 minute on the suite | Both passed (about 85 seconds in total) |
| Two cases that wait 40 seconds each, run one at a time | 1 minute on the test | Passed (about 85 seconds in total) |

Whichever side had the shorter limit, that limit applied. A limit on a suite is not a budget for the whole suite; it applies to each test inside it. For a parameterized test, it applies to each case. This matches the official documentation.

## A test that blocks its thread does not stop at the limit

Cancelling a Swift task does not force it to stop. The code has to check whether it was cancelled and stop on its own. `Task.sleep` throws `CancellationError` as soon as it is cancelled. So I also put `.timeLimit(.minutes(1))` on a test that blocks its thread with `Thread.sleep(forTimeInterval: 90)` instead of `Task.sleep`.

The time limit issue was recorded at about the same time as for the other tests. Even so, the test kept waiting for the full 90 seconds and failed about 90 seconds after it started. The whole test run did not finish until this test did. `.timeLimit` cannot stop code that does not respond to cancellation.

![Both tests have a 1 minute limit and wait 90 seconds. The test that waits with Task.sleep throws CancellationError and fails at about 64 seconds. The test that waits with Thread.sleep has the time limit recorded at about the same time as the others, about 64 seconds, but keeps running and fails at 90 seconds. Both messages read Time limit was exceeded: 60.000 seconds.](/TIL/images/swift-testing-timelimit-en.svg)

## Summary

- Without traits, tests run in parallel. Tests that touch the same state overwrite each other and break it
- `.serialized` runs tests one at a time, but not on the same thread
- `.timeLimit` can only be written in minutes. Going over it cancels the task and fails the test, but code that blocks its thread keeps running to the end

The package I used is in [samples/swift-testing-traits](https://github.com/l4l4dev/TIL/tree/main/samples/swift-testing-traits). Run `swift test --filter ParallelTests` for the parallel and `.serialized` tests, and `swift test --filter TimeLimitTests` for `.timeLimit`. `TimeLimitTests` includes tests that fail on purpose and takes about 90 seconds.

I tested with:

- Xcode 27.2 (27B52)
- Swift 6.4.2
- macOS 27.2
- `swift test`

References:

- [Limiting the running time of tests](https://github.com/swiftlang/swift-testing/blob/main/Sources/Testing/Testing.docc/LimitingExecutionTime.md) (Swift Testing documentation)
- [Using Traits to annotate and customize test behavior](https://www.avanderlee.com/swift-testing/using-traits-to-annotate-and-customize-test-behavior/) (SwiftLee)
- [How to set a time limit for concurrent tests](https://www.hackingwithswift.com/quick-start/concurrency/how-to-set-a-time-limit-for-concurrent-tests) (Hacking with Swift)
- [SwiftTestingのparameterizedテストとTraitsの書き方](https://qiita.com/Hilary02/items/089f0d252f56ad441c35) (Qiita, in Japanese)
- [Learnings About Swift Testing](https://engineering.mercari.com/en/blog/entry/20241212-learnings-about-swift-testing/) (Mercari Engineering)
