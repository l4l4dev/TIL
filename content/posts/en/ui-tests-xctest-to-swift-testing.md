---
title: 'Tapping a missing element in a Swift Testing UI test let the test continue, and the test runner restarted after it finished'
description: 'I moved UI tests from XCTest to Swift Testing and XCUIAutomation. The rewrite was close to one to one. Tapping an element that does not exist recorded a failure with no line number, the test went on to the next line, and the test runner restarted after the test finished. Checking existence first with try #require avoided the restart.'
lang: en
translationKey: ui-tests-xctest-to-swift-testing
publishDate: 2026-11-20
tags: ['Xcode', 'Swift', 'Testing']
draft: false
---

I build [FirnPlanner](https://firnplanner.l4l4.dev/), a macOS day planner, as a personal project, and I moved its UI tests from XCTest to Swift Testing. That covers the Mac app and the iPhone app, which is still in development. Since Xcode 27.3 beta, UI tests can be written with Swift Testing and XCUIAutomation. The unit tests were already in Swift Testing, so this move was about having one way to write tests.

The rewrite itself was close to one to one. What differed was how a failure plays out. I made a sample with an app that has a single button, wrote the same tests in both XCTest and Swift Testing, and ran them on an iOS simulator.

## The rewrite was close to one to one

| XCTest | Swift Testing |
|---|---|
| `import XCTest` | `import Testing` and `import XCUIAutomation` |
| An `XCTestCase` class | A struct suite marked `@MainActor` |
| Launch the app in `setUp` | Launch at the start of each test |
| Terminate the app in `tearDown` | Terminate in a `defer` in each test |
| `XCTAssertTrue`, `XCTAssertEqual` | `#expect`, `try #require` |
| `try XCTSkipUnless(...)` | `.enabled(if:)` on the suite |
| `XCTAttachment` | `Attachment.record(_:named:)` |

The XCTest version looked like this.

```swift
@MainActor
final class BasicXCTests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = launchApp()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    func testTapIncrementsLabel() {
        app.buttons["button"].tap()
        XCTAssertTrue(app.staticTexts["Count: 1"].waitForExistence(timeout: 5))
    }
}
```

In Swift Testing I wrote it like this. `launchApp()` is a function that only creates an `XCUIApplication()` and calls `launch()`.

```swift
@Suite(.serialized) enum UITests {}

extension UITests {
    @MainActor
    struct BasicTests {
        @Test func tapIncrementsLabel() throws {
            let app = launchApp()
            defer { app.terminate() }
            app.buttons["button"].tap()
            try #require(app.staticTexts["Count: 1"].waitForExistence(timeout: 5))
        }
    }
}
```

Every suite goes into an extension of a parent suite marked `.serialized`. UI tests share one simulator and one app, so they must not run at the same time. In this sample, though, the tests still ran one at a time when I put them under a parent without `.serialized` and passed `-parallel-testing-enabled YES`. That matches [what I saw on Xcode 27.3 beta 1](/TIL/en/posts/swift-testing-serialized-timelimit/). It may not hold under other settings, so I kept `.serialized`.

## Cleanup went into defer. A deinit also worked

A struct suite has no `deinit`. The app termination that used to live in `tearDown` moved into a `defer` in each test. The `defer` runs even when the test exits early from `try #require`.

I also tried making the suite a final class and terminating in `deinit`. Calling `app.terminate()` from a plain `deinit` of a `@MainActor` class gives this warning.

```
warning: call to main actor-isolated instance method 'terminate()' in a synchronous nonisolated context
note: add 'isolated' to run isolated to 'MainActor', which may be later than 'nonisolated deinit'
```

The build passed with the warning in place, and in this run the `deinit` ran on the main thread and the app terminated. Writing `isolated deinit` removes the warning, and that also worked. I have not checked whether a plain `deinit` always runs on the main thread.

## Tapping a missing element let the test continue, and the test runner restarted after it finished

I lined up three tests, and the second one taps a button that does not exist. Each test adds 1 to a static counter and logs it.

```swift
@Test func test2TapMissing() {
    let app = launchApp()
    defer { log("st.tapMissing.2 cleanup state=\(app.state.rawValue)"); app.terminate() }
    Self.counter += 1
    log("st.tapMissing.2 counter=\(Self.counter) before tap")
    app.buttons["missing"].tap()
    log("st.tapMissing.2 after tap")
}
```

This was the output. Long lines are cut short. `pid` is the process ID of the test runner, added by `log`. `state=4` is `runningForeground`, meaning the app is running in the foreground.

```
st.tapMissing.1 counter=1 pid=39022
st.tapMissing.2 counter=2 before tap pid=39022
✘ Test test2TapMissing() recorded an issue: Issue recorded
↳ Failed to tap "missing" Button: No matches found for Elements matching predicate ...
st.tapMissing.2 after tap pid=39022
st.tapMissing.2 cleanup state=4 pid=39022
Restarting after unexpected exit, crash, or test timeout; summary will include totals from previous launches.
st.tapMissing.3 counter=1 pid=39248
```

Four things can be read from this.

- The failure was recorded, but with no file name or line number
- The test went on to the line after the tap, and the `defer` ran too
- After the test finished, the test runner process restarted. The third test ran in a new process
- The static counter went back to 0. In the third test it is 1, not 3

I ran these three tests three times, and the test runner restarted every time. I also tried once with tests that have no cleanup. The app launched by the first test was no longer running after the test runner restarted.

In XCTest, the test stopped at the tap line, and the failure came with a file name and line number. Whether the test runner restarted depended on the class. It restarted in classes that have an async `setUp` or `tearDown`, and in classes without one the next test ran in the same process. I have not narrowed down what makes the difference.

When the test runner restarts, any state kept in static values between tests is gone. Every FirnPlanner test starts by creating a fresh place for its data and launching the app, so the tests after a restart passed as they were.

## Checking existence first with try #require avoided the restart

With the same three tests, I changed the second one to check that the element exists before acting on it.

```swift
try #require(app.buttons["missing"].waitForExistence(timeout: 2))
app.buttons["missing"].tap()
```

```
st.waitRequire.2 counter=2 before wait pid=39248
✘ Test test2WaitMissing() recorded an issue at ExperimentTests.swift:80:17: Expectation failed: app.buttons["missing"].waitForExistence(timeout: 2)
st.waitRequire.2 cleanup pid=39248
st.waitRequire.3 counter=3 pid=39248
```

The failure came with a line number, and the test ended at that line. The test runner did not restart, and the counter went up to 3. Checking with `#expect` did not cause a restart either.

In the migration, I wrote the check before acting on an element with `try #require`. The failing line is easy to find, and no restart happens.

## Attachments, and tests that run only when an environment variable is set

For screenshots, I turned them into PNG data and passed that to `Attachment.record`.

```swift
Attachment.record(XCUIScreen.main.screenshot().pngRepresentation, named: "x.png")
```

I ran `xcodebuild test` with `-resultBundlePath` and exported with `xcrun xcresulttool export attachments`. The PNG and a `manifest.json` came out in the same shape as with `XCTAttachment` in XCTest. With `XCTAttachment` I had been setting `lifetime = .keepAlways`. The images recorded with `Attachment.record` were kept for passing tests without any setting.

For tests that I do not run day to day, such as ones that take screenshots, I put `.enabled(if:)` on the suite.

```swift
@Suite(.enabled(if: ProcessInfo.processInfo.environment["RUN_GATED"] != nil))
```

Putting `TEST_RUNNER_RUN_GATED=1` in front of `xcodebuild` passes it to the test runner as `RUN_GATED`, and the suite runs. Without it, the output says `Suite GatedTests skipped.` and the suite is skipped.

## Things that happened in the app tests but did not reproduce in the sample

In the FirnPlanner tests, when the next test launched the app right after the previous one terminated it, a different test failed on each run. Since I added `app.wait(for: .notRunning, timeout: 10)` after the termination, they have not failed. In the sample, calling `launch()` right after `terminate()` 20 times in a row never failed, with or without the wait, in both XCTest and Swift Testing. The size of the app or the time it takes to quit may play a part, but I have not checked.

I had also dropped the idea of putting launch and cleanup into a custom trait, because the test runner crashed in FirnPlanner. In the sample, I attached a trait that implements `TestScoping` with `isRecursive` set to `true` to a suite, and launched and terminated the app inside `provideScope`. The test runner did not crash and the tests passed. I have not looked into what was different. I did not find a way to hand the `XCUIApplication` from the trait to the test, so the test creates `XCUIApplication()` again.

## Summary

- XCTest UI tests could be rewritten in Swift Testing close to one to one. Cleanup went into a `defer` in each test
- Tapping a missing element recorded a failure with no line number, the test went on, and the test runner restarted after it finished. Static values went back to their initial state
- Checking existence with `try #require` before acting gave the failure a line number, and the test runner did not restart
- Start every test from launching the app, so the run can continue after a restart

The project I used is in [samples/xcuitest-to-swift-testing](https://github.com/l4l4dev/TIL/tree/main/samples/xcuitest-to-swift-testing). The tests that fail on purpose are in suites separate from the passing ones. The README explains how to run them.

Environment: Xcode 27.3 beta 2 (27C5035i), iOS 27.3 simulator (iPhone 18 Pro), run with `xcodebuild test`.
