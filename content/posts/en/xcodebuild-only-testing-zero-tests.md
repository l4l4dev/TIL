---
title: 'xcodebuild -only-testing reports success with 0 tests when the filter misses'
description: 'When you narrow Swift Testing tests with xcodebuild -only-testing and get the suite nesting or the () wrong, nothing runs and you still get TEST SUCCEEDED with exit code 0. The Executed line is not reliable either, so check N in Test run with N tests.'
lang: en
translationKey: xcodebuild-only-testing-zero-tests
publishDate: 2026-10-31
tags: ['Xcode', 'Swift', 'Testing']
draft: false
---

While working on [FirnPlanner](https://firnplanner.l4l4.dev/), I reran a single failing snapshot test and it said it passed. When I checked the log later, not a single test had run.

## Trying it with a test that always fails

I put one test that always fails into a small package. The suites are nested.

```swift
import Testing
@testable import Calc

@Suite struct Outer {
    @Suite struct AddTests {
        @Test func addsTwoNumbers() {
            #expect(add(1, 2) == 4) // fails on purpose
        }
    }
}
```

Then I ran it, changing only the `-only-testing` value.

```sh
xcodebuild test -scheme Calc-Package -destination 'platform=macOS' \
  -only-testing:CalcTests/Outer/AddTests
```

| `-only-testing:` value | Tests run | Result |
|---|---|---|
| `CalcTests` | 1 | Failed (correct) |
| `CalcTests/Outer/AddTests` | 1 | Failed (correct) |
| `CalcTests/Outer/AddTests/addsTwoNumbers()` | 1 | Failed (correct) |
| `CalcTests/AddTests` (parent suite skipped) | 0 | **Succeeded** |
| `CalcTests/Outer/AddTests/addsTwoNumbers` (no `()`) | 0 | **Succeeded** |
| `CalcTests/Outer()` (`()` on a suite) | 0 | **Succeeded** |
| `CalcTests/Outre` (typo) | 0 | **Succeeded** |

All 4 misses ended with `** TEST SUCCEEDED **` and exit code 0. Passing a name that does not exist gave no warning that the name was not found.

## How to write the filter for Swift Testing

In what I tried, this is how it worked.

- Follow every level of suite nesting (`Outer/AddTests`). Skipping the parent does not match
- Add `()` to the end of a test function (`addsTwoNumbers()`)
- Do not add `()` to a suite (a struct)

## Do not trust the Executed line

The log had an XCTest-style `Executed 0 tests` line even when the test did run. Swift Testing tests do not seem to be counted on that line.

Check the count on this line from Swift Testing instead.

```text
✘ Test run with 1 test in 2 suites failed after 0.001 seconds with 1 issue.
```

When the filter misses, this line says `Test run with 0 tests`, or it does not appear at all.

## Summary

- When `-only-testing` misses, you get a success with 0 tests
- For Swift Testing, follow the suite nesting and add `()` only to functions
- When you run only part of the tests, check that N in `Test run with N tests` is not 0 before you say they passed

Tested with: Xcode 27.2 (27B52) on macOS 27.2.
