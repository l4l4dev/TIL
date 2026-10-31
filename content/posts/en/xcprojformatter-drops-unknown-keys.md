---
title: 'xcprojformatter silently drops keys it does not know'
description: 'In an Xcode 27 JSON project file (project.xcproj), a one-letter typo in "build-settings" makes xcodebuild ignore those settings without an error. xcprojformatter does not complain either; it removes the block from its output. Diffing the formatter output against the file catches this typo.'
lang: en
translationKey: xcprojformatter-drops-unknown-keys
publishDate: 2026-10-31
tags: ['Xcode']
draft: false
---

[FirnPlanner](https://firnplanner.l4l4.dev/) keeps its project in git in the JSON format that Xcode 27 introduced (`FirnPlanner.xcodeproj/project.xcproj`). Unlike `project.pbxproj`, it is readable, so editing it by hand is tempting. But when I made a typo in a hand edit, none of the tools told me.

I checked this in a new project with Xcode 27.2 (27B52).

## The test project

I used `xcrun xcodeproj` to create one command-line tool target and gave the target only `SWIFT_ACTIVE_COMPILATION_CONDITIONS`.

```json
"targets": [
  {
    "name": "Hello",
    "product-type": "tool",
    "build-phases": [
      "compile-sources",
    ],
    "build-settings": {
      "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "GREETING",
    },
  },
],
```

`main.swift` only prints whether the condition is set.

```swift
#if GREETING
print("GREETING is set")
#else
print("GREETING is not set")
#endif
```

Building and running it prints `GREETING is set`.

## A typo in "build-settings" still builds

I changed the target's `"build-settings"` to `"build-setings"`.

```sh
$ xcodebuild -project Demo.xcodeproj -target Hello build
** BUILD SUCCEEDED **
$ ./build/Debug/Hello
GREETING is not set
```

There is no warning and no error. The unknown key is skipped, and the build succeeds without the condition.

Reading the setting with `xcrun xcodeproj` only says it is not set.

```sh
$ xcrun xcodeproj setting get -P Demo.xcodeproj SWIFT_ACTIVE_COMPILATION_CONDITIONS --target Hello
SWIFT_ACTIVE_COMPILATION_CONDITIONS (single) on target 'Hello' (raw, unevaluated — direct from the .xcodeproj):
  Debug: (unset)
  Release: (unset)
```

When the same block also held `PRODUCT_NAME`, the build stopped with `error: Multiple commands produce '.../build/Debug'`. The product name had become empty, but that error does not point you to a misspelled key.

## xcprojformatter removes the block

Xcode 27.2 includes `xcrun xcprojformatter`, which formats this file. Running it with `--update` on the file with the typo exited with 0, printed nothing, and removed the whole block.

```diff
       "build-phases": [
         "compile-sources",
       ],
-      "build-setings": {
-        "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "GREETING",
-      },
     },
```

If you run the formatter to tidy up the file, the misspelled settings are simply lost.

## Catch it with a diff against the formatter output

Without `--update`, the formatter prints the formatted file to standard output. Comparing that with the file shows the dropped keys as a diff.

```sh
xcrun xcprojformatter Demo.xcodeproj | diff -u Demo.xcodeproj/project.xcproj -
```

On the file before the hand edit, the diff was empty and the exit code was 0. With the `"build-setings"` typo, it showed the same removal as above and exited with 1. FirnPlanner has this in a script that runs after hand edits to the JSON.

This diff only tells you whether the formatter output matches the current file. It does not check that the project is valid.

- It does not catch a misspelled setting name. Changing `SWIFT_ACTIVE_COMPILATION_CONDITIONS` to `SWIFT_ACTIVE_COMPILATION_CONDITION` leaves the diff empty, because any key name inside `"build-settings"` is kept. The build also succeeds
- Formatting differences that are not typos, such as whitespace, also produce a diff. Changing `"build-settings": {` to `"build-settings":{` was enough

What it catches is a structural key that xcprojformatter does not know, like the one in this post.

Instead of editing the JSON by hand, you can also use commands such as `xcrun xcodeproj setting set`. The command writes the structural keys, so this kind of typo cannot get in. It writes the setting name as you pass it, so that part is still up to you.

## Summary

- In an Xcode 27 `project.xcproj`, unknown keys are silently ignored by both xcodebuild and `xcrun xcodeproj`
- `xcrun xcprojformatter --update` silently removes unknown keys
- `xcrun xcprojformatter <project> | diff -u <project>/project.xcproj -` catches typos in structural keys. It does not catch misspelled setting names, and formatting-only changes also show up, so it is not a full validator
