---
title: 'SwiftUI #Preview did not render because even Debug was built with -O'
description: 'In a SwiftUI app I build as a personal project, #Preview did not render. ENABLE_PREVIEWS was YES from the start. The cause was that SWIFT_OPTIMIZATION_LEVEL was not set anywhere, so even Debug was built with -O. Adding one line to an xcconfig fixed it, but the change only took effect after reopening the workspace in Xcode.'
lang: en
translationKey: swiftui-preview-needs-onone
publishDate: 2026-11-08
tags: ['Xcode', 'SwiftUI']
draft: false
---

In a SwiftUI app I build as a personal project, `#Preview` did not render. My first guess was that `ENABLE_PREVIEWS` was `NO`, but that was wrong. The cause was that the Swift optimization level (`SWIFT_OPTIMIZATION_LEVEL`) was not set anywhere.

## ENABLE_PREVIEWS was YES from the start

When previews do not show up, the first thing I suspected was `ENABLE_PREVIEWS`. But the app target had it set to `YES` from the start.

## Without SWIFT_OPTIMIZATION_LEVEL, even Debug is built with -O

Looking at the build settings, `SWIFT_OPTIMIZATION_LEVEL` was not set in the project, the target or the xcconfig files. The app keeps its build settings in xcconfig files, but the Debug `-Onone` was not there either. When it is not set, Xcode uses its default, and even the Debug configuration is built with `-O`. To render a preview, the code has to be built without optimization (`-Onone`).

I checked that Debug really gets `-O` in a separate small project. I built a project with no optimization level set, in Debug, for the iOS simulator, and counted the flags passed to the Swift compiler in the build log.

```sh
xcodebuild -project PrevLab.xcodeproj -scheme PrevLab -configuration Debug \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath dd build > build.log 2>&1
grep -E 'swift-frontend|swiftc|SwiftDriver' build.log | grep -oE ' -O(none|size|unchecked)?( |$)' | sort | uniq -c
```

With no optimization level set, all 6 were `-O`. In `xcodebuild -showBuildSettings`, `SWIFT_OPTIMIZATION_LEVEL` did not appear in the list, and `IS_UNOPTIMIZED_BUILD` was `NO`.

| How the optimization level is set | Flag passed to the compiler | `IS_UNOPTIMIZED_BUILD` |
|---|---|---|
| Not set anywhere | `-O` (6 places) | `NO` |
| `-Onone` for Debug only, in an xcconfig | `-Onone` (6 places) | `YES` |

A project newly created in Xcode has `-Onone` for Debug in its project build settings. If that line is lost, for example when moving build settings into xcconfig files or regenerating the project, the same thing happens.

## Adding one line to the xcconfig fixed it

I added this line to `Configs/Base.xcconfig`. It sets `-Onone` only for the Debug configuration.

```text
SWIFT_OPTIMIZATION_LEVEL[config=Debug] = -Onone
```

Release keeps the default `-O`.

## With Xcode open, the xcconfig change did not take effect

After editing the xcconfig, the change did not reach the preview renderer (RenderPreview) while Xcode stayed open. Closing and reopening the workspace made the preview render. I have not looked into why it needed a reopen. If changing an xcconfig does not change the preview, reopening the workspace once seems worth trying.

After reopening, the `#Preview` of `ContentView` rendered in both light and dark. I reverted the settings change after checking.

## Summary

- When `#Preview` did not show, `ENABLE_PREVIEWS` was `YES`, but the preview could not render while the optimization level was `-O`
- If `SWIFT_OPTIMIZATION_LEVEL` is not set anywhere, even Debug is built with `-O`
- Adding `SWIFT_OPTIMIZATION_LEVEL[config=Debug] = -Onone` to the xcconfig fixed it
- The xcconfig change did not reach the preview until the workspace was reopened in Xcode

I tested with:

- Xcode 27.3 beta 1 (27C5020n)
- Builds for the iOS 27.3 simulator
