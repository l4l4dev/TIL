---
title: '日本語のファイル名は、macOS で通っても Linux で 255 バイトを超える'
description: 'タスク管理のファイル名に日本語の題名がそのまま入り、Linux の checkout で File name too long になった。macOS (APFS) は 255 文字、Linux (ext4 など) は 255 バイトまでという違いが原因。手元で測った境界と、コミット前に確かめる方法。'
lang: ja
translationKey: japanese-filename-255-bytes
publishDate: 2026-10-01
tags: ['Git', 'macOS', 'Linux', 'AI']
draft: false
---

個人で作っている macOS の1日プランナー [FirnPlanner](https://github.com/l4l4dev/FirnPlanner) では、タスク管理に [Backlog.md](https://github.com/MrLesk/Backlog.md) を使っています。タスクは 1 件 1 ファイルの Markdown で、ファイル名は `task-NNN - <題名>.md` の形になります。題名の空白などを置き換えただけの文字列が、そのままファイル名に入ります。

ある日、AI のコードレビュー (Codex) から P1 の指摘が付きました。新しく足したタスクのファイル名が 272 バイトあり、Linux では扱えないという内容です。手元の Mac では作るのもコミットするのも普通にできていたので、言われるまで気づきませんでした。

## Codex の指摘: Linux の checkout でファイルを作れない

指摘の要点はこうでした。

> This new filename component is 272 UTF-8 bytes, exceeding the 255-byte `NAME_MAX` used by common filesystems such as ext4. A fresh checkout therefore cannot materialize the task file, and even the current Linux checkout makes `git status` fail with `File name too long`

今回のレビュー環境は Linux でした。新しく clone してもそのファイルは作れない、既にある checkout でも `git status` が `File name too long` で失敗する、と書かれています。

ただし、`git status` が「失敗する」は正確ではありませんでした。この記事の PR のレビューで、Linux (Git 2.43 と 2.51) で確かめてもらった結果です。255 バイトを超える名前が index に入った状態で `git status --short` を実行すると、`File name too long` が stderr に出ても終了コードは 0 でした。終了コードが 1 になって止まるのは、`git checkout-index -a` や clone のように、ファイルを作る操作の方です。

なので、GitHub Actions のような CI や、Linux で作業するコントリビューターの手元で起きるのは、checkout の失敗です。`git status` の終了コードだけを見ていると、問題に気づけないこともあります。

## APFS は 255 文字、Linux は 255 バイトまで

原因は、ファイル名の長さの上限を何で数えるかの違いです。

Linux の ext4 などは、ファイル名の 1 要素 (パスの `/` で区切った 1 つ) を **255 バイト**までに制限しています。UTF-8 の日本語はほとんどが 1 文字 3 バイトなので、日本語だけなら 85 文字で上限に届きます。

macOS の APFS で同じことを試すと、上限はバイトではなく文字数でした。手元 (macOS 27、APFS) で `あ` を並べたファイル名を `touch` した結果です。

| `あ` の数 | UTF-8 のバイト数 | APFS で作れるか |
| --- | --- | --- |
| 85 | 255 | 作れる |
| 86 | 258 | 作れる |
| 255 | 765 | 作れる |
| 256 | 768 | `File name too long` |

`getconf NAME_MAX .` はどちらでも 255 を返します。数え方が違うので、Mac で試しても Linux の上限には当たりません。

Backlog.md のタスクでいうと、`task-NNN - ` と `.md` で 15 バイトほど使うので、日本語の題名はおよそ 80 文字で 255 バイトを超えます。説明まで題名に書いてしまうと、届く長さです。

## Mac ではコミットも push も通ってしまう

git はファイル名の長さを確かめません。手元で 276 バイトの名前のファイルを作ってみると、`git add` も `git commit` もそのまま通りました。push しても GitHub は受け取ります。壊れるのは、そのコミットを Linux で checkout したときです。

自分の Mac だけで作業していると、この問題はずっと見えません。今回は、レビューの環境が Linux だったので見つかりました。

## コミットの前にバイト数を数える

題名を短くするのが一番の対策です。いまは、タスクを起票するときの題名を日本語なら 60 文字程度までにして、詳しいことは説明の欄に書いています。

それでも確かめたいときは、git が管理しているファイル名を、`/` で区切った要素ごとにバイト数で数えます。

```sh
git ls-files -z | python3 -c '
import sys
for p in sys.stdin.buffer.read().split(b"\0"):
    for part in p.split(b"/"):
        if len(part) > 255:
            print(len(part), p.decode())'
```

`-z` を付けているのは、日本語のファイル名が `"\343\201\202..."` のようにエスケープされて出てこないようにするためです (`core.quotepath` の既定の動き)。何も出なければ問題ありません。手元の 276 バイトのファイルでは、`276 task-1 - 長い題名...` と出ました。

1 件だけ確かめるなら、`printf '%s' "<ファイル名>" | wc -c` で足ります。`echo` だと末尾の改行も数えるので、`printf` を使っています。

## 名前を短くするときは、ファイル名も変わったか見る

当時使っていた版の Backlog.md では、`backlog task edit --title` で題名を直しても、変わるのはファイルの中の `title` だけでした。ファイル名は長いまま残ります。題名を変えたら、ファイル名も同じ規則で付け直したかを確かめます。今回の指摘では、題名を短くしてファイル名を 168 バイトにし、ほかに 255 バイトを超えるファイルが無いことも確かめました。

Linux のマシンを手元に持っていなくても、CI やレビューの環境が Linux なら、そこで初めて壊れます。日本語のファイル名を自動で作るツールを使っているなら、一度バイト数を数えておくと安心です。
