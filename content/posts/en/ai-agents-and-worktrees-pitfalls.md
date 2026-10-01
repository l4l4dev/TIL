---
title: 'Pitfalls of running AI agents in parallel with git worktree'
description: 'Five problems I hit running Claude Code subagents in parallel git worktrees: a stale main as the starting point, worktrees that vanish when nothing changed, a merge failure hidden by a pipe, DerivedData that keeps growing, and waits that stall.'
lang: en
translationKey: ai-agents-and-worktrees-pitfalls
publishDate: 2026-10-01
tags: ['Git', 'git worktree', 'Xcode', 'AI', 'Claude Code']
draft: false
---

In [the previous post](/TIL/en/posts/git-stash-across-worktrees/) I wrote about how `git stash` exists only once across worktrees, which made two agents swap their changes. I build a macOS app as a personal project and run Claude Code subagents in parallel, one git worktree each. Besides stash, this setup gave me a few more problems. Below are five short sections, each with what happened, why, and what I do now.

## A worktree is cut from main at launch time, so I rebase before the PR

When I start a subagent with `isolation: "worktree"`, it gets a dedicated worktree. As far as I observed, that worktree is cut from main at the moment the agent starts. If main moves on while the agent works, the worktree does not follow.

The trouble starts when the returned branch becomes a PR as it is. The diff can silently revert changes that landed on main later. This actually happened once: I squashed commits with `git reset --soft origin/main` on a branch cut from an old main, and the result included a diff that undid a fix merged in the meantime. I noticed before it reached main and redid the branch.

Before merging, I now always check two things.

```sh
git merge-base --is-ancestor origin/main HEAD && echo "contains latest main"
git diff --stat origin/main...HEAD
```

If the first one fails, I run `git rebase origin/main` first. If the second one lists files the branch was never meant to touch, I stop there. I only squash commits after the rebase.

## A worktree with no changes disappears, and the follow-up runs in another checkout

This is something I observed, not something I verified as specified behavior. A worktree created by `isolation: "worktree"` seemed to be cleaned up automatically when the agent finished without changing anything.

I once had an agent do only investigation and planning, then asked it to continue with the implementation. The investigation had changed nothing, so the worktree was already gone. The agent's working directory fell back to the checkout at the repository root. Another session was using that checkout on a different branch, and the agent temporarily renamed that branch. I restored it right away and nothing was lost, but it could easily have broken the other session's work.

For work that involves implementation I no longer use `isolation`. I create the worktree myself with `git worktree add`, and put this at the top of the instructions.

> First print `pwd` and `git branch --show-current`. If they differ from what was specified, report and do nothing. Do not use `git branch -m`.

Having the agent confirm its own location means a mismatch ends in a report instead of a destructive command.

## `git merge --ff-only | tail -1 && cleanup` runs the cleanup even when the merge fails

To bring a worktree branch into main, I used to write this on one line.

```sh
git merge --ff-only feature | tail -1 && echo next
```

Where `next` stands, I had the worktree removal and a note saying the branch was merged. Here is what happens when main has moved ahead and a fast-forward is impossible (reproduced in a small repository, Git 2.54).

```text
$ git merge --ff-only feature | tail -1 && echo next
hint: Diverging branches can't be fast-forwarded, you need to either:
(omitted)
fatal: Not possible to fast-forward, aborting.
next
```

The merge failed with `fatal`, yet `next` is printed. The exit status of a pipeline is that of its last command, and `tail` succeeds. In real use I wrote `2>&1 | tail -1`, so the screen showed only one `fatal` line. Right after it the worktree was gone and the notes said the branch was merged.

With `set -o pipefail`, the pipeline reports the failing command instead.

```text
$ (set -o pipefail; git merge --ff-only feature | tail -1 && echo next; echo "exit=$?")
(hint and fatal output)
exit=128
```

`next` is not printed, and the exit status is the merge's 128. Still, I did not settle on `pipefail`. It is simpler not to pipe a command whose failure I want to see. I now split it in two.

```sh
git merge --ff-only feature
echo "merge exit=$?"
```

