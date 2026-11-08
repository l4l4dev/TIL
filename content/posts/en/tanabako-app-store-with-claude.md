---
title: 'I let AI take a personal iOS app to the App Store, and only made the decisions and final checks myself'
description: 'I shipped Tanabako, a book reader for iPhone Duo, to the App Store with Claude Code and Claude in Chrome. Development took a few days, and the store work itself took about one day. This post records how work was split between AI and me, what I learned preparing the store listing, and where I got stuck.'
lang: en
translationKey: tanabako-app-store-with-claude
publishDate: 2026-11-08
tags: ['iOS', 'App Store', 'AI', 'Claude Code']
draft: false
---

I built [Tanabako](https://apps.apple.com/jp/app/tanabako/id6830099962), a personal app for reading my own books on iPhone Duo. It became available on the Japanese App Store on November 6, 2026. I left everything from implementation to store submission to AI, and only made the decisions and the final checks myself. Development took a few days, and the work of putting it on the App Store took about one day.

## 190 commits and 42 pull requests in 5 days

I counted the repository up to the November 7 commit that recorded the release.

| Item | Count |
|---|---|
| Commits | 190 |
| Merged pull requests | 42 |
| Tasks (backlog) | 111 |
| Decision records | 11 |
| Design and other documents | 3 |

Commits fall between October 31 and November 4. November 7 has only the one commit that recorded the release. Commits per day:

| Date | Commits |
|---|---|
| 10/31 | 29 |
| 11/1 | 86 |
| 11/2 | 13 |
| 11/3 | 57 |
| 11/4 | 4 |
| 11/7 | 1 |

All 42 merged pull requests have a review from Codex.

## Claude Code built and recorded, and I chose and approved

The work was split like this:

- Claude Code: writes the code and UI tests, the tasks, the decision records and the how-to documents. Code goes from a work branch into a pull request, and is merged after a Codex review
- Claude in Chrome: enters the product page text, screenshots, price, age rating answers and so on in App Store Connect
- Me: choosing between options, approving answers, operating anything only my own account can do, and the final checks

Putting code through pull requests and Codex reviews is itself one of the decision records.

For the product page text, Claude Code wrote three options, A, B and C, and I chose B. I entered the contact for App Review and the declarations I answer as the account holder myself.

## Many store questions could be answered by reading the code

Some of the questions in App Store Connect have answers that follow from how the app is built.

For App Privacy (whether the app collects data), Claude Code checked the code and the privacy manifest before answering. The only outside service Tanabako talks to is Dropbox, which users connect themselves. The Wi-Fi transfer feature runs an HTTP server on the device with `NWListener` and only receives files from a browser on the same LAN. No data reaches the developer, so with my approval the answer was that the app does not collect data.

Screenshots are taken by UI tests: 5 each for the closed iPhone Duo screen and the iPhone 18 Pro screen. The status bar time is fixed at 9:41, and the sample books are ones with no rights issues. When the screens change, I can rerun the tests instead of taking the screenshots again by hand.

The age rating questionnaire was "None" or "No" in all 7 steps, which gave 4+. The privacy policy and support pages are on GitHub Pages from a public repository, and support requests come in through GitHub Issues.

## What took time was the procedures outside the app

The slow part was the procedures outside the code.

For the Dropbox integration, the app I first created in the Dropbox developer console was not made with my personal account, so I recreated it there. After that, connecting from another account showed "This app has reached its user limit". Apps in development can only be connected by a limited number of users, and after allowing additional users (up to 500), the connection worked. Following Dropbox guidance, I will apply for production status once the app has about 50 users.

App Store Connect also has several declarations and checks that the account holder answers. I did not have Claude in Chrome fill these in. I checked their content and answered them myself.

For uploading builds, I decided to use Xcode 27.3 beta for daily development and the release version of Xcode only for uploading to App Store Connect. The app does not use encryption subject to export regulations, so `ITSAppUsesNonExemptEncryption` is set to `NO` in Info.plist.

## Handing everything over for speed was a good experience

This time I put speed before details and tried handing the whole thing to AI. I got as far as the App Store in a few days, and it was a good experience. From here, I plan to adjust the details as I use the app. English support and distribution outside Japan are also left as next steps.

## Summary

- Development ran from October 31 to November 4, with 190 commits and 42 merged pull requests, all reviewed by Codex
- Claude Code handled implementation and records, Claude in Chrome handled input in App Store Connect, and I did the choosing, approving, operations only I could do, and final checks
- App Privacy and screenshots could be settled from the code and UI tests. What took time were procedures outside the app, such as the Dropbox account and its user limit, and the declarations the account holder answers
