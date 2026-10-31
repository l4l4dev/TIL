---
title: 'Xcode 27.2 から書き出せる Apple 公式のエージェントスキルで、iPhone Duo で崩れそうな所を洗い出した'
description: 'xcrun agent skills export で、Apple 公式の AI エージェント向けスキルを 11 本書き出せる。そのうち app-resizability を読ませて開発中の iPhone 版を点検したら、決め打ちの幅、画面全体を基準にしたキーボードの判定、1 回だけ読んだ safe area など、Duo の開閉で崩れそうなコードが 4 件と、まだ確かめていない姿勢が見つかった。'
lang: ja
translationKey: apple-agent-skills-duo-audit
publishDate: 2026-10-31
tags: ['Xcode', 'iOS', 'AI', 'Claude Code']
draft: false
---

個人で作っている1日プランナー [FirnPlanner](https://firnplanner.l4l4.dev/) では、いま iPhone 版を開発していて、折りたたみの iPhone Duo にも合わせています。実装もレビューも AI のコーディングエージェント (Claude Code) と進めています。そこで、Apple が配っているエージェント向けのスキルを読ませて、iPhone 版を点検してもらいました。

## Xcode から、Apple 公式のスキルを 11 本書き出せる

Xcode 27.2 の `xcrun` には `agent skills export` があり、Apple が書いた AI エージェント向けのスキル (手順と参考資料の Markdown) をフォルダに書き出せます。

```sh
$ xcrun agent skills export ~/apple-skills
$ ls ~/apple-skills
adopt-c-bounds-safety
app-intents-specialist
app-intents-whats-new-27
app-resizability
audit-xcode-security-settings
building-document-based-swiftui-applications
device-interaction
modernize-tests
swiftui-specialist
swiftui-whats-new-27
xctrace
```

Claude Code の場合は、`~/.claude/skills/` に置けば、作業の内容に合わせてエージェントが読み込みます。

## Duo の点検には app-resizability を使う

Duo に関係するのは `app-resizability` です。説明には、Duo の対応を頼まれたら全部の項目を点検するように、と書いてあります。開閉で画面の大きさが変わると、どの古い書き方も一度に表に出るから、という理由です。

項目は 5 つの参考資料に分かれていました。

| 参考資料 | 見るもの |
|---|---|
| `uiscreen-task.md` | `UIScreen.main` を基準にした大きさ |
| `safe-area-task.md` | 固定のバーの高さ、1 回だけ読んだ safe area、手で計算したキーボードの位置 |
| `orientation-task.md` | 縦か横かでの分岐 |
| `idiom-task.md` | iPhone か iPad かでの分岐 |
| `scene-lifecycle-task.md` | シーンを使わない古い起動の流れ |

このスキルは、本来は見つけた所をその場で書き換える作りです。今回はコードを変えずに、直す所を挙げてもらうだけにしました。直すかどうかは 1 件ずつ決めたかったからです。

## 見つかったのは、コードの 4 件と、まだ見ていない姿勢の 1 件

挙がったのは次の 5 件です。1〜4 件目は、画面の大きさが変わらない前提で書いたコードです。どれもまだ実機で崩れたのを見たわけではなく、Duo の開閉で崩れる恐れがある所です。5 件目はコードではなく、まだ確かめていない姿勢です。

1. **畳むか開くかを、幅 600pt で切り替えていた。** Duo を開いて横にすると、システムが画面の左右どちらかに縦のバーを置くことがあり、その分だけ使える幅が減ります。開いた画面でも 600pt を割って、畳んだときの形になる恐れがあります
2. **キーボードが出たかを、画面全体と比べて決めていた。** 開閉でウィンドウの大きさが変わると、画面全体とウィンドウが一致しなくなります
3. **キーボードの上の入力バーが、幅を 1 回だけ読んでいた。** 出したまま開閉すると、古い幅が残ります。左右の safe area も無視していたので、縦のバーの下にボタンが入る恐れがあります
4. **`UIApplication.shared` から、最初のウィンドウを探していた。** ログイン画面を出す元と、キーボードを閉じる処理です。スキルは、手近なビューやシーンから取るようにしています
5. **3 つの姿勢 (閉じる、開いて縦、開いて横) と、半分折った形を、まだ見ていなかった**

1 件目は、こういう形です (説明用に新しく書いた例です)。

```swift
// 幅で切り替える
GeometryReader { proxy in
    if proxy.size.width >= 600 {
        SplitLayout()
    } else {
        StackLayout()
    }
}
```

直し方の候補の 1 つは、size class で切り替える形です。

```swift
@Environment(\.horizontalSizeClass) private var sizeClass

var body: some View {
    if sizeClass == .regular {
        SplitLayout()
    } else {
        StackLayout()
    }
}
```

ただし、これは 600pt の判定をそのまま置き換えたものではありません。size class は画面の種類を表す印で、使える幅を約束するものではないからです。regular のときに 2 列の形で幅が足りるかは、Duo の姿勢ごとに撮って確かめる必要があります。

2 件目は、キーボードの枠を `UIScreen.main.bounds` と比べる書き方です。iOS 27 の SDK で型チェックすると、`UIScreen.main` は iOS 26 から非推奨だという警告が出ます。警告の文面も、ウィンドウのシーンから画面を取るように勧めていました。

```swift
// 画面全体と比べる
return frame.minY < UIScreen.main.bounds.maxY
```

スキルのおすすめは `keyboardLayoutGuide` です。通知で受け取るなら、キーボードの枠を自分のビューの座標に直してから比べます。

```swift
guard let screen = view.window?.windowScene?.screen else { return false }
let local = view.convert(frame, from: screen.coordinateSpace)
return local.intersects(view.bounds)
```

## safe area は「横向きのときだけのもの」ではなかった

意外だったのは、3 件目の根拠です。`safe-area-task.md` には、左右の safe area は横向きのときの一時的なものではない、と書いてあります。機種や形によっては、システムが左右のどちらかに縦のバーを置き、それが左右の safe area として届きます。そして、大きさが変わらなくても safe area は変わり得るので、1 回読んで覚えておくと、最初の変化から先はずれたままになります。

iPhone は縦で使うものと思っていたので、左右の safe area はノッチのある横向きのときだけ気にすれば足りる、と考えていました。Duo では、その前提が崩れます。

## Mac 版には swiftui-specialist も効いた

同じ日に、Mac 版を `swiftui-specialist` で点検してもらいました。こちらは Duo と関係なく、次の 4 件が出ました。

- `@State` に `private` が付いていない。スキルの `dataflow.md` によると、`@State` のマクロが初期値の式 (`= Store()` など) を最初の 1 回だけ評価するのは、getter が `private` か `fileprivate` のときだけです。そうでないと、ビューの値が作られるたびに式が評価されます
- 日付の `DateFormatter` を、呼ぶたびに作っている
- `ForEach` の行の識別を、位置 (`\.offset`) にしている
- `foregroundColor` など、置き換えが勧められている書き方が残っている

## まとめ

- Xcode 27.2 は `xcrun agent skills export <フォルダ>` で、Apple 公式のエージェント向けスキルを 11 本書き出せる
- Duo の対応には `app-resizability`。決め打ちの幅、`UIScreen.main`、1 回だけ読んだ safe area、`UIApplication.shared` からのウィンドウ探しを、画面の大きさが変わる前提で洗い出せる
- 見つかったのは、コードの 4 件と、まだ確かめていない姿勢。コードはまだ直していない。直すときは、Duo の 3 つの姿勢で撮って、前と後を比べるつもり

確かめた環境: Xcode 27.2 (27B52)、macOS 27.2。点検そのものは 27.2 RC から書き出したスキルで行いました。
