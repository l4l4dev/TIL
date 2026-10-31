---
title: 'Xcode でビルドすると、.xcstrings がまるごと並べ直されることがある'
description: 'Xcode の画面からビルドすると、コードにある文字列と String Catalog がずれていたときだけ、Xcode が .xcstrings を書き直す。キーは Xcode の順に並べ直されるので、別の順で書いてあったファイルは差分が膨らむ。xcodebuild では書き直さなかった。git の clean フィルタで並びの差分を消した。'
lang: ja
translationKey: xcode-build-rewrites-xcstrings
publishDate: 2026-10-31
tags: ['Xcode', 'Git', 'Swift']
draft: false
---

[FirnPlanner](https://firnplanner.l4l4.dev/) の開発で、Xcode でビルドしただけなのに、`git status` に `.xcstrings` (String Catalog) が変更として出ました。中を見ると、ほとんどがキーの並びの入れ替えでした。

新しいプロジェクトで、いつ書き直されるのかを確かめました。

## 書き直すのは、コードとカタログがずれたときだけ

`Text("Today")` などの文字列が 4 つあるアプリに、日本語訳を入れたカタログを置きました。カタログを git にコミットしてから、コマンドラインの `xcodebuild` と、Xcode の画面からのビルドで比べました。

| カタログの状態 | `xcodebuild` | Xcode の画面からのビルド |
|---|---|---|
| コードの文字列とそろっている (キーが逆順でも) | 変わらない | 変わらない |
| コードにだけある文字列がある | 変わらない | キーを足し、全体を並べ直す |
| コードから消した文字列がある | 変わらない | `"extractionState" : "stale"` を付け、全体を並べ直す |

キーがそろっていれば、並びが Xcode と違っていても、Xcode はファイルに触りませんでした。書き直すのは、足すか印を付けるものがあるときだけです。そのときはファイル全体を Xcode の順で書くので、並びが違っていたファイルは、1 行足しただけでも差分が全体に広がります。

`xcodebuild` は、どの場合もカタログを書き直しませんでした。

## Xcode の並び順と書き方

Xcode が書いたファイルは、次のようになっていました。

- キーは文字コード順。大文字が先なので、`"Zebra"` が `"all done"` より前に来る
- `:` の前後に空白が入る (`"Today" : {`)
- 訳の無いキーは `{}` ではなく、空行をはさんだ `{` と `}` になる
- ファイルの末尾に改行が付かない

手で書いたり、ツールで書き出したりしたカタログは、これと順番や書き方が違うことがあります。

## git の clean フィルタで、並びの差分を消す

並びだけの差分を消すために、git に渡す前にキーを並べ直すフィルタを置きました。

```python
#!/usr/bin/env python3
# git の clean フィルタ。.xcstrings のキーを並べ直してから git に渡す
import json, sys

catalog = json.load(sys.stdin)
json.dump(catalog, sys.stdout, ensure_ascii=False, indent=2,
          sort_keys=True, separators=(",", " : "))
```

`sort_keys=True` は、いちばん外のキーだけでなく、`localizations` や `stringUnit` の中まで、すべての階層のキーを並べ直します。Xcode もすべての階層を文字コード順で書いていたので、ここでは中まで並べ直すのが合っています。

```sh
echo '*.xcstrings filter=sort-xcstrings' >> .gitattributes
git config --local filter.sort-xcstrings.clean "python3 scripts/sort-xcstrings.py"
git add --renormalize -- '*.xcstrings'
git diff --cached
```

`git add --renormalize .` とすると、`.gitattributes` のほかの設定 (改行コードなど) に合わせて、関係ないファイルまで stage されることがあります。手元で試すと、`* text=auto` を足したリポジトリでは CRLF のテキストファイルも stage されました。対象を `.xcstrings` に絞り、コミットの前に `git diff --cached` で中身を見ます。

`git config` はリポジトリごとの設定なので、clone するたびに入れます。

clean フィルタが並べ直すのは、git に入れる中身 (index と blob) だけです。作業ツリーのファイルには触りません。

試しにカタログのキーを逆順にし、インデントも変えて書き直すと、`git status` には ` M` と出ますが、`git diff` は空でした。ファイルの大きさが変わったので git は変更ありと見ますが、`git diff` はフィルタを通した中身で比べるので、差が出ません。

この状態で `git add -u` をすると、stage されるものは無く、` M` も消えました。ただし、作業ツリーのファイルは逆順のままです。ファイルそのものを並べ直した形にしたいときは、別の手順が要ります。`git checkout -- <ファイル>` だけでは、git が中身は同じと見て書き直しませんでした。`git diff` が空なのを確かめてからファイルを消し、`git checkout -- <ファイル>` で取り出すと、index の中身 (並べ直した形) になりました。

Xcode が書いたファイルとこのフィルタの出力の違いは、訳の無いキーの `{}` の書き方だけでした。

## stale の印は、消したか消し忘れか

`"extractionState" : "stale"` は、そのキーがコードから見つからなくなったという印です。文字列を本当に消したのなら、カタログからも消します。コードの書き方を変えて Xcode が拾えなくなっただけなら、拾える書き方に戻します。

## まとめ

- Xcode の画面からビルドすると、コードとずれた `.xcstrings` を書き直す。そのとき全体を Xcode の順に並べ直す
- `xcodebuild` は書き直さなかった
- 並びだけの差分は、キーを並べ直す git の clean フィルタで消せる。並べ直すのは git に入れる中身だけで、作業ツリーのファイルはそのまま

確かめた環境: Xcode 27.2 (27B52)、macOS 27.2。
