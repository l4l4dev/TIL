---
title: 'Dropping XcodeGen and keeping the Xcode 27 project.xcproj in git'
description: 'Xcode 27.2 stores .xcodeproj as JSON5, so I stopped generating the project with XcodeGen and committed it instead. What broke under XcodeGen, how I checked the converted project, and how I tracked down Xcode silently rewriting the file afterwards.'
lang: en
translationKey: xcodegen-to-xcproj
publishDate: 2026-10-01
tags: ['Xcode', 'XcodeGen', 'iOS', 'macOS']
draft: false
---

I dropped XcodeGen from [FirnPlanner](https://github.com/l4l4dev/FirnPlanner), a daily planner for macOS that I build on my own (an iPhone version is in progress). Starting with Xcode 27.2, the inside of `.xcodeproj` is `project.xcproj` (JSON5) instead of `project.pbxproj` (a plist), and its diffs are readable. If the project file can live in git as is, there is nothing left to generate. Most of the implementation is done by AI coding agents, so getting rid of a "remember to regenerate" step that both people and agents forget was a big reason to switch.

The switch taught me one more thing. Once the project is in git, you can see an open Xcode re-saving the project file. One setting disappeared when it did, and I had to find out whether it mattered.

## Under XcodeGen, forgetting to regenerate broke something every time

XcodeGen builds `.xcodeproj` from `project.yml`. Keeping `.xcodeproj` out of git spares you `project.pbxproj` merge conflicts. FirnPlanner kept `.xcodeproj` out of git and generated it from `project.yml` every time. Because that setup rebuilt the project on each generation, our workflow was to run `xcodegen generate` again after adding, deleting, or renaming a file. Settings made in Xcode's UI were lost on the next generation, so we had a rule not to use New File.

Forgetting that step caused real failures:

- After merging a branch into main, I ran the full test suite before regenerating, and the build failed. `PlacementLedger.swift`, added on that branch, was not in the old project
- Regenerating while Xcode was open sometimes left the local Swift package (FirnPlannerCore) unreadable. Closing Xcode and regenerating fixed it, but the symptom did not point at the cause
- Twice, regenerating and running with Xcode open slipped unrelated changes into `Package.resolved` and `Localizable.xcstrings` (an extra dependency in the list, rewritten English strings). I caught both before committing
- Every regeneration rewrote the iPhone app's `Info.plist`, producing the same diff each time

Every manual check also started with "close Xcode, run `mint run xcodegen generate`, reopen, press ⌘R." With more contributors, everyone has to remember that preamble.

## Handing implementation to AI makes the regeneration step matter more

AI coding agents (Claude Code) do most of the implementation on FirnPlanner. An orchestrating session splits the work, worker agents implement in parallel in separate git worktrees, and the orchestrator checks tests and reviews before merging into main. I decide what to build and when to make changes like this one, check behavior on screen, and talk with contributors.

That setup multiplies the XcodeGen chores. Each worktree needs its own generation, and every merge needs another one on main. Every instruction to an agent had to say "regenerate after adding files" and "don't regenerate with Xcode open." The failed build above happened during a merge. Steps that people forget, agents forget too.

So I chose to change the project format and remove the step altogether. The agents did the migration itself: the conversion, the build-settings comparison, testing on two Xcode versions, and fixing CI and the docs. My part was deciding whether to move while 27.2 was still in beta, and checking things in Xcode's UI.

### Failures go where the next agent will read them

Agents don't remember earlier failures across sessions, so I write failures down in places the next agent is sure to read. There are four:

- **Task records**: I track work in Backlog.md. Each task gets a plan, work notes, comments, and a final summary, all written through its CLI. The failed build above is in that day's task notes: "Built before regenerating and failed. Lesson: always run generate first after a merge."
- **Agent memory**: Anything that should carry over to the next session goes into Claude Code's memory, one fact per file, with what happened, why it matters (Why), and what to do next time (How to apply). Entries include "don't let worker agents use git stash (stashes got swapped between worktrees)" and "check that the fast-forward succeeded before moving on after a merge."
- **A procedures doc**: Setup and verification steps live in a single doc that is the source of truth. Memory entries and instructions only say "read that doc" instead of copying its content into several places.
- **Scripts**: Anything a machine can catch becomes a check in a script, such as failing when both project formats are present.

The way work flows is fixed too. When the orchestrator hands a task to a worker agent, the instructions always include five things: the target files, the existing patterns to follow, the done condition, the verification commands, and what not to do (no git stash, only one xcodebuild at a time, and so on). The orchestrator verifies the result with tests, and changes that touch logic go through a pull request reviewed by another AI (Codex). Anything that changes what the screen looks like is marked "awaiting check" and isn't done until a person has followed the check steps.

The failures later in this post were recorded the same way. The Xcode rewrites are in the task notes with the time of both occurrences, and what I found is now in the procedures doc as "treat the form Xcode saves as canonical."

## project.xcproj is a project file with readable diffs

I learned about `project.xcproj` from [this article on Zenn](https://zenn.dev/d_date/articles/b1a7baa74b77da) (in Japanese). The key points:

- New projects created with Xcode 27.2 store `.xcodeproj` as `project.xcproj` (JSON5)
- Only Xcode 27.0 and later can read it. Xcode 26 and earlier cannot open it
- Existing projects convert with `xcodebuild -project App.xcodeproj -convert-project xcproj` (and back with `pbxproj`)
- It ships with an editing CLI, `xcodeproj`, and a formatter, `xcprojformatter`

With readable diffs, most of the reasons to use XcodeGen go away, at least for this project. When I checked in September 2026, XcodeGen did not support the new format.

## Before switching, I checked that the converted project was the same project

Xcode 27.2 was still in beta, so waiting for the release was an option. I moved early because I expected to reuse the approach in other projects. In exchange, I first checked that the converted project matched the original:

1. Convert the XcodeGen-generated project with `-convert-project xcproj`
2. Dump `xcodebuild -showBuildSettings` for every target (6) and every configuration (Debug / Release / Beta) before and after, and diff them. Only `PROJECT_GUID` differed, and that matched in the end too
3. Compare the file count of each target
4. On both Xcode 27.0 and 27.2 beta 2, run the full Mac test suite, the snapshot tests, the iPhone build and tests, and the UI test build

I think deciding up front to diff the build settings paid off. I could switch after confirming zero differences, not after "it seems to work."

A side finding: in my tests with 27.2 beta 2, `xcodebuild` did not convert an XcodeGen `project.pbxproj` on its own. But running `xcodegen generate` where `project.xcproj` exists puts both formats in the same `.xcodeproj`, and Xcode then reads neither. Anyone running the old step would break the project, so my environment check script now fails if both are present.

## I replaced the file list with synchronized folders

The converted project still lists all 950 files XcodeGen had enumerated, one by one. That would make adding files as tedious as before, so I turned the source folders into synchronized folders (drop a file in the folder and it joins the target).

In `project.xcproj`, a folder-to-target mapping looks like this:

```json5
{ "kind": "folder", "path": "MobileTests", "target-membership": [ "FirnPlannerMobileTests" ] },
{ "kind": "folder", "path": "Tests/SnapshotTests", "opaque-folders": [ "__Snapshots__" ], "target-membership": [ "FirnPlannerSnapshotTests" ] },
```

There are a few exceptions:

- Mac files shared with the iPhone app go into the folder's exceptions (`inclusions` under `membership-exceptions`). Ticking Target Membership in Xcode's File inspector writes them there
- Folders that should go into resources as folders, like the snapshot reference images, go into `opaque-folders`. When this project treated them as individual files, the PNGs landed loose at the top of Resources, and `Bundle.url(forResource:)` could no longer find the folder
- `Info.plist` stays a real file in git. It has array and dictionary values that the `INFOPLIST_KEY_*` build settings cannot express

`project.xcproj` cannot hold comments; the formatter drops them. Reasons for build settings now live at the end of the xcconfig, and reasons for Info.plist keys live as comments in the Info.plist.

Along the way I fixed nine places: CI scripts, where the pinned `Package.resolved` lives, the setup guide, `.gitignore`, and so on. I told contributors that they need Xcode 27.0 or later and should delete the old `project.pbxproj` after pulling.

I also missed something. The agents had written step-by-step check instructions for me in past task comments, and eight of them still began with "run `mint run xcodegen generate`, then open the project." Running that now creates `project.pbxproj` and Xcode can no longer open the project. I noticed before following any of them and added corrections. You can update the guide, but instructions written into old work records are hard to chase down.

## After the switch, an open Xcode was rewriting project.xcproj

On the evening of the switch, `project.xcproj` showed a diff I had not made:

```diff
-    }, {
-      "kind": "folder",
-      "path": "Tests",
-      "opaque-folders": [
-        "SnapshotTests",
-      ],
-      "target-membership": [
-        "FirnPlannerTests",
-      ],
-      "membership-exceptions": [
-        {
-          "target": "FirnPlannerTests",
-          "exclusions": [
-            "SnapshotTests",
-          ],
-        },
-      ],
     },
+    { "kind": "folder", "path": "Tests", "opaque-folders": [ "SnapshotTests" ], "target-membership": [ "FirnPlannerTests" ] },
```

I had left Xcode open while an agent merged branches into main. It looks like Xcode noticed the files in the working tree change, reloaded, and saved the project back in its own form. The same rewrite happened again during a merge in the middle of the night while I was asleep. I think I noticed it because an AI was running git in the same working tree where a person had the IDE open.

The rewriting probably happened under XcodeGen as well. Back then `.xcodeproj` was in `.gitignore`, so nobody noticed, and the next generation overwrote it. Keeping the project in git made it visible.

What worried me was that the diff was not just formatting. The exception that removes `SnapshotTests` from the `Tests` folder (`exclusions` under `membership-exceptions`) was gone. Committing it might pull the snapshot test files into the unit test target as well. The first two times, I reverted to the version in git.

## With or without the exception, the builds I compared did not differ

There were two possible reasons Xcode dropped the exception. Either it saw the setting as redundant, because the same entry already lists `SnapshotTests` in `opaque-folders`, or a beta bug was discarding a meaningful setting.

I asked an agent to find out. It cloned the repository twice, kept the git version (with the exception) in one, used Xcode's version (without it) in the other, ran `build-for-testing` on both, and compared the unit test bundles.

| Compared | With exception | Without exception |
| --- | --- | --- |
| Files inside `FirnPlannerTests.xctest` | 36 | 36 (identical list) |
| Size of the test binary | 83,685,136 bytes | 83,685,136 bytes |
| Snapshot test symbols (`nm`) | 0 | 0 |
| Full test suite | Passed (run on main the same day) | Passed |

Within what I compared, the results were the same. Neither bundle contained any SnapshotTests files, and both had zero snapshot test symbols.

What follows is my interpretation. In the `Tests` folder entry, `SnapshotTests` is listed in `opaque-folders`. I think that is why, in this project and this configuration, the snapshot test sources stay out of FirnPlannerTests even without the exclusion. Xcode probably treated the exclusion as redundant and dropped it each time it re-saved. I have not checked Apple's documentation on how `opaque-folders` and exclusions interact in general.

I only compared the macOS Debug configuration, Xcode 27.2 beta 2, and the FirnPlannerTests bundle. I did not compare the snapshot test target, the app bundle, the Release configuration, or Xcode 27.0.

**This time, I adopted Xcode's version as the canonical one in git based on that Debug / FirnPlannerTests comparison. The other scopes remain unverified.** I did confirm that running `xcprojformatter` leaves it unchanged. An open Xcode should no longer produce this diff when an agent merges.

## After editing project.xcproj by hand, open it in Xcode and look for a diff

This added one step to my process. After editing `project.xcproj` by hand or with the CLI, I format it, open it in Xcode once, and confirm that Xcode's re-save produces no diff.

From now on, when a diff appears, I won't adopt Xcode's form right away. The diff alone can't tell me whether the setting is merely redundant from Xcode's point of view or whether a bug in Xcode (especially a beta) is dropping a meaningful setting. Before adopting it, I will list the targets and configurations the setting should affect, build both versions, and compare the outputs. Applied to this case, the scope would include the snapshot test target, the Release configuration, and the other Xcode version I use as a baseline, in addition to FirnPlannerTests (I did not compare those this time). If nothing differs within that scope, I adopt Xcode's form and record what I compared and what I didn't. If something differs, I keep the git version and report it to Apple as a bug.

Some things are still unchecked: whether adding a file through Xcode's UI saves the expected diff in `project.xcproj`, and whether the build passes on the Xcode version Xcode Cloud uses. Xcode 27.2 is still in beta, so the behavior may change in the release. I will update this post when I know more.
