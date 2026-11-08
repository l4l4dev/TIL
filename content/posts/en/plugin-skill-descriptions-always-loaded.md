---
title: 'After installing the Xcode plugin, skill descriptions grew by about 10,000 characters'
description: 'Installing the Xcode 27.3 beta plugin in Claude Code adds 19 skills whose descriptions total 10,503 characters. Descriptions are loaded every turn as a listing, but the listing has a budget, and over it, descriptions of the least-used skills are dropped. 6 skills I had copied by hand with the same names were still there.'
lang: en
translationKey: plugin-skill-descriptions-always-loaded
publishDate: 2026-11-08
tags: ['Xcode', 'AI', 'Claude Code']
draft: false
---

After I installed the official Xcode plugin (`xcode@claude-plugins-official`) in Claude Code, 19 skills were added, and their descriptions total 10,503 characters. A skill body is not loaded until the skill is invoked, so I thought installing skills took no space, but descriptions (the `description` in the frontmatter) are loaded every turn as a listing. The listing has a budget, and once it is exceeded, skills whose descriptions are dropped become less likely to be invoked by Claude. The 10,503 characters are the total of the descriptions on disk. I did not measure how much was actually loaded each turn.

## Description length can be counted from the SKILL.md frontmatter

The plugin contents are exported for each Xcode build, and `xcrun agent plugin path --plugin-format claude` prints where they are. I took `description` from the frontmatter of each `skills/*/SKILL.md` there and counted the characters.

```python
import glob, os, re, sys
import yaml

total = 0
paths = sorted(glob.glob(os.path.join(sys.argv[1], "skills", "*", "SKILL.md")))
for path in paths:
    front = re.match(r"---\n(.*?)\n---", open(path).read(), re.S).group(1)
    total += len(yaml.safe_load(front)["description"])
print(len(paths), "skills,", total, "characters")
```

I switched the Xcode used by `xcrun` with `DEVELOPER_DIR` and counted two versions.

| Xcode | Skills | Total description length |
|---|---|---|
| 27.2 (27B52) | 16 | 11,101 characters |
| 27.3 beta 1 (27C5020n) | 19 | 10,503 characters |

27.3 beta has 3 more skills, but the total is slightly shorter. The longest description is 963 characters.

## 6 of the same skills I had copied by hand were still there

Before installing the plugin, I had copied some of the Xcode skills into `~/.claude/skills` by hand. Looking for ones with the same names as the plugin skills, I found 6.

```sh
for d in "$(xcrun agent plugin path --plugin-format claude)"/skills/*/; do
  n=$(basename "$d"); [ -d ~/.claude/skills/"$n" ] && echo "$n"
done
```

Comparing their contents, 1 was identical to both the 27.3 beta and 27.2 plugins, and 1 more was identical only to the 27.2 plugin. The other 4 matched neither version. According to the documentation, plugin skills are named `plugin-name:skill-name`, so both they and the skills I placed by hand are loaded as separate skills. Descriptions for the same purpose were loaded twice for 6 skills.

## Over the budget, descriptions of the least-used skills are dropped

According to the Claude Code documentation, Claude sees a listing of skill names and descriptions every turn and uses it to decide which skill to invoke on its own. By default, the listing budget is 1% of the context window. Over the budget, all names are kept, but descriptions are dropped starting from the least-used skills. A skill without a description can still be invoked by name, but Claude is less likely to pick it on its own.

In a session after installing the plugin, the following 9 of the 19 skills appeared in the skill listing by name only, without a description.

- swiftui-specialist, swiftui-whats-new-27
- translation, translation-coordinator
- siri-app-integration, siri-evaluations
- xctrace, macos-touch-gestures, building-document-based-swiftui-applications

The frontmatter of these 9 was fine. So I estimate that the listing went over its budget and their descriptions were dropped. I did not confirm that it was over the budget with `/context` or the warning in the debug log.

The more skills you install, the more descriptions are loaded every turn, and once over the budget, some of them become less likely to be invoked.

## `/doctor` and `/context` show how large the listing is

The documentation also describes how to check the size of the listing and how to reduce it. I have not tried any of these yet.

- `/doctor` shows an estimate of the listing size and the skills that take the most. The Skills row in `/context` shows the size after the budget is applied
- Starting with `--debug` writes a warning to the debug log when the listing exceeds its budget
- Setting a skill to `"name-only"` in the `skillOverrides` setting lists it by name without a description

The 6 skills I placed by hand serve the same purpose as the plugin ones, so I think they can be removed.

## Summary

- A skill body is loaded when it is invoked, but its description is loaded every turn as part of a listing. The descriptions of the 19 skills in the Xcode 27.3 beta 1 plugin total 10,503 characters. I did not measure how much was actually loaded each turn
- I had 6 hand-copied skills with the same names, loaded separately from the plugin skills
- When the listing goes over its budget, descriptions are dropped starting from the least-used skills, and Claude is less likely to invoke them on its own. In a session after installing the plugin, 9 appeared by name only. I estimate this was because of the budget

I tested with:

- Claude Code 2.1.319
- Xcode 27.3 beta 1 (27C5020n) and Xcode 27.2 (27B52)

References:

- [Extend Claude with skills](https://code.claude.com/docs/en/skills) (Claude Code documentation)
- [Settings reference](https://code.claude.com/docs/en/settings-reference) (Claude Code documentation)
