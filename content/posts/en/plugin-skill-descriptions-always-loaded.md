---
title: 'Plugin skill descriptions are loaded every turn, and too many skills get their descriptions dropped'
description: 'Installing the Xcode 27.3 beta plugin in Claude Code added 19 skills with about 10,500 characters of descriptions. Skill descriptions are loaded into context every turn, and when the listing goes over its budget, descriptions are dropped. Skills I had copied by hand with the same names were in the listing too.'
lang: en
translationKey: plugin-skill-descriptions-always-loaded
publishDate: 2026-11-08
tags: ['Xcode', 'AI', 'Claude Code']
draft: false
---

I installed the official Xcode plugin (`xcode@claude-plugins-official`) in Claude Code. It was exported from Xcode 27.3 beta 1 and contains 19 skills. For a skill, only its name and description (the `description` in the frontmatter) are loaded up front, and the body is loaded when the skill is invoked. Since the body takes no space until it is used, I thought installing skills cost nothing. It turned out that the descriptions are loaded every turn, and with too many skills, descriptions get dropped.

## Skill descriptions are in context every turn

According to the Claude Code documentation, Claude sees a listing of skill names and descriptions every turn. Claude reads the descriptions to decide which skill to invoke on its own. The listing has a budget, which by default is 1% of the context window. Over the budget, all names are kept, but descriptions are dropped starting from the least-used skills. A skill without a description can still be invoked by name, but Claude is less likely to pick it on its own.

So each skill you install uses context for its description on every turn, and once the listing goes over the budget, some of the installed skills become less likely to be invoked.

## The 19 descriptions added up to about 10,500 characters

The plugin contents are exported for each Xcode build. `xcrun agent plugin path --plugin-format claude` prints where they are. I took `description` from the frontmatter of each `skills/*/SKILL.md` there and counted the characters.

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

27.3 beta has 3 more skills, but the total is slightly shorter than in 27.2. The longest description is 963 characters, below the length at which a single skill's description is cut (1,536 characters).

## I estimate that 9 of them were shown by name only

In the session where I checked, I estimate that 9 of the 19 skills were shown by name only, without a description. This is an estimate. The frontmatter was fine, so I think the listing went over the budget and descriptions were dropped. However, I did not confirm which skills were affected in Claude Code logs or in `/context`.

## Skills I had copied by hand were in the listing too

Before installing the plugin, I had copied some of the Xcode skills into `~/.claude/skills` by hand. Looking for ones with the same names as the plugin skills, I found 6.

```sh
for d in "$(xcrun agent plugin path --plugin-format claude)"/skills/*/; do
  n=$(basename "$d"); [ -d ~/.claude/skills/"$n" ] && echo "$n"
done
```

Of the 6, only 1 was identical to the 27.3 beta plugin. 2 were identical to the 27.2 plugin, and the other 4 matched neither version. According to the documentation, plugin skills are named `plugin-name:skill-name`, so they are treated as separate from the skills I placed by hand. Skills for the same purpose were in the listing twice, adding more descriptions.

## Summary

- A skill body is loaded when it is invoked, but its description is loaded every turn
- When the listing goes over its budget, descriptions are dropped starting from the least-used skills, and Claude is less likely to invoke them on its own
- The Xcode 27.3 beta 1 plugin has 19 skills with 10,503 characters of descriptions
- In the session I checked, I estimate that 9 were shown by name only. I think this was because of the budget, but it is an estimate
- I had 6 hand-copied skills with the same names, and they were in the listing along with the plugin skills

I tested with:

- Claude Code 2.1.319
- Xcode 27.3 beta 1 (27C5020n) and Xcode 27.2 (27B52)

References:

- [Extend Claude with skills](https://code.claude.com/docs/en/skills) (Claude Code documentation)
- [Settings reference](https://code.claude.com/docs/en/settings-reference) (Claude Code documentation)
