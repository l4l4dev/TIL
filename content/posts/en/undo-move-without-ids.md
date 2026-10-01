---
title: 'Undoing a move in Markdown without IDs: restore if nothing changed, otherwise do nothing'
description: 'To undo a task moved from the Inbox Markdown file to a day page, I had to point at the one task that was moved. I rewrote that four times, and each guess deleted an unrelated line when its clue broke. The final version restores only when the file is exactly as the move left it.'
lang: en
translationKey: undo-move-without-ids
publishDate: 2026-10-01
tags: ['Design', 'Markdown', 'AI']
draft: false
---

I build [FirnPlanner](https://github.com/l4l4dev/FirnPlanner), a daily planner for macOS, as a personal project, and it keeps tasks in Markdown files. There is one file per day, and tasks without a date go into a single file called `Inbox.md`.

Moving a task from the Inbox to a day page can be undone. How to point at "the one task that was moved" in that undo took four rewrites. The conclusion is: restore if the file is exactly as the move left it. If even one character differs, change nothing and say so.

## The moved task cannot be identified by its content

Say the Inbox looks like this (an example).

```markdown
- [ ] Write up the notes
- [ ] Buy milk
- [ ] Write up the notes
```

If I move the first "Write up the notes" to today's page, two lines remain in the Inbox. To undo, I remove the task from today's page and put it back at its original place in the Inbox. But from the Markdown lines alone, I cannot tell whether the task on the day page is the one I just moved, or one the user wrote later with the same title. The same goes for the same-titled line left in the Inbox.

Giving each task an ID would solve it. But a checkbox line is part of a file the user also reads and writes in other editors. Adding IDs to it would pollute the file, so IDs are not an option.

## Each new clue still deleted an unrelated line when it broke

I rewrote the matching four times, changing the clue each time.

- On the Inbox side (which line to put back): first by content, then by the recorded position, and finally by the count of lines with the same content
- On the day page side (whether to restore the placement, meaning time and duration): first by line number, then by the set of titles, and finally by the count of the same title

Every one of them was a guess, and each deleted an unrelated line in the situation where its clue broke. For example, after a move, delete the text added to the Inbox and add the same content somewhere else. The count is back to what it was, so the undo takes the line added elsewhere for the one it moved, and deletes it.

The comments from an AI code review (Codex) pointed the same way every time: keep an identifier. That is reasonable, but as above, the user's Markdown cannot carry one. I concluded that as long as I matched by content, each change of clue would only move the breakage to another situation.

## Undo only when the file is exactly as the move left it

After the fourth round, I stopped trying to find the line. The app remembers the whole Inbox from before and after the move. When undoing, if the current Inbox matches the state right after the move without a single character of difference, it goes back to the state before the move. If not, it changes nothing and steps out. It then shows this message (the app's Japanese text, shown here in English):

> Couldn't undo because Inbox has changed. Nothing was changed.

There is nothing to guess in this form. Because it never searches for a line, it cannot delete an unrelated one, so the wrong deletion is gone. Some situations remain where undo is not possible, but then nothing is changed and the reason is shown.

Placement follows the same idea. If the user touched the placement after the move, it is not restored. Unlike the Inbox, though, the undo as a whole does not step out. A placement mismatch does not duplicate a task, and all that is lost is the time, so the time simply is not restored and the task is auto-placed.

## What I give up: undo after touching the Inbox

This form costs two things.

- If you touch the Inbox after a move, that move can no longer be undone
- When you undo after touching the placement, the time of the moved task is not restored either

For placement, the effect is that changes made after the move stay, and the time of the moved task comes back if you did not touch the placement.

There was another option: put Inbox edits in the same undo history (UndoManager) as other edits. The order is then defined, and the guessing is not needed. But it changes what ⌘Z means. Pressing ⌘Z while typing in the body would bring back an Inbox deletion from a few minutes ago. That is heavy for a fix to an identity bug, so I did not take it. If people keep running into "couldn't undo", I will reconsider.

## In the implementation, take the decision before writing anything

I hit two ordering traps. Both showed up as failing tests.

1. If the placement check is taken after the body is restored, it always says "touched". Restoring the body triggers the code that follows line numbers, which rewrites the placement records, so I can no longer tell whether the user moved something or it moved during the restore
2. If the Inbox check is taken after writing another day's file, then on stepping out only the source side is restored and a duplicate stays in the Inbox

The decision is made before anything is written.

I also nearly made the same kind of hole in placement. If you keep the whole before and after state and write all of it back on undo, a hole appears unless edits in that area are in the same undo history. Dragging and resizing are not, so if you moved other tasks after the move, writing everything back erases those changes. Keeping the whole state is for the identity check only. It does not mean the write-back should cover everything, so the write-back is limited to what was touched.

## For data that cannot hold identifiers, check for a match and step out if it differs

What carries over to your own app:

- When undoing data that cannot hold identifiers, finding the target from content or position always has a situation where the clue breaks, and an unrelated item gets damaged there. Changing the clue only moved the breakage
- Instead of guessing, remember the state right after the operation and check for a match when undoing. If it matches, restore. If not, do nothing
- When it does not match, do not fail silently. Say that nothing was changed
- Take the check before writing. If you check after writing, stepping out leaves a half-done state

It bothers me that there are situations where undo is not possible, but I chose telling the user it cannot be undone over deleting an unrelated line.
