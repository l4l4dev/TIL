---
title: 'There is only one git stash across all worktrees'
description: 'Two AI agents used git stash at the same time in separate git worktrees, and their uncommitted changes swapped places. The cause is that refs/stash exists once per repository. How to reproduce it, and what I use instead.'
lang: en
translationKey: git-stash-across-worktrees
publishDate: 2026-10-01
tags: ['Git', 'git worktree', 'AI', 'Claude Code']
draft: false
---

I build [FirnPlanner](https://github.com/l4l4dev/FirnPlanner), a daily planner for macOS, as a personal project, and most of the implementation is done by an AI coding agent (Claude Code). Several worker agents run at the same time, each in its own git worktree. Each worktree has its own working tree and its own branch, so I assumed they could not get in each other's way.

`git stash` turned out to be the exception. Two agents stashed and popped at almost the same moment, and one agent's uncommitted changes showed up in the other agent's worktree.

## What happened

I had given two tasks to two agents in parallel: a fix to the sync merge, and an unrelated task. Partway through, both wanted to set their local changes aside for a moment, so both ran `git stash`, did some work, and then ran `git stash pop`.

One worktree ended up with the other task's changes. I noticed when one agent tried to restore the other agent's worktree and stopped at a permission prompt. In the end I had the agent that owned the changes reapply its own patch. Nothing was lost, but if nobody had noticed, unrelated changes would have been committed into the wrong PR.

## refs/stash is shared by the whole repository

The REFS section of `git help worktree` says so directly:

> In general, all pseudo refs are per-worktree and all refs starting with refs/ are shared. (...) There are exceptions, however: refs inside refs/bisect, refs/worktree and refs/rewritten are not shared.

Only pseudo refs such as `HEAD`, and refs under `refs/bisect`, `refs/worktree` and `refs/rewritten`, are per-worktree. The `refs/stash` that `git stash` uses lives under `refs/`, so every worktree shares the same one. The stack of entries (`stash@{0}`, `stash@{1}`, ...) is the reflog of that single ref.

`git stash pop` does not check which worktree an entry came from. It applies the top entry, `stash@{0}`, to whichever worktree you are in. If two agents push and pop in turn, each can pop the other's entry.

## Reproducing it

Create two worktrees and stash in each:

```sh
git init -b main repo && cd repo
echo base > a.txt && echo base > b.txt
git add . && git commit -m init
git worktree add -b task-a ../wt-a
git worktree add -b task-b ../wt-b

# Stash in worktree A
cd ../wt-a && echo "work in A" >> a.txt && git stash push -m "A's stash"
# Then stash in worktree B
cd ../wt-b && echo "work in B" >> b.txt && git stash push -m "B's stash"

# Back in A, pop
cd ../wt-a
git stash list
git stash pop
```

From worktree A, both entries are listed:

```text
stash@{0}: On task-b: B's stash
stash@{1}: On task-a: A's stash
```

Popping applies B's change (`b.txt`) to worktree A:

```text
On branch task-a
Changes not staged for commit:
	modified:   b.txt
```

In worktree B, `git stash list` now shows only A's entry. If B pops there, it receives A's changes. `git rev-parse --git-path refs/stash` points to the same `.git/refs/stash` from both worktrees (checked with Git 2.54).

One person switching between worktrees rarely hits this, because they remember where they stashed. It becomes likely when several agents run in parallel through worktrees, because each one touches the same stack without seeing the others.

## Using WIP commits instead

The git section of every instruction I give to a worker agent now includes this line:

> Do not use git stash. If you need to set changes aside, make a WIP commit.

Branches are separate per worktree, so no other worktree will pop a commit on your branch. WIP commits are squashed before the PR.

If you really want stash-shaped entries, you can keep them under `refs/worktree/`, which is per-worktree. `git stash create` makes the stash commit without pushing it onto `refs/stash`:

```sh
c=$(git stash create "A's stash")
git update-ref refs/worktree/wip "$c"
git reset --hard
# ...work...
git stash apply refs/worktree/wip
```

Running `git rev-parse refs/worktree/wip` from another worktree did not find it. I don't use this, though. Saying "don't use stash" is simpler than getting an agent to write these steps correctly every time.

## When changes do get swapped

If a swap happens, the agent that owns the worktree restores it. Another agent, or the coordinating session, does not touch someone else's worktree in its place. This time, the agent that tried to restore the other worktree stopped at the permission prompt. Handing the diff to the owner and letting it reapply the patch makes it easier to follow what went back where.

Worktrees give you separate working trees, but most of what is inside `.git` is shared. Besides the stash, tags and remote-tracking branches are shared too. Before running work in parallel, it's worth reading the REFS section of `git help worktree` once to see what is shared.
