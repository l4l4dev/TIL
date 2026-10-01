---
title: '「出力は変えない」高速化は、両方を動かして diff するまで信用しない'
description: 'エディタの装飾計算を速くする変更で、既存テストは全部通っていたのに、検証役のエージェントが新旧を両方動かして比べたら出力の差が 4 件見つかった。原因は Swift Regex の \d が全角数字にもマッチすること。確かめた結果と、新旧を並べて diff する手順。'
lang: ja
translationKey: swift-regex-digit-and-diff-both-versions
publishDate: 2026-10-01
tags: ['Swift', 'Testing', 'AI']
draft: false
---

個人で作っている macOS の1日プランナー [FirnPlanner](https://github.com/l4l4dev/FirnPlanner) では、実装の大半を AI のコーディングエージェントに任せています。先日、Markdown エディタの装飾計算を速くする変更を、エージェントに頼みました。条件は「出力を 1 バイトも変えない」ことです。

エージェントは既存のテスト 241 件をすべて通して持ってきました。それでも、別のエージェントに新旧を両方動かして比べさせたところ、出力が違う入力が見つかりました。

## テストが全部通っても、出力は変わっていた

変更の中身は、全行に掛けていた正規表現を、先に条件で絞る前判定と手書きの走査に置き換えるものです。たとえば番号付きリストの判定は、行頭が数字かどうかを先に見て、数字のときだけ詳しく調べます。

検証役のエージェントには、コードを読むだけでなく、実際に動かして比べるよう頼みました。この検証役は、変更前の版と変更後の版の両方を読み込む小さな実行ファイルを作り、同じ本文を渡して、結果を全項目ダンプして diff を取っています。差は 4 件、2 系統ありました。

- コードブロックの直後にある字下げ行が、変更前はコードブロックの内側として扱われるのに、変更後はコードブロックより前のタスクの子として扱われた
- 全角数字を含む行 (`１. item` や `２０２６-０８-２３`) が、変更前は番号リストや日付として認識されるのに、変更後は認識されなかった

どちらも、手で書いた期待値のテストには入っていない入力でした。

## Swift Regex の \d は全角数字にもマッチする

後者の原因は、元の正規表現の `\d` にあります。新しい前判定は、`\d` が ASCII の `0-9` だけにマッチする前提で、ASCII の数字だけを見る形で書かれていました。小さなスクリプトで確かめます。

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

出力は次のとおりです。

```text
\d fullwidth: true ascii: true
[0-9] fullwidth: false ascii: true
\d + asciiOnlyDigits() fullwidth: false ascii: true
```

`\d` は全角数字の `１２` にマッチします。ASCII だけにしたいときは `[0-9]` と書くか、`.asciiOnlyDigits()` を付けます。「全角数字は対象外」というコメントとテストまで書かれていましたが、元の挙動とは食い違っていました。

直し方は 2 つ考えられます。元の挙動に合わせて、非 ASCII の数字を含む行だけ元の正規表現に回す方法と、仕様として「ASCII だけ」に変える方法です。今回は出力を変えないことが条件だったので、前者にしました。

## 新旧の版を path dependency で並べて diff する

![同じ入力を新旧の版に渡し、全項目の出力をファイルに保存して diff で比較する手順](/TIL/images/compare-outputs-ja.svg)

検証の手順は、一般化するとこうなります。置き換える前と後を、別々のディレクトリに置きます。

```text
old/   変更前のパッケージ (Lib)
new/   変更後のパッケージ (Lib)
dump-old/   old を読む実行ファイル
dump-new/   new を読む実行ファイル
```

`dump-old` と `dump-new` の `Package.swift` は、依存先を指す 2 か所だけが違います。`dump-new` では、`.package(path: "../new")` と `.product(name: "Lib", package: "new")` の両方を `new` に変えます。パスから付く package の名前はディレクトリ名 (`old` / `new`) なので、パスだけ変えて `package: "old"` を残すと、`unknown package 'old'` でビルドが止まります。

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

`main.swift` には、同じ入力の一覧を書いて、結果を全部印字させます。2 つの実行ファイルは同じソースにして、あとは出力を diff するだけです。

```sh
(cd dump-old && swift run -q dump > ../old.txt)
(cd dump-new && swift run -q dump > ../new.txt)
diff old.txt new.txt
```

上のような小さな例 (番号の判定を、先頭の ASCII 数字で絞る版に置き換えたもの) で試すと、全角の入力だけが差として出ました。

```text
2c2
< "１２. a" true
---
> "１２. a" false
```

手元の環境 (macOS 上の SwiftPM) で、この形が動くことを確かめています。差の出る入力があれば、そのまま diff に出ます。

## 入力には境界を入れる

diff は、入れた入力の範囲でしか差を見つけられません。今回差が出たのは、境界にあたる入力でした。

- ブロックの境界 (コードブロックの開始行・終了行の直後)
- 全角や非 ASCII の文字
- 空行
- 文書の先頭と末尾

これらを混ぜた入力を足して、検証のケースを 28 件にしました。直した版で再度 diff を取り、差が 0 件になってから取り込んでいます。

## 純関数の置き換えは、両方を動かして比べる

既存のテストが通ることは、出力が同じであることの証拠にはなりません。テストは、書いた人が思いついた入力しか見ていないからです。解析や集計のような純関数を、結果を変えずに置き換えるときは、次の 2 点を決めています。

- 新旧の版を両方実際に動かして、同じ入力の出力を全項目比べる
- 入力に、境界の例を意図して入れる

AI のエージェントに実装を任せるときは、もっと効きます。今回も実装したエージェントは、テストが通ったことを根拠に「出力は変わらない」として持ってきました。コードを読むだけの検証でも、`\d` の挙動のような前提の誤りは見落とします。検証役には「両方を動かして比べてほしい」と、はっきり頼むようにしています。
