---
title: 'SwiftUI の #Preview が出ないのは、Debug でも -O でビルドされていたからだった'
description: '個人で作っている SwiftUI のアプリで #Preview が描画されなかった。ENABLE_PREVIEWS は最初から YES で、原因は SWIFT_OPTIMIZATION_LEVEL をどこにも書いていなかったことだった。書かないと Debug でも -O でビルドされる。xcconfig に 1 行追加すると直ったが、Xcode を開き直すまで反映されなかった。'
lang: ja
translationKey: swiftui-preview-needs-onone
publishDate: 2026-11-08
tags: ['Xcode', 'SwiftUI']
draft: false
---

個人で作っている SwiftUI のアプリで、`#Preview` が描画されませんでした。最初は `ENABLE_PREVIEWS` が `NO` になっているのだろうと考えましたが、外れでした。原因は、Swift の最適化レベル (`SWIFT_OPTIMIZATION_LEVEL`) をどこにも書いていなかったことでした。

## ENABLE_PREVIEWS は最初から YES だった

プレビューが出ないとき、最初に疑ったのは `ENABLE_PREVIEWS` です。ところが、アプリのターゲットでは最初から `YES` になっていました。

## SWIFT_OPTIMIZATION_LEVEL を書いていないと、Debug でも -O になる

ビルド設定を見ると、`SWIFT_OPTIMIZATION_LEVEL` がプロジェクトにもターゲットにも xcconfig にも書かれていませんでした。このアプリはビルド設定を xcconfig にまとめていますが、Debug の `-Onone` はそこにも入っていませんでした。書かれていないと Xcode の既定の値が使われ、Debug の構成でも `-O` でビルドされます。プレビューを描画するには、最適化なし (`-Onone`) でビルドされている必要があります。

Debug でも `-O` になることは、別に作った小さなプロジェクトで確かめました。最適化レベルを書いていないプロジェクトを、Debug で iOS シミュレーター向けにビルドしました。ビルドのログで、Swift のコンパイラーに渡されたフラグを数えます。

```sh
xcodebuild -project PrevLab.xcodeproj -scheme PrevLab -configuration Debug \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath dd build > build.log 2>&1
grep -E 'swift-frontend|swiftc|SwiftDriver' build.log | grep -oE ' -O(none|size|unchecked)?( |$)' | sort | uniq -c
```

最適化レベルを書いていないときは、6 か所すべてが `-O` でした。`xcodebuild -showBuildSettings` でも、`SWIFT_OPTIMIZATION_LEVEL` は一覧に出ず、`IS_UNOPTIMIZED_BUILD` は `NO` でした。

| 最適化レベルの書き方 | コンパイラーに渡ったフラグ | `IS_UNOPTIMIZED_BUILD` |
|---|---|---|
| どこにも書かない | `-O` (6 か所) | `NO` |
| xcconfig に Debug だけ `-Onone` を書く | `-Onone` (6 か所) | `YES` |

Xcode で新しく作ったプロジェクトでは、プロジェクトのビルド設定に Debug の `-Onone` が入っています。ビルド設定を xcconfig に移したり、プロジェクトを作り直したりしてこの行が消えると、同じことが起きます。

## xcconfig に 1 行追加して直した

`Configs/Base.xcconfig` に次の 1 行を追加しました。Debug の構成のときだけ `-Onone` になります。

```text
SWIFT_OPTIMIZATION_LEVEL[config=Debug] = -Onone
```

Release は既定の `-O` のままです。

## Xcode を開いたままでは、xcconfig の変更が反映されなかった

xcconfig を書き換えても、Xcode を開いたままでは、プレビューを描画する処理 (RenderPreview) に変更が反映されませんでした。ワークスペースを閉じて開き直すと描画できました。なぜ開き直すまで反映されなかったのかは、調べていません。xcconfig を変えてもプレビューが変わらないときは、一度ワークスペースを開き直すとよさそうです。

開き直した後、`ContentView` の `#Preview` は、ライトとダークの 2 つの条件で描画できました。確かめた後、設定の変更は元に戻しています。

## まとめ

- `#Preview` が出ないとき、`ENABLE_PREVIEWS` が `YES` でも、最適化レベルが `-O` だと描画できなかった
- `SWIFT_OPTIMIZATION_LEVEL` をどこにも書いていないと、Debug でも `-O` でビルドされる
- xcconfig に `SWIFT_OPTIMIZATION_LEVEL[config=Debug] = -Onone` を追加すると直った
- xcconfig の変更は、Xcode でワークスペースを開き直すまで、プレビューに反映されなかった

確かめた環境は次のとおりです。

- Xcode 27.3 beta 1 (27C5020n)
- iOS 27.3 シミュレーター向けのビルド
