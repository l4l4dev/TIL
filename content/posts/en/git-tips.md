---
title: "Useful Git Tips and Tricks"
publishDate: 2025-04-03T09:30:00+09:00
lang: en
translationKey: git-tips
description: "Useful Git commands and workflows."
draft: false
categories: ["Development"]
tags: ["git", "version-control", "productivity"]
---


Today I learned some useful Git commands and workflows that have improved my productivity.

## 1. Git Aliases

Git aliases allow you to create shortcuts for commonly used commands:

```bash
[alias]
  co = checkout
  br = branch
  ci = commit
  st = status
  unstage = reset HEAD --
  last = log -1 HEAD
  visual = !gitk
```

## 2. Interactive Rebase

Interactive rebase is powerful for cleaning up your commit history:

```bash
git rebase -i HEAD~3
```

This opens an editor where you can:
- `pick` - Use the commit as is
- `reword` - Change the commit message
- `edit` - Pause to amend the commit
- `squash` - Combine with previous commit
- `fixup` - Like squash, but discard the commit message
- `drop` - Remove the commit

## 3. Git Stash

Stash uncommitted changes when you need to switch context:

```bash
git stash save "Work in progress on feature X"

git stash list

git stash pop

git stash apply stash@{2}
```

## 4. Git Hooks

Git hooks are scripts that run automatically when certain Git events occur. They're stored in the `.git/hooks` directory.

For example, a pre-commit hook can run tests or linting before allowing a commit.

## 5. Git Log Visualization

```bash
git log --oneline --graph --decorate

git log -p

git log --stat
```

These tips have made my Git workflow much more efficient!
