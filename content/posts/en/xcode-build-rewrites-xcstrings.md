---
title: 'Building in Xcode can reorder a whole .xcstrings file'
description: 'Building from the Xcode window rewrites a .xcstrings file only when the String Catalog and the strings in code disagree. It writes the keys in its own order, so a file written in another order gets a large diff. xcodebuild did not rewrite it. A git clean filter removes the order-only diff.'
lang: en
translationKey: xcode-build-rewrites-xcstrings
publishDate: 2026-10-31
tags: ['Xcode', 'Git', 'Swift']
draft: false
---

While working on [FirnPlanner](https://firnplanner.l4l4.dev/), I only built the app in Xcode, and `git status` showed `.xcstrings` files (String Catalogs) as modified. Most of the diff was keys changing places.

I used a new project to find out when the file gets rewritten.

## It is rewritten only when code and catalog disagree

I made an app with 4 strings such as `Text("Today")` and added a catalog with Japanese translations. After committing the catalog to git, I compared `xcodebuild` on the command line with a build from the Xcode window.

| Catalog state | `xcodebuild` | Build from the Xcode window |
|---|---|---|
| Matches the strings in code (even with keys in reverse order) | No change | No change |
| A string exists only in code | No change | Adds the key and reorders the whole file |
| A string was removed from code | No change | Adds `"extractionState" : "stale"` and reorders the whole file |

When the keys matched, Xcode did not touch the file, even if the order was different from its own. It rewrites the file only when it has a key to add or mark. Then it writes the whole file in its own order, so in a file with a different order, adding one line spreads the diff over the whole file.

`xcodebuild` did not rewrite the catalog in any of these cases.

## How Xcode orders and formats the file

The file Xcode wrote looked like this.

- Keys are in character code order. Uppercase comes first, so `"Zebra"` comes before `"all done"`
- There are spaces around `:` (`"Today" : {`)
- A key without translations is written as `{` and `}` with an empty line between, not `{}`
- There is no newline at the end of the file

A catalog written by hand or exported by a tool can differ from this in order or format.

## Removing the order-only diff with a git clean filter

To remove diffs that only change the order, I added a filter that sorts the keys before git stores the file.

```python
#!/usr/bin/env python3
# git clean filter: sort the keys of a .xcstrings file before git stores it
import json, sys

catalog = json.load(sys.stdin)
json.dump(catalog, sys.stdout, ensure_ascii=False, indent=2,
          sort_keys=True, separators=(",", " : "))
```

```sh
echo '*.xcstrings filter=sort-xcstrings' >> .gitattributes
git config --local filter.sort-xcstrings.clean "python3 scripts/sort-xcstrings.py"
git add --renormalize .
```

`git config --local` is per repository, so set it in every clone.

When I rewrote the catalog with its keys in reverse order, `git status` showed ` M`, but `git diff` was empty. The content is the same, so `git add -u` clears it. The only difference between the file Xcode wrote and the output of this filter was how a key without translations is written as `{}`.

## A stale mark: removed on purpose, or by accident

`"extractionState" : "stale"` means Xcode can no longer find the key in code. If you really removed the string, remove it from the catalog too. If you only changed the code so that Xcode cannot pick it up, change it back to a form Xcode can find.

## Summary

- Building from the Xcode window rewrites a `.xcstrings` file that disagrees with the code, and reorders the whole file in Xcode's order
- `xcodebuild` did not rewrite it
- A git clean filter that sorts the keys removes the order-only diff

Tested with: Xcode 27.2 (27B52) on macOS 27.2.
