---
title: 'Auditing for iPhone Duo with the official Apple agent skills that Xcode 27.2 can export'
description: 'xcrun agent skills export writes out 11 official Apple skills for AI agents. Running app-resizability over an iPhone app still in development found 4 pieces of code that could break when a Duo opens or closes (a hard-coded width, a keyboard check against the whole screen, and a safe area read only once, among others) and postures that had not been checked yet.'
lang: en
translationKey: apple-agent-skills-duo-audit
publishDate: 2026-10-31
tags: ['Xcode', 'iOS', 'AI', 'Claude Code']
draft: false
---

I am developing an iPhone version of [FirnPlanner](https://firnplanner.l4l4.dev/), a day planner I build on my own, and adapting it to the foldable iPhone Duo. I write and review the code with an AI coding agent (Claude Code), so I gave it the agent skills that Apple ships and had it audit the iPhone version.

## Xcode can export 11 official Apple skills

In Xcode 27.2, `xcrun` has `agent skills export`. It writes skills for AI agents, written by Apple, into a folder. Each skill is Markdown with instructions and reference files.

```sh
$ xcrun agent skills export ~/apple-skills
$ ls ~/apple-skills
adopt-c-bounds-safety
app-intents-specialist
app-intents-whats-new-27
app-resizability
audit-xcode-security-settings
building-document-based-swiftui-applications
device-interaction
modernize-tests
swiftui-specialist
swiftui-whats-new-27
xctrace
```

With Claude Code, put them in `~/.claude/skills/` and the agent loads the ones that match the task.

## app-resizability is the one for Duo

The skill for Duo is `app-resizability`. Its instructions say that a request for Duo support means checking every item. The reason given is that when opening and closing changes the screen size, every old pattern shows up at once.

The items are split across 5 reference files.

| Reference | What it checks |
|---|---|
| `uiscreen-task.md` | Sizes based on `UIScreen.main` |
| `safe-area-task.md` | Hard-coded bar heights, a safe area read only once, keyboard positions computed by hand |
| `orientation-task.md` | Branching on portrait or landscape |
| `idiom-task.md` | Branching on iPhone or iPad |
| `scene-lifecycle-task.md` | The old launch flow without scenes |

The skill is built to rewrite what it finds on the spot. This time I kept the code unchanged and only asked for a list of places to fix, because I wanted to decide on each one separately.

## Four code findings and one posture not checked yet

These are the 5 findings. Findings 1 to 4 are code written on the assumption that the screen size never changes. I have not seen any of them break on a device yet. They are places that could break when a Duo opens or closes. Finding 5 is not code. It is the postures I have not checked yet.

1. **Folded or open was decided at a width of 600pt.** When a Duo is open in landscape, the system may put a vertical bar on the left or right edge, and the usable width shrinks by that much. Even the open screen could drop below 600pt and get the folded layout
2. **Whether the keyboard was shown was decided against the whole screen.** When opening or closing changes the window size, the screen and the window no longer match
3. **The input bar above the keyboard read its width only once.** Opening or closing with it shown leaves the old width. It also ignored the left and right safe area, so buttons could end up under the vertical bar
4. **The first window was looked up through `UIApplication.shared`.** This was used to present the sign-in screen and to dismiss the keyboard. The skill gets these from the nearest view or scene instead
5. **The 3 postures (closed, open portrait, open landscape) and the half-folded shape had not been checked yet**

The first one looks like this (a new example written for this post).

```swift
// Switch on width
GeometryReader { proxy in
    if proxy.size.width >= 600 {
        SplitLayout()
    } else {
        StackLayout()
    }
}
```

One option for a fix is to switch on the size class.

```swift
@Environment(\.horizontalSizeClass) private var sizeClass

var body: some View {
    if sizeClass == .regular {
        SplitLayout()
    } else {
        StackLayout()
    }
}
```

This is not a drop-in replacement for the 600pt check. A size class describes the kind of screen and does not promise a particular width. Whether the two-column layout has enough room in regular still has to be checked by capturing each Duo posture.

The second one compares the keyboard frame with `UIScreen.main.bounds`. Type-checking with the iOS 27 SDK warns that `UIScreen.main` is deprecated since iOS 26. The warning text also suggests getting the screen from the window scene.

```swift
// Compare with the whole screen
return frame.minY < UIScreen.main.bounds.maxY
```

The skill recommends `keyboardLayoutGuide`. If you take the frame from the notification, convert it into your view's coordinates before comparing.

```swift
guard let screen = view.window?.windowScene?.screen else { return false }
let local = view.convert(frame, from: screen.coordinateSpace)
return local.intersects(view.bounds)
```

## The side safe area is not only for landscape

The reasoning behind the third finding surprised me. `safe-area-task.md` says the left and right safe area is not a temporary landscape thing. On some devices and configurations, the system puts a vertical bar on one side, and it arrives as a left or right safe area inset. The safe area can also change while the size stays the same, so a value read once and kept stays wrong after the first change.

I thought of the iPhone as a portrait device, so I only worried about the side safe area in landscape with a notch. On a Duo, that assumption no longer holds.

## swiftui-specialist helped on the Mac version too

On the same day, I had the Mac version audited with `swiftui-specialist`. These were unrelated to Duo, and 4 came up.

- A `@State` without `private`. According to the skill's `dataflow.md`, the `@State` macro evaluates an initial value expression (such as `= Store()`) just once only when the getter is `private` or `fileprivate`. Otherwise the expression is evaluated every time the view value is created
- A `DateFormatter` for dates was created on every call
- `ForEach` identified rows by position (`\.offset`)
- APIs with recommended replacements, such as `foregroundColor`, were still in use

## Summary

- Xcode 27.2 can export 11 official Apple agent skills with `xcrun agent skills export <folder>`
- For Duo, use `app-resizability`. It finds hard-coded widths, `UIScreen.main`, a safe area read only once, and window lookups through `UIApplication.shared`, all on the assumption that the screen size changes
- The audit found 4 code issues and postures not checked yet. The code is not fixed yet. When I fix it, I plan to capture the 3 Duo postures and compare before and after

Tested with: Xcode 27.2 (27B52) on macOS 27.2. The audit itself used skills exported from Xcode 27.2 RC.
