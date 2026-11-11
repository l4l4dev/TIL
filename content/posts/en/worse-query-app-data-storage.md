---
title: 'Reviewing how your iOS app stores data after the worse_query sandbox escape PoC'
description: 'worse_query, published on 2026-11-08, is a PoC that lets an app with an App Group container access files in other apps containers. It is not a WebView bug. It needs a malicious app to be installed and run, and it is not a jailbreak. This post lists what app developers should review: plaintext secrets, WebView data, and how purchase state is stored.'
lang: en
translationKey: worse-query-app-data-storage
publishDate: 2026-11-11
tags: ['iOS', 'Security']
draft: false
---

On 2026-11-08, an iOS sandbox escape PoC called worse_query was published on GitHub. It lets an app installed on the device access files in other apps' containers. A crypto exchange and a security firm issued warnings, so it spread as a wallet story, but the impact is not limited to wallets. Anything an app keeps in plaintext in its container may be readable by another app. That makes it a good moment to review how your own app stores data.

This post summarizes public information as of 2026-11-11. I have not run the PoC myself.

## worse_query lets an app with an App Group container access other apps' files

According to the [worse_query README](https://github.com/forcequitOS/worse_query), it targets iOS 26.0 through 26.7.2 and iOS 27.2. The README calls it a proof of concept for developers that is not useful by itself. To use it, the app that embeds it needs an App Group container. It is the successor to [bad_query](https://github.com/forcequitOS/bad_query), which the same author published in August.

The README lists the paths it can access.

```
/var/containers/Data/System (iOS 27)
/var/containers/Shared/SystemGroup/* (iOS 27)
/var/mobile/Containers/Data/Application/*
/var/mobile/Containers/Data/InternalDaemon/*
/var/mobile/Containers/Data/PluginKitPlugin/*
/var/mobile/Containers/Shared/AppGroup/*
/var/mobile/Containers/Shared/AppGroup (iOS 27)
```

For app developers, the important ones are `Data/Application/*` and `Shared/AppGroup/*`. The first holds each app's data container (where Documents, Library, and tmp live). The second holds App Group containers that an app shares with its widgets and extensions. `PluginKitPlugin/*` holds extension containers.

The README does not explain the mechanism further. The comments in the source show that it uses a query to containermanagerd, the system daemon that manages containers, for the location of an App Group container. It is not a bug in WebView or any particular framework, so files in the container are exposed the same way in apps that never use a WebView. The repository also includes pathleak, a helper that works out the paths of other apps' containers by brute-forcing inode numbers, which is how an attacking app finds the containers to target.

## It requires a malicious app to be installed and run

worse_query does not take over a device on its own. An app that embeds it has to be installed on the device and run. The README states plainly that it "is not relevant to a jailbreak and never will be."

The [alert from the security firm SlowMist](https://x.com/SlowMist_Team/status/2120045378792010166) reads it the same way. It is a container sandbox escape, not a jailbreak. An app that exploits it can reach system paths and read or modify other apps' data. The bug does not steal assets by itself, and the risk starts when a user installs an app from an untrusted source, such as a sideloaded IPA. The [warning from the exchange Binance](https://x.com/binance/status/2120093246399430770) says it "allows malicious apps to read local files from other apps" and that "this is an iOS-level issue, not unique to Binance."

The author has said this directly on X: worse_query "would absolutely be exploitable from an App Store app," and an attacker "would just have to pass App Review" ([post](https://x.com/forcequitOS/status/2120249200478961791), 2026-11-11). App Groups are a standard capability for App Store apps, so the prerequisite can be met. In the same post, the author pointed to FomoPeek, a malicious app that passed App Review and was later analyzed by SlowMist, as a precedent that review is not a guarantee. Whether any app distributed through the App Store has actually used worse_query is still not confirmed.

## As of 2026-11-11, Apple has not announced a fix

Apple released iOS 27.2.1 and iOS 26.7.3 on 2026-11-09. Neither security note ([27.2.1](https://support.apple.com/en-us/149715), [26.7.3](https://support.apple.com/en-us/149716)) has an entry for worse_query or the sandbox, and neither mentions containermanagerd. The fixes are for Bluetooth, AirPlay, Messages, and other components.

The author has stated this directly on X: worse_query is "not patched in iOS 27.2.1 and 27.3 beta 1," and the README's supported versions will be updated when it is patched ([post](https://x.com/forcequitOS/status/2120125653085270418), 2026-11-10).

SlowMist's alert recommends keeping iOS up to date and installing Apple's fix as soon as one is released. That is advice to install a fix when it ships. It does not say that 27.2.1 fixed the bug, so it is safer not to read it as "updating to 27.2.1 protects you."

Sources also list the affected versions differently. The README says 26.0 through 26.7.2 and 27.2, while Binance names 26.7.1, 27.0.1, and 27.2.

For scale, the predecessor bad_query lists iOS 26.0 through 26.6.1 and iOS 27.0 beta 4 as its targets in its README, and iOS 26.7 is not among them.

## What developers should review is anything kept in plaintext in the container

Whenever a fix arrives, what app developers can act on now is what their app stores on the device and how. The sandbox is what protects a container from other apps. The question is what would hurt if that assumption failed.

### Put secrets in the keychain, not in files

Check whether login tokens, API keys, or wallet private keys and recovery phrases are stored in plaintext in files or in `UserDefaults`. `UserDefaults` is saved as a plist in the container's `Library/Preferences`. SQLite, Core Data, and SwiftData stores, and any file written to `Documents` or `Caches`, are in the container too.

Put secrets in the keychain. Keychain items are not files in a container; they are managed by the system's security daemon. The README's list of accessible paths does not include where the keychain is stored either. That is a statement about this PoC, not a guarantee about future variants. Use the keychain, and also reduce how many secrets you keep on the device at all.

For large data that has to live in files, one option is to encrypt it with CryptoKit or similar and keep only the key in the keychain.

File protection classes (Data Protection) encrypt files while the device is locked. My understanding is that they do not stop another app that is running while the device is in use from reading the files. Do not assume that adding a protection class prevents this kind of read.

### WebView data also stays in the app container

SlowMist and its CISO 23pds, in [a separate post](https://x.com/im23pds/status/2119985290907656563), list wallets that keep WebView caches in plaintext as at risk. The reason is not a WebView bug. The data WebView saves also goes into the app container.

With the default data store (`WKWebsiteDataStore.default()`), `WKWebView` saves cookies, localStorage, IndexedDB, and caches inside the container. Session cookies from a login, and tokens the web side put in localStorage, remain there as files.

For screens that do not need to keep anything, you can use a data store that does not persist.

```swift
let config = WKWebViewConfiguration()
config.websiteDataStore = .nonPersistent()
let webView = WKWebView(frame: .zero, configuration: config)
```

For screens that do need persistence, consider measures on both the web and app sides, such as clearing data with `removeData(ofTypes:modifiedSince:)` on logout and not putting long-lived tokens in localStorage.

### Do not decide purchase state from a flag on the device

If your app stores a flag like `isPro = true` in `UserDefaults` and enables paid features based on that alone, now is the time to review it. If other apps' data can be modified as SlowMist describes, this flag can be changed from outside. The same was already possible on jailbroken devices before worse_query.

With StoreKit 2, you can check `Transaction.currentEntitlements` at launch and decide whether to enable paid features from transactions signed by the App Store. Use a local flag only as a cache for fast display, and re-derive the real state from the transactions.

```swift
for await result in Transaction.currentEntitlements {
    if case .verified(let transaction) = result,
       transaction.productID == "pro_monthly" {
        // Enable paid features
    }
}
```

If your server gates features, decide with purchase state verified on the server side.

### The same applies to App Group containers

App Group containers, used to share data with widgets and extensions, are also in the README's list. Check what you keep there with the same standard as the app's own container.

## What you can tell users

On the app side, the work is reviewing how data is stored. When users ask through support, the advice from SlowMist and Binance applies as is: do not install apps from unknown sources, delete any you have installed, and keep iOS up to date and install the fix when it ships. SlowMist also recommends that if an untrusted app was installed on a device holding a wallet, you move assets to a new wallet created on a clean device.

## What I could not confirm

- Whether any app distributed through the App Store has exploited worse_query
- Whether Apple has fixed worse_query or plans to

## Summary

- worse_query is a PoC that lets an app with an App Group container access files in other apps' containers. It requires a malicious app to be installed and run, and it is not a jailbreak
- As of 2026-11-11, Apple's security notes do not list a fix
- App developers should review plaintext secrets in the container, WebView data, and purchase state decided only by a flag on the device

## Sources

- [forcequitOS/worse_query](https://github.com/forcequitOS/worse_query) (README and source, published 2026-11-08)
- [forcequitOS/bad_query](https://github.com/forcequitOS/bad_query) (the predecessor)
- [The author's announcement](https://x.com/forcequitOS/status/2119475139528020218) (X, 2026-11-08)
- [SlowMist alert](https://x.com/SlowMist_Team/status/2120045378792010166) (X, 2026-11-10)
- [Post by 23pds (SlowMist)](https://x.com/im23pds/status/2119985290907656563) (X, 2026-11-10)
- [Binance warning](https://x.com/binance/status/2120093246399430770) (X, 2026-11-10)
- [Apple: About the security content of iOS 27.2.1 and iPadOS 27.2.1](https://support.apple.com/en-us/149715)
- [Apple: About the security content of iOS 26.7.3 and iPadOS 26.7.3](https://support.apple.com/en-us/149716)
- [The author on the patch status](https://x.com/forcequitOS/status/2120125653085270418) (X, 2026-11-10)
- [The author on App Store apps](https://x.com/forcequitOS/status/2120249200478961791) (X, 2026-11-11)
