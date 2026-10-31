---
title: 'xcprojformatter は知らないキーを黙って捨てる'
description: 'Xcode 27 の JSON 形式のプロジェクト (project.xcproj) で "build-settings" を 1 文字打ち間違えると、xcodebuild はエラーを出さずにその設定を無視する。xcprojformatter もエラーを出さず、整形の結果からそのブロックを消す。整形の出力と元のファイルの diff が空かどうかで、打ち間違いを見つけられる。'
lang: ja
translationKey: xcprojformatter-drops-unknown-keys
publishDate: 2026-10-31
tags: ['Xcode']
draft: false
---

[FirnPlanner](https://firnplanner.l4l4.dev/) は、Xcode 27 から使える JSON 形式のプロジェクトファイル (`FirnPlanner.xcodeproj/project.xcproj`) を git に入れています。`project.pbxproj` と違って手で読めるので、手で直したくなります。ただ、手で直したときの打ち間違いは、どのツールも教えてくれませんでした。

新しいプロジェクトで確かめました。環境は Xcode 27.2 (27B52) です。

## 試したプロジェクト

`xcrun xcodeproj` でコマンドラインツールのターゲットを 1 つ作り、ターゲットに `SWIFT_ACTIVE_COMPILATION_CONDITIONS` だけを持たせました。

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

`main.swift` は、条件が付いているかを表示するだけです。

```swift
#if GREETING
print("GREETING is set")
#else
print("GREETING is not set")
#endif
```

ビルドして実行すると `GREETING is set` と出ます。

## "build-settings" を打ち間違えても、ビルドは通る

ターゲットの `"build-settings"` を `"build-setings"` にしました。

```sh
$ xcodebuild -project Demo.xcodeproj -target Hello build
** BUILD SUCCEEDED **
$ ./build/Debug/Hello
GREETING is not set
```

警告もエラーも出ません。知らないキーは読み飛ばされ、条件が付かないままビルドが通ります。

`xcrun xcodeproj` で設定を読んでも、付いていないとしか出ません。

```sh
$ xcrun xcodeproj setting get -P Demo.xcodeproj SWIFT_ACTIVE_COMPILATION_CONDITIONS --target Hello
SWIFT_ACTIVE_COMPILATION_CONDITIONS (single) on target 'Hello' (raw, unevaluated — direct from the .xcodeproj):
  Debug: (unset)
  Release: (unset)
```

同じブロックに `PRODUCT_NAME` も入っていたときは、ビルドが `error: Multiple commands produce '.../build/Debug'` で止まりました。製品名が空になったせいですが、このエラーからキーの打ち間違いにはたどり着きにくいです。

## xcprojformatter は、そのブロックを消す

Xcode 27.2 には、このファイルを整形する `xcrun xcprojformatter` が入っています。打ち間違えたファイルに `--update` を付けて走らせると、終了コード 0 で何も言わずに終わり、ブロックごと消えていました。

```diff
       "build-phases": [
         "compile-sources",
       ],
-      "build-setings": {
-        "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "GREETING",
-      },
     },
```

整形にかけて直そうとすると、打ち間違えた設定がそのまま失われます。

## 整形の出力との diff で見つける

`--update` を付けないと、整形した結果を標準出力に出します。これを元のファイルと比べると、捨てられたキーが差分として残ります。

```sh
xcrun xcprojformatter Demo.xcodeproj | diff -u Demo.xcodeproj/project.xcproj -
```

正しいファイルなら差分は空で、終了コードは 0 です。打ち間違いがあると、上と同じ削除の差分が出て、終了コードは 1 になります。FirnPlanner では、これをスクリプトにして、JSON を手で直したあとに走らせています。

JSON を手で直す代わりに、`xcrun xcodeproj setting set` などのコマンドで直す手もあります。コマンドは正しいキーで書くので、打ち間違いが入りません。

## まとめ

- Xcode 27 の `project.xcproj` で知らないキーを書くと、xcodebuild も `xcrun xcodeproj` も黙って無視する
- `xcrun xcprojformatter --update` は、知らないキーを黙って消す
- `xcrun xcprojformatter <project> | diff -u <project>/project.xcproj -` の差分が空かどうかで、打ち間違いを見つけられる
