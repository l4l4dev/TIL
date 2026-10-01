---
title: 'git stash は worktree をまたいで 1 本しかない'
description: 'AI のエージェント 2 本が別々の git worktree で同時に git stash を使ったら、未コミットの変更が worktree の間で入れ替わった。refs/stash がリポジトリに 1 つしかないのが原因。再現の手順と、代わりにどうしているか。'
lang: ja
translationKey: git-stash-across-worktrees
publishDate: 2026-10-01
tags: ['Git', 'git worktree', 'AI', 'Claude Code']
draft: false
---

個人で作っている macOS の1日プランナー [FirnPlanner](https://github.com/l4l4dev/FirnPlanner) では、実装の大半を AI のコーディングエージェント (Claude Code) に任せています。作業用のエージェントは、それぞれ別の git worktree で同時に動きます。worktree ごとに作業ツリーもブランチも分かれるので、互いに干渉しないと思っていました。

ところが `git stash` だけは分かれていませんでした。2 本のエージェントがほぼ同時に stash と pop をしたら、片方の未コミットの変更がもう片方の worktree に出てきました。

## 並行で stash と pop をしたら、変更が別の worktree に移った

同期のマージを直すタスクと、別のタスクを、2 本のエージェントに並行で振っていました。どちらも途中で手元の変更をいったん避けたくなり、`git stash` → 作業 → `git stash pop` をしています。

結果として、片方の worktree に、もう片方のタスクの変更が入りました。片方のエージェントが相手の worktree を元に戻そうとして、権限の確認で止まったところで気づきました。最後は、変更の持ち主のエージェントに自分のパッチを当て直させて戻しています。どちらの変更も失わずに済みましたが、気づかずにコミットしていたら、関係ない変更が別の PR に混ざっていたはずです。

## refs/stash はリポジトリで共有される

`git help worktree` の REFS の節に、そのまま書いてあります。

> In general, all pseudo refs are per-worktree and all refs starting with refs/ are shared. (中略) There are exceptions, however: refs inside refs/bisect, refs/worktree and refs/rewritten are not shared.

worktree ごとに分かれるのは `HEAD` のような疑似 ref と、`refs/bisect`・`refs/worktree`・`refs/rewritten` の下だけです。`git stash` が使う `refs/stash` は `refs/` の下にあるので、すべての worktree で 1 本を共有します。stash の積み重ね (`stash@{0}`、`stash@{1}` …) は、この ref の reflog です。

`git stash pop` は、どの worktree で作った退避かを見ません。いちばん上の `stash@{0}` を、今いる worktree に当てます。2 本が交互に push と pop をすると、相手の退避を取り出すことになります。

## worktree 2 つで試すと、pop が相手の退避を取り出す

worktree を 2 つ作り、それぞれで stash してみます。

```sh
git init -b main repo && cd repo
echo base > a.txt && echo base > b.txt
git add . && git commit -m init
git worktree add -b task-a ../wt-a
git worktree add -b task-b ../wt-b

# A の worktree で退避
cd ../wt-a && echo "A の作業" >> a.txt && git stash push -m "A の退避"
# 続けて B の worktree で退避
cd ../wt-b && echo "B の作業" >> b.txt && git stash push -m "B の退避"

# A の worktree に戻って取り出す
cd ../wt-a
git stash list
git stash pop
```

A の worktree から見ても、退避は 2 つとも並んでいます。

```text
stash@{0}: On task-b: B の退避
stash@{1}: On task-a: A の退避
```

そのまま `pop` すると、A の worktree に B の変更 (`b.txt`) が当たります。

```text
On branch task-a
Changes not staged for commit:
	modified:   b.txt
```

B の worktree で `git stash list` を見ると、残っているのは A の退避だけです。B がここで `pop` すれば、今度は A の変更を受け取ります。どちらの worktree で `git rev-parse --git-path refs/stash` を実行しても、同じ `.git/refs/stash` を指していました (Git 2.54 で確認)。

人が 1 人で worktree を行き来しているだけなら、まず起きません。自分がどこで stash したかを覚えているからです。worktree を使って複数のエージェントを同時に動かすと、互いの stash が見えないまま同じスタックを触るので、起きやすくなります。

## 代わりに WIP コミットを使う

いまは、作業用のエージェントに渡す指示の git の節に、次の 1 行を必ず入れています。

> git stash を使わない。一時的に変更を避けたいときは WIP コミットにする。

ブランチは worktree ごとに分かれているので、自分のブランチに積んだコミットを他の worktree が取り出すことはありません。WIP コミットは PR にする前にまとめ直します。

どうしても stash の形で持ちたいなら、worktree ごとに分かれる `refs/worktree/` の下に置く手もあります。`git stash create` は退避のコミットを作るだけで、`refs/stash` には積みません。

```sh
c=$(git stash create "A の退避")
git update-ref refs/worktree/wip "$c"
git reset --hard
# ...作業...
git stash apply refs/worktree/wip
```

別の worktree から `git rev-parse refs/worktree/wip` を引いても見つかりませんでした。ただ、これをエージェントに毎回正しく書かせるより、「stash を使わない」と決めた方が単純なので、こちらは使っていません。

## 入れ替わったら、worktree の持ち主に戻させる

入れ替わりに気づいたら、その worktree の持ち主のエージェントに戻させます。別のエージェントや司令塔のセッションが、代わりに相手の worktree を触ることはしません。持ち主の側に差分を渡して当て直させる方が、何をどこに戻したかを追いやすいからです。

worktree は作業ツリーを分けてくれますが、`.git` の中身の大半は共有です。stash のほかにも、タグやリモート追跡ブランチは共有されます。並行で動かすときに何が共有されるかは、一度 `git help worktree` の REFS の節を読んでおくと安心です。
