---
title: 'Do not trust a "same output" speedup until you run both versions and diff them'
description: 'An AI agent sped up the editor decoration code without changing its output, and all 241 existing tests passed. A reviewer agent ran the old and new versions side by side and found 4 differences. The cause: Swift Regex \d matches full-width digits. What I checked, and how to diff two versions.'
lang: en
translationKey: swift-regex-digit-and-diff-both-versions
publishDate: 2026-10-01
tags: ['Swift', 'Testing', 'AI']
draft: false
---

I build [FirnPlanner](https://firnplanner.l4l4.dev/), a daily planner for macOS, as a personal project, and an AI coding agent writes most of the implementation. Recently I asked an agent to speed up the decoration calculation in the Markdown editor, with one condition: the output must not change by a single byte.

The agent came back with all 241 existing tests passing. Then I had a different agent run the old and new versions and compare them, and it found inputs where the output differed.

## All tests passed, but the output had changed

The change replaced regular expressions that ran on every line with a cheap pre-check and a hand-written scan. For numbered lists, for example, it first looks at whether the line starts with a digit, and only then examines the line closely.

I asked a reviewer agent not just to read the code but to run it. It built a small executable that loads both the old and the new package, feeds in the same text, dumps every field of the result, and diffs the dumps. It found 4 differences in 2 groups.

- An indented line right after a code block: the old version treated it as part of the code block, while the new version attached it to a task before the code block
- Lines with full-width digits (`１. item` or `２０２６-０８-２３`): the old version recognized them as numbered lists or dates, and the new version did not

None of these inputs were in the tests, whose expected values were written by hand.

## Swift Regex \d matches full-width digits

The second group comes from `\d` in the original regular expression. The new pre-check assumed that `\d` matched only ASCII `0-9`, and looked only at ASCII digits. A small script settles it.

```swift
let fw = "１２. item"
let ascii = "12. item"
let a = try! Regex(#"^\d+\."#)
let b = try! Regex(#"^[0-9]+\."#)
let c = try! Regex(#"^\d+\."#).asciiOnlyDigits()
for (name, r) in [("\\d", a), ("[0-9]", b), ("\\d + asciiOnlyDigits()", c)] {
    print(name, "fullwidth:", fw.firstMatch(of: r) != nil, "ascii:", ascii.firstMatch(of: r) != nil)
}
```

The output:

```text
\d fullwidth: true ascii: true
[0-9] fullwidth: false ascii: true
\d + asciiOnlyDigits() fullwidth: false ascii: true
```

`\d` matches the full-width `１２`. To limit it to ASCII, write `[0-9]` or add `.asciiOnlyDigits()`. The code even had a comment and a test saying full-width digits were out of scope, which contradicted the original behavior.

There are two ways to fix it: send only the lines that contain non-ASCII digits back to the original regular expression, or change the spec to "ASCII only". Since the condition was no change in output, I took the first.

## Diff two versions with SwiftPM path dependencies

![Run both versions on identical inputs, dump every output field, and compare the files with diff](/TIL/images/compare-outputs-en.svg)

Generalized, the procedure looks like this. Put the version before and the version after in separate directories.

```text
old/        the package before the change (Lib)
new/        the package after the change (Lib)
dump-old/   an executable that loads old
dump-new/   an executable that loads new
```

The two `Package.swift` files for the executables differ in exactly two places. In `dump-new`, change both `.package(path: "../new")` and `.product(name: "Lib", package: "new")` to `new`. A path dependency gets its package name from the directory name (`old` / `new`), so if you change only the path and leave `package: "old"`, the build stops with `unknown package 'old'`.

```swift
// dump-old/Package.swift
// swift-tools-version:5.9
import PackageDescription
let package = Package(
    name: "dump",
    platforms: [.macOS(.v13)],
    dependencies: [.package(path: "../old")],
    targets: [.executableTarget(name: "dump", dependencies: [.product(name: "Lib", package: "old")])]
)
```

Each `main.swift` is the same source: a list of inputs, and a print of every result. Then you only diff the output.

```sh
(cd dump-old && swift run -q dump > ../old.txt)
(cd dump-new && swift run -q dump > ../new.txt)
diff old.txt new.txt
```

I tried it on a small example (replacing a numbered-list check with a version that first looks at a leading ASCII digit), and only the full-width input showed up.

```text
2c2
< "１２. a" true
---
> "１２. a" false
```

I confirmed this setup works with SwiftPM on macOS. Any input that differs shows up directly in the diff.

## Put boundary cases in the inputs

A diff only finds differences in the inputs you feed it. The differences here came from boundary inputs.

- Block boundaries (the lines right after the start and end of a code block)
- Full-width and other non-ASCII characters
- Empty lines
- The start and end of a document

I added inputs mixing these, which brought the verification to 28 cases. After the fix, I diffed again, got zero differences, and only then merged.

## Run both versions when you replace a pure function

Passing tests is not evidence that the output is unchanged, because tests only cover inputs their author thought of. When I replace a pure function such as a parser or an aggregation without changing its result, I now do two things.

- Run the old and new versions for real and compare every field of the output on the same inputs
- Put boundary examples into the inputs on purpose

This matters more when an AI agent does the implementation. This time too, the implementing agent brought the change back as "output unchanged" because the tests passed. A review that only reads the code also misses a wrong assumption like the behavior of `\d`. I now ask the reviewer explicitly to run both versions and compare.
