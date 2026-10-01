---
title: 'AI エージェントを git worktree で並行に動かして踏んだ落とし穴'
description: 'Claude Code のサブエージェントを git worktree で並行に動かして困ったことを 5 つ。起点が古い main、変更が無いと消える worktree、パイプで隠れる merge の失敗、増え続ける DerivedData、止まる待ち。'
lang: ja
translationKey: ai-agents-and-worktrees-pitfalls
publishDate: 2026-10-01
tags: ['Git', 'git worktree', 'Xcode', 'AI', 'Claude Code']
draft: false
---

[前回の記事](/TIL/ja/posts/git-stash-across-worktrees/)では、`git stash` が worktree をまたいで 1 本しかないせいで、エージェント同士の変更が入れ替わった話を書きました。個人で作っている macOS の1日プランナー [FirnPlanner](https://github.com/l4l4dev/FirnPlanner) では、Claude Code のサブエージェントを git worktree ごとに並行で動かしています。この運用では、stash のほかにも踏んだ落とし穴がいくつかありました。短い節で、起きたこと、理由、いまの対処を順に書きます。

## worktree は起動した時点の main から切られるので、PR の前に載せ直す

サブエージェントに `isolation: "worktree"` を付けて起動すると、専用の worktree が作られます。私の環境で観察した限り、その worktree は起動した時点の main から切られます。エージェントが作業している間に main が進んでも、追いかけてはくれません。

困るのは、返ってきた枝をそのまま PR にしたときです。main に後から入った変更を、枝が知らないまま巻き戻す差分になることがあります。実際に、古い main から切った枝で `git reset --soft origin/main` をしてコミットをまとめたところ、その間に main に入った修正を取り消す差分が混ざりました。main に入れる前に気づいて載せ直しています。

いまは、取り込む前に必ず次の 2 つを見ています。

```sh
git merge-base --is-ancestor origin/main HEAD && echo "main の最新を含む"
git diff --stat origin/main...HEAD
```

1 本目が失敗したら、先に `git rebase origin/main` をします。2 本目の `--stat` に、触ったはずのないファイルが出ていたら、そこで止まります。コミットをまとめる操作は、rebase のあとにだけします。

## 変更が無いと worktree が消え、続きの作業が別のチェックアウトで動く

これも観察した事実で、仕様として確かめたわけではありません。`isolation: "worktree"` の worktree は、エージェントが何も変更しないで終わると、自動で片付けられるようでした。

調査と計画だけをさせて、あとから実装の続きを頼んだことがあります。調査では何も変更していないので、そのときには worktree がもう消えていました。続きを頼まれたエージェントの作業ディレクトリは、リポジトリ直下のチェックアウトに落ちました。直下は別のセッションが別のブランチで使っていて、エージェントはそこでブランチ名を一時的に変えてしまいました。すぐ戻せたので実害はありませんでしたが、他のセッションの作業を壊していてもおかしくない状況でした。

いまは、実装を伴う委譲では `isolation` を使わず、`git worktree add` で自分で作ります。そのうえで、指示の最初に次を書いています。

> 最初に `pwd` と `git branch --show-current` を出し、指定と違っていたら何もせず報告する。`git branch -m` は使わない。

作業場所が合っているかをエージェント自身に確かめさせると、場所が食い違ったときに破壊的な操作へ進まずに済みます。

## `git merge --ff-only | tail -1 && 後片付け` は、失敗しても後片付けが走る

worktree の枝を main に取り込むとき、次のように 1 行で書いていました。

```sh
git merge --ff-only feature | tail -1 && echo next
```

`next` のところには、worktree の削除や「取り込んだ」という記録が入っていました。main が先に進んでいて fast-forward できない状態で、これを実行すると次のようになります (小さなリポジトリで再現しました。Git 2.54)。

```text
$ git merge --ff-only feature | tail -1 && echo next
hint: Diverging branches can't be fast-forwarded, you need to either:
(中略)
fatal: Not possible to fast-forward, aborting.
next
```

merge は `fatal` で失敗しているのに、`next` が出ています。パイプラインの終了コードは最後のコマンドの `tail` のもので、`tail` は成功するからです。実際の運用では `2>&1 | tail -1` と書いていて、画面にも `fatal` の 1 行しか出ませんでした。その直後に worktree が消え、記録には「取り込み済み」と残りました。

`set -o pipefail` を付けると、パイプラインの終了コードは失敗したコマンドのものになります。

```text
$ (set -o pipefail; git merge --ff-only feature | tail -1 && echo next; echo "exit=$?")
(hint と fatal の出力)
exit=128
```

`next` は出ず、終了コードは merge の 128 です。ただ、私は `pipefail` で直すのをやめました。そもそも失敗を見たいコマンドにパイプを付けない方が単純だからです。代わりに、次のように 2 段に分けました。

```sh
git merge --ff-only feature
echo "merge exit=$?"
```

終了コードを見て、取り込めたことを `git log -1` で確かめてから、別の実行で後片付けをします。fast-forward できなければ、通常の merge で取り直します。

## DerivedData は worktree ごとに増え、ディスクが一杯になった

xcodebuild は、プロジェクトのパスごとに `~/Library/Developer/Xcode/DerivedData` の下へ別のフォルダを作ります。worktree を切るたびにパスが変わるので、ビルドを回すたびにフォルダが 1 つ増えます。worktree を消しても、DerivedData は残ります。

2026 年 9 月 9 日に、Mac から「ディスクの空きがほとんどありません」と警告が出ました。当時の `DerivedData` は 613 GB で、このアプリのフォルダ (`FirnPlanner-<ハッシュ>`) が 265 個ありました。1 つが 2〜3 GB です。今日は 15 個、`DerivedData` 全体で 39 GB でした (名前の一覧を読み、`du` で大きさを見ただけで、何も消していません)。

対処として、worktree を消すときは対応する DerivedData も消すようにしました。直近 2 時間に触っていないフォルダだけを消せば、走っているビルドのものには触れません。

```sh
find ~/Library/Developer/Xcode/DerivedData -maxdepth 1 -name 'FirnPlanner-*' -mmin +120 -exec rm -rf {} +
```

エージェントに後片付けを任せると、並行して動いている別のエージェントのフォルダまで消されることがありました。指示には「DerivedData は消さない」を入れ、消すのは親のセッションだけにしています。

同じ DerivedData を共有するのも、困る原因になります。リポジトリ直下で全件テストを流していたとき、自分で開いている Xcode と DerivedData を取り合って、`CodeSign failed` で 4 回続けて落ちました。直下は Xcode と共有で、worktree は別のフォルダだから起きないのでした。それ以来、直下で流すときは `-derivedDataPath` に別の場所を渡しています。

## 待ちと xcodebuild を 2 段に分けると、エージェントが止まる

xcodebuild は同時に 1 本しか動かせません。2 本目は DerivedData を取り合って、両方が止まります。そこで、ロックを取って 1 本ずつ流すラッパーを置いています。macOS には `flock` コマンドが無いので、Python の `fcntl.flock` で書きました。

```sh
#!/bin/sh
exec python3 -c '
import fcntl, subprocess, sys
with open("/tmp/xb.lock", "w") as f:
    fcntl.flock(f, fcntl.LOCK_EX)
    sys.exit(subprocess.call(sys.argv[1:]))
' "$@"
```

3 本を同時に起動すると、2 秒ずつ順に動きました (`sleep 2` を流して確かめました)。

```text
C start 15
C end   17
B start 17
B end   19
A start 19
A end   21
```

もう 1 つ、エージェントに待たせる書き方でも止まりました。「xcodebuild が空くのを待ってから実行して」と頼むと、Monitor を張って「通知を待つ」と言ってターンを終えます。サブエージェントは自分が張った Monitor やバックグラウンドの通知を受け取れないので、そのまま止まってしまいます。Bash は実行が 120 秒を超えると自動でバックグラウンドに回るので、時間のかかる xcodebuild でも同じことが起きました。

いまは、待ちと実行を 1 コマンドにつなぎ、timeout を最大にして渡しています。

```sh
while pgrep -x xcodebuild >/dev/null; do sleep 30; done; ./xb.sh xcodebuild ... test
```

`pgrep -f` だと、待っているシェル自身のコマンド行にも一致して、いつまでも待つので `-x` にします。timeout が切れたら同じコマンドを繰り返す、と指示に書いておきます。

## 困るのは worktree の外側にある共有物だった

並行で動かして困ったのは、コードそのものより、worktree が分けてくれない部分でした。起点になる main や、リポジトリ直下のチェックアウトがそうです。ディスクと、同時に 1 本しか動かせないビルドも同じです。どれも、エージェントに任せる前に、私が決めておく必要がありました。
