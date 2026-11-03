---
title: 'The .prohibited activation policy stopped a macOS test host from coming to the front'
description: 'Every xcodebuild test run brought the app launched as the test host to the front and took key input from whatever app I was typing in. Setting the activation policy to .prohibited in applicationWillFinishLaunching stopped it; .accessory did not. I checked by logging the frontmost app.'
lang: en
translationKey: test-host-stays-in-background
publishDate: 2026-11-04
tags: ['Xcode', 'macOS', 'Testing']
draft: false
---

In [FirnPlanner](https://firnplanner.l4l4.dev/), a one-day planner for macOS that I build on my own, every full test run brought the FirnPlanner instance launched for the tests to the front. If I was typing in another app, my input suddenly went somewhere else.

Unit tests launch the app as a test host and run the tests inside it. That test host was what came to the front.

## Set .prohibited just before launch finishes

In `applicationWillFinishLaunching`, I set the activation policy to `.prohibited`, but only when the app is launched as a test host.

```swift
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            NSApp.setActivationPolicy(.prohibited)
        }
    }
}
```

A process launched as a test host has the environment variable `XCTestConfigurationFilePath`. A normal launch does not, so this check tells the two apart.

According to Apple's documentation, a `.prohibited` app does not appear in the Dock, may not create windows, and is not activated. An `.accessory` app only stays out of the Dock; it can still be activated.

## I compared them by logging the frontmost app

It is hard to tell by eye whether the app stopped coming to the front. I ran a script that writes the name of the frontmost app every 0.25 seconds next to the tests.

```sh
#!/bin/zsh
# Log the name of the frontmost app every 0.25 seconds. Stop with Ctrl-C
while true; do
  name=$(lsappinfo info "$(lsappinfo front)" | head -1 | cut -d'"' -f2)
  print -r -- "$(date +%H:%M:%S) $name"
  sleep 0.25
done
```

These are the lines logged during the tests, and how many of them had FirnPlanner in front.

| Test host setting | Lines logged | Lines with FirnPlanner in front |
|---|---|---|
| Nothing | 60 | 4 |
| `.accessory` | 63 | 8 |
| `.prohibited` | 491 | 0 |

The `.prohibited` row covers a full test run to the end. The other two cover only part of a run. Because the lengths differ, the higher count for `.accessory` tells us nothing. What I can say is that `.accessory` did not stop the app from coming to the front, and `.prohibited` kept it in the background for a whole full run.

I did not find out why `.accessory` did not help. Still, as the documentation above says, an `.accessory` app can be activated, so this does not contradict it.

## Only for tests that need no windows

A `.prohibited` app cannot create windows. FirnPlanner tests only put views in an `NSHostingView` and draw them offscreen, so they need no windows. If your tests rely on a key window or on window ordering, this approach does not fit.

Apps launched by UI tests (XCUITest) do not become `.prohibited` through this check. UI test runs still come to the front.

## Running the tests on another desktop was not an option

My first idea was to run the tests on a separate desktop (Space). But macOS has a setting, on by default, that moves the screen to the desktop holding an app window when you switch to that app. With it on, the screen should jump to that desktop whenever the test host comes to the front. I expected that to be worse, so I dropped the idea without trying it.

## Two flaky tests passed in all 20 runs

After the change, I ran the full suite 20 times. Two tests that used to fail now and then, one checking the height of a date format field and one checking the width of a mermaid diagram, did not fail once. I have not checked whether this is related to the app no longer coming to the front. Another test still failed in 2 of the 20 runs.

## Summary

- Setting `.prohibited` in `applicationWillFinishLaunching` stopped the test host from coming to the front
- `.accessory` did not
- The app can no longer create windows, so this is only for tests that need none

Environment: Xcode 27.2 beta 3 (27B5038j), macOS 27.2. Logged in October 2026.
