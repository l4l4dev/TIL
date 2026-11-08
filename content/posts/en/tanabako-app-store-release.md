---
title: 'Shipping a personal iOS app to the App Store, split between Claude Code and me'
description: 'I submitted Tanabako, an iOS app for reading books, five days after starting it, and it went live on day seven. The release prep was split into seven tasks. An AI agent filled in App Store Connect and uploaded the build, and I handled sign-in, consent, personal info, and the submit button. This post covers that split, the tools, and where I got stuck.'
lang: en
translationKey: tanabako-app-store-release
publishDate: 2026-11-08
tags: ['Xcode', 'iOS', 'AI', 'Claude Code']
draft: false
---

I shipped [Tanabako](https://apps.apple.com/jp/app/tanabako/id6830099962), an iOS app that puts your own PDFs and zip files of images on a shelf for reading. I started it on 2026-10-31, installed it on my device through TestFlight on 11-03, submitted it for review on 11-04, and it went live in Japan on 11-06. It passed review on the first submission.

An AI coding agent, Claude Code, did most of the implementation and most of the release prep. I took the operations that need my own information, the "Submit for Review" button, and the checks on a real device. This post describes how the work was split, the tools I used, and where I got stuck.

![How the release prep was split. Claude Code filled in App Store Connect, captured and uploaded screenshots, archived and uploaded the build, entered review notes and picked the build, and drafted the App Privacy answers. I signed in, accepted terms, entered the contact info and DSA status, pressed the submit button, and checked the app on a device through TestFlight. I made the decisions and Claude Code entered them.](/TIL/images/app-store-split-en.svg)

## From the first commit to review took five days

Here is the size of the work. I counted the app repository from 10-31, when I started, to 11-04, when I submitted.

| Item | Count |
|---|---|
| Commits | 189 |
| Merged PRs | 42 |
| Tests (Swift Testing) | 316 |

Including the November 7 commit recording the release brings the total to 190 commits. At that later cutoff, the repository also had 111 Backlog.md tasks, 11 decision records, and 3 design and other documents. These figures use a different cutoff from the 189 commits in the table.

Code goes on a work branch. All 42 merged PRs had a Codex review on GitHub. Claude Code checks each finding, fixes it, and carries the PR to the merge.

Checks that need a human looking at the screen are batched. When a task is implemented and its tests pass, Claude Code marks it Done without waiting for me. My checks are grouped into tasks titled "確認: ..." (check: ...), and after the work is merged to main I follow the steps written in them. In an app I built before, the rule was that nothing moved on until I had checked and approved. For Tanabako I changed that one rule from the start.

## The tools

| Purpose | Tool |
|---|---|
| Implementation, research, App Store Connect work | Claude Code. One session sees the whole project and hands implementation and research to other agents |
| Tasks and decisions | Backlog.md (a CLI that keeps tasks as Markdown files) |
| Code review | GitHub PRs and Codex |
| Working in the App Store Connect and Dropbox web pages | Claude in Chrome (a Chrome extension that lets Claude Code operate the browser) |
| Screenshots | XCUITest and `xcrun simctl status_bar` |
| Uploading the review build | `xcodebuild archive` and `xcodebuild -exportArchive` |
| Privacy policy and support page | A public repository on GitHub Pages |

The task records live in the repository so that when a session ends, the next one can pick up where it stopped. I also had Claude Code write in the task notes what it entered in App Store Connect, and whether the value was still there after a reload. Support requests go through GitHub Issues.

## The release prep was split into seven tasks

Once the app was on TestFlight, I made a parent task, "publish on the App Store", and split the prep into subtasks.

1. Set up the privacy policy and support pages
2. Decide and enter the App Privacy answers
3. Prepare the screenshots
4. Decide the product page text, price, and age rating
5. Get the Dropbox app ready for release
6. File the EU Digital Services Act (DSA) trader status
7. Submit for review

Each subtask splits differently between what I decide and what Claude Code does. For App Privacy, Claude Code read the code and `PrivacyInfo.xcprivacy` and listed every outgoing connection. The only external service it connects to is the user's own Dropbox, and there is no analytics or crash reporting SDK. Wi-Fi transfer uses an HTTP server on the device through `NWListener` to receive files from a browser on the same LAN. The app does not send data to the developer. From that it proposed answering "Data Not Collected". I approved, and then Claude Code published the answers. For the product page text, I picked from options A, B, and C, and Claude Code entered my choice. All seven steps of the age-rating questionnaire were answered "None" or "No", resulting in a 4+ rating.

The screenshots were taken by UI tests: five for the closed iPhone Duo display and five for iPhone 18 Pro. The sample books shown in them were generated by the test code, and the status bar was fixed at 9:41 with `simctl status_bar`. According to the guidance in App Store Connect, adding iPhone Duo screenshots puts a Duo badge on the product page.

## I kept the outward-facing actions and my own information

Before working in App Store Connect, I decided which parts Claude Code would handle.

| Claude Code | Me |
|---|---|
| Entering the text, keywords, category, price, and regions | Signing in to App Store Connect and Dropbox |
| The age rating questionnaire, the App Privacy answers (content approved by me) | Accepting terms |
| Uploading screenshots | The App Review contact and the DSA status |
| Entering review notes and picking the build | The "Submit for Review" button |
| Archiving and uploading the build | Checking the app on a device through TestFlight |

There were two reasons for drawing the line here. First, I did not want an AI handling my own information, such as passwords, contact details, and what goes into the DSA filing. Second, I wanted to press any button that changes what others can see, such as submitting, myself. Claude Code's auto mode also blocked the submit action and the push to the public repository. I ran the support page push myself by typing it with a `!` prefix in the Claude Code prompt.

Even for values that Claude Code types in, such as price and regions, I make the decision. Claude Code proposes options with reasons, and enters the one I pick.

## Where I got stuck was Apple and Dropbox accounts

I was stopped more often by account and registration state than by code.

### The bundle ID was taken by my free team, so I renamed the app

When I went to upload to TestFlight, the bundle ID for the first name, Gatefold, was already registered to my free development team (Personal Team). A paid team cannot use it, and a free team cannot delete the registration. The app was not public yet, so I changed the app name to Tanabako along with the bundle ID. Before suggesting name candidates, Claude Code searched the App Store, products with the same name, and US trademarks on the web.

### The Dropbox app was recreated under my personal account

To import books from Dropbox, the app has an entry in the Dropbox developer console. While fixing the display name during release prep, I found that the Dropbox app had been created under an account that was not my personal one. I created it again under my personal account, swapped the key embedded in the app, and confirmed that a TestFlight build could connect.

A Dropbox app is either in development or in production. At first the plan included applying for production. The application page said that an app in development can connect up to 500 users, and that the review does not happen until the app is linked with 50 users. So I shipped without applying, and will apply when the number of connected users approaches 50.

### A Japan-only release still asked for DSA trader status

Version 1.0 ships only in Japan. App Store Connect still asked whether I am a trader under the EU DSA. The filing is made by the holder of the Apple Developer Program account, so I entered it myself.

### App Store Connect sometimes drops values you thought you saved

I had Claude Code reload the page after every save and check that the value was still there. Right after moving to a new page, elements sometimes cannot be found and the action fails. When that happened, Claude Code waited a little and read the page text again.

## The review notes explain how to try the app without signing in

Tanabako has no accounts, and nothing shows until you import a book file. So that the reviewer would not have to prepare files, I put a sample PDF and zip on the support page. The review notes, in English, explain how to open that page in Safari, save the files to the Files app, and import them with the "+" button in the app. They also say that connecting Dropbox is not needed for review, and that the app does not use the network while reading.

It was approved about two days after submission. The release was set to automatic, so it went live right away.

## For the next app, I turned the steps into a Claude Code skill

After the whole release, I wrote the process down as a Claude Code skill, a Markdown file describing how to do a job. It covers:

- How to split the subtasks
- What Claude Code does and what I do
- Where things are in App Store Connect, and tips for working in it
- The build and upload commands
- How to write review notes
- What to do after a rejection

Next time I ship a different app, I can say "I want to put this on the App Store", and Claude Code will read this skill before starting.

There is one thing to watch for when uploading. Day to day I develop with a beta Xcode, but App Store Connect does not accept builds made with a beta Xcode. Only the build I upload is made with the release Xcode, selected with `DEVELOPER_DIR`. That is in the skill too. For export compliance, I confirmed the app does not use encryption subject to the declaration and set `ITSAppUsesNonExemptEncryption` to `NO` in Info.plist.

I prioritized speed and handed most of the work to AI. After launch, I plan to refine the details as I use the app. English localization and distribution outside Japan are future steps.
