---
title: 'iPhone Duo のシミュレーターは、Duo 専用の iOS ランタイムでしか作れない'
description: 'Xcode 27.2 で iPhone Duo のシミュレーターを作ろうとしたら、iOS 27.0 でも、ふつうの iOS 27.2 でも Incompatible device で失敗した。Duo には機種専用のランタイムがあり、識別子に機種の ID が付いている。見分け方と、simctl でできないこと。'
lang: ja
translationKey: iphone-duo-simulator-runtime
publishDate: 2026-10-31
tags: ['Xcode', 'iOS', 'Simulator', 'AI']
draft: false
---

個人で作っている1日プランナー [FirnPlanner](https://firnplanner.l4l4.dev/) では、いま iPhone 版を開発していて、折りたたみの iPhone Duo にも合わせています。実機は手元に無いので、確かめるのはシミュレーターです。テストやビルドは AI のコーディングエージェント (Claude Code) がコマンドラインで回すので、Duo のシミュレーターも `xcrun simctl` で作ろうとしました。ここで 2 回つまずきました。

## iOS 27.2 のランタイムがあるのに、Duo を作れない

機種の一覧には、Xcode 27.2 を入れた時点で iPhone Duo が出ます。

```sh
$ xcrun simctl list devicetypes | grep Duo
iPhone Duo (com.apple.CoreSimulator.SimDeviceType.iPhone-Duo)
```

ところが、入っている iOS 27.0 のランタイムを指定して作ると失敗します。

```sh
$ xcrun simctl create duo com.apple.CoreSimulator.SimDeviceType.iPhone-Duo \
    com.apple.CoreSimulator.SimRuntime.iOS-27-0
An error was encountered processing the command (domain=com.apple.CoreSimulator.SimError, code=403):
Incompatible device
```

機種の定義を JSON で見ると、対応する OS の下限が 27.1.0 になっていました。

```sh
$ xcrun simctl list devicetypes -j | grep -B3 '"name" : "iPhone Duo"'
      "modelIdentifier" : "iPhone19,4",
      "minRuntimeVersionString" : "27.1.0",
      "minRuntimeVersion" : 1769728,
      "name" : "iPhone Duo"
```

ここまでは分かりやすい話です。分かりにくかったのは、iOS 27.2 のランタイムを指定しても同じ「Incompatible device」で失敗したことでした。

```sh
$ xcrun simctl create duo com.apple.CoreSimulator.SimDeviceType.iPhone-Duo \
    com.apple.CoreSimulator.SimRuntime.iOS-27-2
Incompatible device
Unable to create a device for device type: iPhone Duo (...), runtime: iOS 27.2 (27.2 - 24B8117) - com.apple.CoreSimulator.SimRuntime.iOS-27-2
```

## Duo のランタイムは、識別子の末尾に機種の ID が付いている

`simctl list runtimes` には「iOS 27.2」が何本も並んでいて、名前だけでは区別が付きません。識別子まで見ると、末尾に `-iPhone19-4` が付いたものがありました。`iPhone19,4` は、上で見た Duo の機種の ID です。

```sh
$ xcrun simctl list runtimes | grep 'iOS 27'
iOS 27.0 (27.0 - 24A434) - com.apple.CoreSimulator.SimRuntime.iOS-27-0
iOS 27.1 (27.1 - 24A94401) - com.apple.CoreSimulator.SimRuntime.iOS-27-1
iOS 27.2 (27.2 - 24B114) - com.apple.CoreSimulator.SimRuntime.iOS-27-2
iOS 27.2 (27.2 - 24B91016s) - com.apple.CoreSimulator.SimRuntime.iOS-27-2-iPhone19-4
```

(手元には beta や RC の分も残っているので、実際にはもっと多く並びます。)

ランタイムごとに、作れる機種の数を数えてみました。

| ランタイムの識別子 | 作れる機種 |
|---|---|
| `iOS-27-0` | 62 機種 (Duo は入らない) |
| `iOS-27-1` | iPhone Duo だけ |
| `iOS-27-2` | 63 機種 (Duo は入らない) |
| `iOS-27-2-iPhone19-4` | iPhone Duo だけ |

数えたのは、`simctl list runtimes -j` の `supportedDeviceTypes` です。iOS 27.2 では、Duo だけが別のランタイムに分かれていました。手元の iOS 27.1 も、作れる機種は Duo だけです。

<!-- 図: ふつうの iOS 27.2 では Duo を作れず、専用のランタイム (iOS-27-2-iPhone19-4) では作れる。図は別に用意して、ここに日英で同じものを入れる -->

なので、Duo を作るときは機種専用のランタイムを指定します。識別子を渡すと、作ったシミュレーターの UDID が返ってきます。

```sh
$ xcrun simctl create duo com.apple.CoreSimulator.SimDeviceType.iPhone-Duo \
    com.apple.CoreSimulator.SimRuntime.iOS-27-2-iPhone19-4
CAA756E8-69C3-4762-BA55-9F10F10130CD
```

ランタイムを省いても、simctl が専用のものを選んでくれました。

```sh
$ xcrun simctl create duo com.apple.CoreSimulator.SimDeviceType.iPhone-Duo
No runtime specified, using 'iOS 27.2 (27.2 - 24B91016s) - com.apple.CoreSimulator.SimRuntime.iOS-27-2-iPhone19-4'
```

スクリプトに書くときは、上のように識別子を明示するのが確実です。名前の「iOS 27.2」では選ばないでください。名前で選ぶと、ふつうの 27.2 に当たって失敗することがあります。

## 開閉と回転は simctl ではできない

作れたあとで、もう 1 つ詰まりました。Duo は、閉じた形 (外の画面)、開いて縦、開いて横で画面の形が変わります。どの形でも画面が崩れないかを撮りたかったのですが、`simctl` には形を変えるサブコマンドがありません。`simctl ui` で変えられるのは外観 (ライト / ダーク)、コントラストを上げる設定、文字の大きさだけです。

```sh
$ xcrun simctl ui
...
Supported Options:
    appearance
    increase_contrast
    content_size
```

閉じた形はそのまま撮れました。開いた 2 つの形は、Simulator.app で開いて回す必要があります。エージェントに任せていた撮影のうち、ここだけは人の手が要るので、まだ撮れていません。

## まとめ

- iPhone Duo のシミュレーターは、iOS 27.1 以上で、かつ Duo 専用のランタイムでしか作れなかった。iOS 27.2 では識別子の末尾が `-iPhone19-4` のもの
- 名前は同じ「iOS 27.2」なので、選ぶときは識別子を見る。ランタイムを省くと専用のものが選ばれる
- 開閉と回転は `simctl` に無い。開いた形の確認は Simulator.app で行う

確かめた環境: Xcode 27.2 (27B52)、macOS 27.2。