I read the exit status, confirm the merge with `git log -1`, and only then clean up in a separate run. If a fast-forward is not possible, I redo it with a normal merge.

## DerivedData grew with every worktree and filled the disk

xcodebuild creates a separate folder under `~/Library/Developer/Xcode/DerivedData` for each project path. Each new worktree has a new path, so every build run adds a folder. Removing the worktree leaves its DerivedData behind.

On 9 September 2026 my Mac warned that the disk was almost full. At that time `DerivedData` was 613 GB, and it held 265 folders for this app (`FirnPlanner-<hash>`), at 2 to 3 GB each. Today it holds 15, and the whole `DerivedData` is 39 GB. I only read the list of names and checked sizes with `du`; I deleted nothing.

To deal with it, I started deleting DerivedData when I remove a worktree. At first I used this command to delete folders not touched in the last two hours:

```sh
find ~/Library/Developer/Xcode/DerivedData -maxdepth 1 -name 'FirnPlanner-*' -mmin +120 -exec rm -rf {} +
```

This does not exclude running builds. I learned that from the review of this post. `-mmin` looks at the modification time of each folder directly under DerivedData. When a build writes inside it, under `Build/` and so on, the parent folder time may not change. A running build that uses a folder created more than two hours ago is still a deletion target.

So I am switching to choosing the DerivedData location per worktree and passing it in:

```sh
xcodebuild ... -derivedDataPath ~/tmp/dd/<worktree-name>
```

The location then tells you which worktree a folder belongs to. I delete it when I remove the worktree, after checking with `pgrep -x xcodebuild` that no xcodebuild is running and that Xcode does not have that worktree open. A time condition can narrow down candidates among leftover folders, but it does not show that a folder is unused.

When I let agents do the cleanup, they sometimes deleted the folders of other agents running at the same time. My instructions now say not to delete DerivedData, and only the parent session does it.

Sharing one DerivedData causes trouble too. When I ran the full test suite in the repository root, it failed four times in a row with `CodeSign failed`, because the Xcode I had open was fighting over the same DerivedData. The root checkout is shared with Xcode, while worktrees have their own folders, which is why it never happened there. Now, when I run it in the root, I pass a separate location with `-derivedDataPath`.

## Splitting the wait and xcodebuild into two steps stalls the agent

In this project, I limit xcodebuild to one run at a time. When a second run used the same DerivedData, the two fought over it and both stopped. So I keep a wrapper that takes a lock and runs them one by one. macOS has no `flock` command, so I wrote it with Python `fcntl.flock`.

```sh
#!/bin/sh
exec python3 -c '
import fcntl, subprocess, sys
with open("/tmp/xb.lock", "w") as f:
    fcntl.flock(f, fcntl.LOCK_EX)
    sys.exit(subprocess.call(sys.argv[1:]))
' "$@"
```

Starting three jobs at once, they ran one after another, two seconds each (I checked with `sleep 2`).

```text
C start 15
C end   17
B start 17
B end   19
A start 19
A end   21
```

Another way of making agents wait also stalled them. When I told an agent to wait until xcodebuild is free and then run it, it set up a Monitor, said it would wait for the notification, and ended its turn. In my environment, a subagent could not receive the notifications of a Monitor or background job it started, and it just stopped. Also, the Bash tool of the Claude Code I used in September 2026 moved a command to the background after 120 seconds when no timeout was given. That is the tool, not the bash shell itself, and I did not record the version at the time. Long xcodebuild runs stalled the same way because of it.

I now chain the wait and the run into one command, and pass the maximum timeout.

```sh
while pgrep -x xcodebuild >/dev/null; do sleep 30; done; ./xb.sh xcodebuild ... test
```

I use `-x` because `pgrep -f` also matches the command line of the waiting shell itself and waits forever. The instructions also say to repeat the same command if the timeout runs out.

## What hurt was the shared things outside the worktree

What hurt in parallel runs was less the code itself and more the parts a worktree does not separate. The starting main and the checkout at the repository root are two of them. The disk and the one-at-a-time build are the others. I needed to decide all of them before handing work to an agent.
