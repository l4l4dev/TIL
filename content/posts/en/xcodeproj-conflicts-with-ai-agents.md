---
title: 'Does project.xcproj reduce conflicts? With AI agents in parallel, the records conflicted more than the code'
description: 'Will the JSON project file format in Xcode 27 make conflicts before a release easier? Why pbxproj conflicts so often, what actually helps, and what conflicted in a repository where AI agents work in parallel, counted by redoing 660 merges.'
lang: en
translationKey: xcodeproj-conflicts-with-ai-agents
publishDate: 2026-10-06
tags: ['Xcode', 'Git', 'AI']
draft: false
---

When several teams work on one `.xcodeproj`, `project.pbxproj` often conflicts right before a release. My personal project [FirnPlanner](https://firnplanner.l4l4.dev/), a daily planner for macOS, moved to the new project file format introduced in Xcode 27.2 (`project.xcproj`, JSON5) ([the post about the move](/TIL/en/posts/xcodegen-to-xcproj/)). I thought about whether this format makes conflicts easier, and counted what actually conflicted in my own repository.

In short, there is reason to expect it to help. But what helps is mostly "synchronized folders", not the JSON format itself. And in this repository, where AI agents work in parallel, what conflicted was neither the project file nor the code, but the work records. This is a record as of 6 October 2026.

## pbxproj conflicts because one new file changes four places

In `project.pbxproj`, adding one source file usually rewrites about four places:

- `PBXFileReference` (the file itself)
- `PBXBuildFile` (the entry that puts it in a target)
- the group's `children` (where it sits in the navigator)
- the build phase's `files` (the list to compile)

These entries are tied together by random 24-character IDs. When two teams add different files to the same group, both rewrite neighbouring lines in the same lists, and they conflict. Because the content is mostly IDs, it is hard for a person to read which side to keep. Merging every team's branch before a release makes this happen again and again.

## Synchronized folders help most, JSON comes second

Since moving to `project.xcproj`, two things seem to affect how conflicts happen.

The first is **synchronized folders**. Once a source folder is tied to a target, any file placed in that folder joins the target. Adding, deleting or renaming a file does not change the project file. The four places above are not rewritten at all, so this helps the most. Note that synchronized folders have been available in `project.pbxproj` since Xcode 16. You can adopt them without moving to JSON.

The second is the **JSON5 format**.

```json5
{ "kind": "folder", "path": "MobileTests", "target-membership": [ "FirnPlannerMobileTests" ] },
```

Entries are written with paths and target names instead of IDs, so when a conflict happens you can read what conflicted with what. Trailing commas are allowed, so adding a line at the end of an array does not change the line before it. That should reduce conflicts caused by two sides editing neighbouring lines.

Some things can still conflict. Build settings, new targets, package dependencies and folder exceptions (files shared with another target) are still written in `project.xcproj`. Also, an open Xcode sometimes saves the project file again in its own shape ([the second half of the earlier post](/TIL/en/posts/xcodegen-to-xcproj/)). If a team does not use the same Xcode version, formatting differences may show up as diffs and cause conflicts. I have not verified this yet; it is only a concern.

## Redoing 660 merges to count what conflicted

In the FirnPlanner development repository, most of the implementation is done by an AI coding agent (Claude Code), and agents work in parallel, one per git worktree. From 1 August to 6 October 2026, main has 660 merge commits.

Git does not record conflicts. So I merged the two parents of each merge commit again with `git merge-tree` and listed the conflicting files.

```sh
git rev-list --merges main | while read m; do
  git merge-tree --write-tree --name-only --no-messages "$m^1" "$m^2" >/dev/null
  [ $? -eq 1 ] && echo "$m"   # 1 means there were conflicts
done
```

With `--name-only`, the lines after the first one are the names of the conflicting files. The results:

| Item | Count |
| --- | --- |
| Merges with conflicts | 126 (August 19, September 86, 1 to 6 October 21) |
| Of those, merges where only work records conflicted | 94 |
| Both records and code | 11 |
| Only code and other non-record files | 21 |
| Conflicting files: task records | 73 |
| Conflicting files: spec and design-value docs | 46 (spec 29, design values 16, other 1) |
| Conflicting files: Swift | 38 (in 23 merges) |
| Conflicting files: snapshot PNGs | 14 |
| Conflicting files: lint baseline / string catalog | 5 / 3 |
| Conflicting files: project file | 0 |

The work records are task files and docs in the task manager [Backlog.md](https://github.com/MrLesk/Backlog.md). Each agent appends notes to its own task file and edits the spec docs. Different branches edit the same doc, so they conflict.

This way of counting has limits. It only sees conflicts that remained as merge commits. Fast-forwards, and conflicts while rebasing a branch in a worktree, are not included. So I also counted `CONFLICT (content): Merge conflict in ...` messages in the agents' session logs: 128 for records, 48 for Swift, 46 for others (lint baseline, string catalog, snapshots), and only 2 for the project file. Those 2 happened on the day I dropped XcodeGen, when a branch based on an old main was rebased.

## Zero project file conflicts does not mean anything yet

The zero conflicts on the project file are not the effect of JSON. Until 29 September I used XcodeGen, did not keep `.xcodeproj` in git, and generated it from `project.yml` every time. `project.pbxproj` never had a chance to conflict. `project.yml` changed 47 times without conflicts, but that is XcodeGen at work.

I moved to `project.xcproj` on 30 September. By 6 October it had changed 8 times, with no conflicts. With synchronized folders, adding files does not change the project file, so there are few changes in the first place. Whether JSON reduced conflicts can only be said after more data builds up.

## When AI works in parallel, the records conflict

What surprised me was how few Swift conflicts there were: 23 out of 660 merges. When I give work to agents, the rule is not to give tasks that touch the same file at the same time, and I think that is working. I have not compared it with having no such rule, so this is a guess.

Instead, the work records conflicted, because every agent appends to the same spec docs. Code can be kept apart by how work is assigned, but records are written by everyone in the same place. It is the same shape as teams conflicting on the project file before a release: one file that everyone writes to will conflict.

If your team struggles with `.xcodeproj` conflicts, adopting synchronized folders first is likely to help. You can do that while staying on `project.pbxproj`. Moving to JSON is the next step, which makes conflicts readable when they happen.
