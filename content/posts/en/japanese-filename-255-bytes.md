---
title: 'Japanese filenames that work on macOS can exceed 255 bytes on Linux'
description: 'My task manager puts the Japanese task title straight into the filename, and a Linux checkout failed with File name too long. APFS on macOS limits names to 255 characters, while Linux filesystems such as ext4 limit them to 255 bytes. The limits I measured, and how to check before committing.'
lang: en
translationKey: japanese-filename-255-bytes
publishDate: 2026-10-01
tags: ['Git', 'macOS', 'Linux', 'AI']
draft: false
---

I build [FirnPlanner](https://github.com/l4l4dev/FirnPlanner), a daily planner for macOS, as a personal project, and I track its tasks with [Backlog.md](https://github.com/MrLesk/Backlog.md). Each task is one Markdown file named `task-NNN - <title>.md`. The title goes into the filename almost as is, with spaces and a few symbols replaced.

One day an AI code review (Codex) left a P1 comment. The filename of a new task was 272 bytes long, too long for Linux. On my Mac, creating and committing the file had worked without any complaint, so I had no idea until the review said so.

## Codex's comment: git status fails on a Linux checkout

The core of the comment:

> This new filename component is 272 UTF-8 bytes, exceeding the 255-byte `NAME_MAX` used by common filesystems such as ext4. A fresh checkout therefore cannot materialize the task file, and even the current Linux checkout makes `git status` fail with `File name too long`

Codex reviews in a Linux environment. A fresh clone cannot create that file, and even an existing checkout fails on `git status`. CI such as GitHub Actions, or a contributor working on Linux, would hit the same thing.

## APFS allows 255 characters, Linux allows 255 bytes

The difference is in what the limit counts.

Linux filesystems such as ext4 limit each component of a path (each part between `/`) to **255 bytes**. Most Japanese characters take 3 bytes in UTF-8, so a name made only of Japanese characters reaches the limit at 85 characters.

On APFS, the same test shows that the limit counts characters, not bytes. These are the results of `touch`ing names made of repeated `あ` on my machine (macOS 27, APFS):

| Count of `あ` | UTF-8 bytes | Created on APFS? |
| --- | --- | --- |
| 85 | 255 | yes |
| 86 | 258 | yes |
| 255 | 765 | yes |
| 256 | 768 | `File name too long` |

`getconf NAME_MAX .` returns 255 on both. Because they count differently, testing on a Mac never hits the Linux limit.

For a Backlog.md task, `task-NNN - ` and `.md` take about 15 bytes, so a Japanese title goes past 255 bytes at roughly 80 characters. Put the description into the title and you get there.

## On a Mac, commit and push still go through

Git does not check filename length. When I created a file with a 276-byte name, `git add` and `git commit` both went through as usual. GitHub accepts the push too. Things break only when someone checks out that commit on Linux.

If you only work on your own Mac, you never see the problem. This time it surfaced because an AI reviewer running on Linux checked the branch out.

## Count the bytes before committing

Keeping titles short is the best fix. When I create a task now, I keep a Japanese title to about 60 characters and put the details in the description.

To check anyway, count the bytes of each path component in the files git tracks:

```sh
git ls-files -z | python3 -c '
import sys
for p in sys.stdin.buffer.read().split(b"\0"):
    for part in p.split(b"/"):
        if len(part) > 255:
            print(len(part), p.decode())'
```

`-z` keeps Japanese filenames from coming out escaped as `"\343\201\202..."` (the default `core.quotepath` behavior). No output means you're fine. For my 276-byte test file it printed `276 task-1 - 長い題名...`.

For a single name, `printf '%s' "<filename>" | wc -c` is enough. I use `printf` because `echo` also counts the trailing newline.

## When you shorten a title, check that the filename changed too

In the version of Backlog.md I was using then, `backlog task edit --title` changed only the `title` inside the file. The filename stayed long. After changing a title, check that the filename was also renamed by the same rule. For this comment, I shortened the title, brought the filename down to 168 bytes, and also checked that no other file went over 255 bytes.

Even without a Linux machine of your own, if your CI or review environment runs Linux, that is where it will break first. If a tool generates filenames from Japanese text for you, it's worth counting the bytes once.
