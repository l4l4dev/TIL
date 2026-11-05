---
title: 'XCUIHinge moves the hinge from a UI test, but the same angle does not always give the same layout'
description: 'I tried XCUIHinge, added in Xcode 27.3 beta 1, on the iPhone Duo simulator. You set the angle in radians, and it works from both XCTest and Swift Testing. The angle you read back stops short of the value you set, and the layout at the same angle changed depending on how the hinge got there.'
lang: en
translationKey: xcuihinge-ui-test
publishDate: 2026-11-05
tags: ['Xcode', 'iOS', 'Simulator', 'Testing']
draft: false
---

I build [FirnPlanner](https://firnplanner.l4l4.dev/), a macOS day planner, as a personal project, and I am working on a version for iPhone Duo. It uses a different layout when the device is open and when it is closed, so when I heard that Xcode 27.3 beta 1 added `XCUIHinge` for driving the hinge angle from UI tests, I tried it on the simulator.

## The API is a single angle property

This is everything in the header (`XCUIAutomation.framework/Headers/XCUIHinge.h`):

- You get it from `XCUIDevice.shared.hinge`. The type is `XCUIHinge?`, and it is `nil` on devices without a hinge
- `angle` is a `CGFloat` in radians. 0 is closed and π is fully flat
- Use it from the MainActor
- A note says that on physical devices, opening the hinge programmatically while the device is closed is not supported and fails the test

The header also says that reading the angle alone does not tell you which layout your app uses. My results matched that note.

## It works from both XCTest and Swift Testing

I made an app that only shows the screen width and the size class, and added two UI test targets. On the XCTest side, `import XCTest` is enough to use `hinge`.

```swift
import XCTest

final class HingeXCTests: XCTestCase {
    @MainActor
    func testOpenFlat() throws {
        let app = XCUIApplication()
        app.launch()

        let hinge = try XCTUnwrap(XCUIDevice.shared.hinge)
        hinge.angle = .pi // open flat

        let sizeClass = app.staticTexts["sizeClass"]
        XCTAssertTrue(sizeClass.wait(for: \.label, toEqual: "regular", timeout: 5))
    }
}
```

For Swift Testing, I imported `Testing` and `XCUIAutomation` and marked the suite `@MainActor`. The target is a regular UI test target with no extra settings.

```swift
import Foundation
import Testing
import XCUIAutomation

@MainActor
struct HingeSwiftTests {
    @Test func openFlatShowsRegularWidth() async throws {
        let app = XCUIApplication()
        app.launch()

        let hinge = try #require(XCUIDevice.shared.hinge)
        hinge.angle = .pi
        try await Task.sleep(for: .seconds(1))

        #expect(app.staticTexts["sizeClass"].label == "regular")
    }
}
```

Both passed on the iPhone Duo simulator. On the iPhone 18 Pro simulator, `hinge` was `nil`. I have not tried a physical device.

## The angle you read back stops short of the value you set

I set an angle, waited until the screen had not changed for 2 seconds, and read `angle` back.

| Movement | Set | Read back |
|---|---|---|
| Opening from 0° | 30° | 28.46° |
| Opening from 60° | 90° | 88.46° |
| Closing from 120° | 90° | 91.54° |
| Straight from 0° | 90° | 85.38° |
| Straight from 180° | 90° | 94.62° |
| From anywhere | 0° / 180° | 0° / 180° |

For angles in between, the hinge stopped about 5% of the distance moved short of the target. 0° and 180° came out exactly as set, and out-of-range values (200°, -10°) became 180° and 0°. Across three runs of the same sequence, most values matched within 0.1°. One value (closing from 150° to 120°) split into two results, 121.54° and 120.93°.

I do not know why it stops short. If a test compares angles, it cannot assume the value matches the one it set.

## At the same 90°, the layout depends on how the hinge got there

In the same test, I also recorded the size class.

- Opening from 0° in 15 to 30° steps, it stayed compact through 120° and switched to regular at 150°
- Closing from 180° in 15 to 30° steps, it stayed regular down to 30° and went back to compact at 0°
- Opening straight from 0° to 90° gave regular

So at 90°, the size class was compact when the hinge opened gradually from 0° and regular when it opened in one step. This was the same in all three runs.

In one of the three runs, the app also stayed regular after the hinge closed to 0°. I could not reproduce that.

When I first read the screen after only `sleep(1)`, I got regular at 45°, which did not match the other results. I think I was reading before the layout finished switching. When a test checks the screen, waiting until it stops changing was more stable than waiting for a fixed time.

## Summary

- Setting `XCUIDevice.shared.hinge?.angle` in radians moves the simulator hinge. It works from both XCTest and Swift Testing
- For angles in between, the value you read back differs from the one you set. Compare with a tolerance
- The angle alone does not decide the layout. After setting it, check what is actually on screen

Environment:

- Xcode 27.3 beta 1 (27C5020n)
- iPhone Duo and iPhone 18 Pro on the iOS 27.3 simulator (24C5037i)
- macOS 27.2
- Project generated with XcodeGen 2.45.4
