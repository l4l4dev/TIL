---
title: 'macOS アプリのユニットテスト中にテストホストが前面に来るのは、.prohibited で止まった'
description: 'xcodebuild test を流すたびに、テストホストとして起動したアプリが前面に来て、作業中のアプリからキー入力を奪っていた。applicationWillFinishLaunching で活性化のポリシーを .prohibited にすると止まり、.accessory では止まらなかった。前面のアプリを記録して確かめた。'
lang: ja
translationKey: test-host-stays-in-background
publishDate: 2026-11-04
tags: ['Xcode', 'macOS', 'Testing']
draft: false
---

個人で作っている macOS の1日プランナー [FirnPlanner](https://firnplanner.l4l4.dev/) では、全件テストを流すたびに、テスト用に起動した FirnPlanner が前面に来ていました。別のアプリで文字を打っていると、その途中で入力先が切り替わります。

ユニットテストは、アプリをテストホストとして起動し、その中でテストを走らせます。前面に来ていたのは、このテストホストです。

## 起動の直前に .prohibited にする

`applicationWillFinishLaunching` で、テストホストとして起動したときだけ、活性化のポリシーを `.prohibited` にしました。

```swift
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            NSApp.setActivationPolicy(.prohibited)
        }
    }
}
```

テストホストとして起動したプロセスには、環境変数 `XCTestConfigurationFilePath` が入ります。ふだんの起動では入らないので、これで見分けています。

Apple のドキュメントでは、`.prohibited` は Dock に出ず、ウィンドウを作らず、活性化もされないアプリです。`.accessory` は Dock に出ないだけで、活性化はされます。

## 前面のアプリを記録して比べた

前面に来なくなったかどうかは、目で見ていても分かりにくいです。前面のアプリの名前を 0.25 秒おきに書き出すスクリプトを、テストと並べて動かしました。

```sh
#!/bin/zsh
# 前面のアプリの名前を 0.25 秒おきに記録する。止めるときは Ctrl-C
while true; do
  name=$(lsappinfo info "$(lsappinfo front)" | head -1 | cut -d'"' -f2)
  print -r -- "$(date +%H:%M:%S) $name"
  sleep 0.25
done
```

テストの間に記録した行のうち、FirnPlanner が前面だった行の数です。

| テストホストの設定 | 記録した行 | FirnPlanner が前面だった行 |
|---|---|---|
| 何もしない | 60 | 4 |
| `.accessory` | 63 | 8 |
| `.prohibited` | 491 | 0 |

`.prohibited` の行は全件テストを最後まで流したときの記録で、ほかの 2 つは途中までの記録です。長さがそろっていないので、`.accessory` のほうが回数が多いことからは何も言えません。言えるのは、`.accessory` では前面に来るのが止まらず、`.prohibited` では全件を流しても一度も前面に来なかった、というところまでです。

`.accessory` で止まらなかった理由は確かめていません。ただ、上のドキュメントにあるとおり `.accessory` のアプリは活性化されうるので、説明と食い違う動きではありません。

## 使えるのはウィンドウの要らないテストだけ

`.prohibited` のアプリはウィンドウを作れません。FirnPlanner のテストは、ビューを `NSHostingView` に入れて画面に出さずに描くだけなので、ウィンドウは要りませんでした。キーウィンドウやウィンドウの重なりを前提にするテストがあるなら、この方法は合いません。

UI テスト (XCUITest) が起動したアプリは、この判定では `.prohibited` になりません。UI テストを流すと、今も前面に来ます。

## 別のデスクトップで流す案は使えなかった

最初は、テストを別のデスクトップ (Space) で流せばよいと考えました。ところが macOS には、アプリに切り替えると、そのアプリのウィンドウがあるデスクトップへ画面を移す設定があり、既定で有効です。有効のままだと、テストホストが前面に来たときに画面ごとそのデスクトップへ移るはずです。かえって邪魔になると考えて、試さずにやめました。

## 落ちやすかった 2 つのテストが 20 回とも通った

対策の後、全件テストを 20 回流すと、それまでときどき落ちていた 2 つのテスト (日付書式の欄の高さと、mermaid の図の幅を見るテスト) が一度も落ちませんでした。前面に来なくなったことと関係があるのかは確かめていません。別のテストは 20 回中 2 回落ちていて、こちらは残っています。

## まとめ

- テストホストが前面に来るのは、`applicationWillFinishLaunching` で `.prohibited` にすると止まった
- `.accessory` では止まらなかった
- ウィンドウを作れなくなるので、ウィンドウの要らないテストに限る

確かめた環境: Xcode 27.2 beta 3 (27B5038j)、macOS 27.2。記録は 2026 年 10 月。
