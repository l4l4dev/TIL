---
title: 'プラグインの skill は説明文が毎回読み込まれ、入れすぎると説明が省かれて呼ばれにくくなる'
description: 'Claude Code に Xcode 27.3 beta のプラグインを入れると、skill が 19 個増え、説明文は合わせて約 1 万 500 字あった。skill の説明文は毎回コンテキストに読み込まれ、一覧が上限を超えると説明が省かれる。手で置いた同じ名前の skill も一覧に並んでいた。'
lang: ja
translationKey: plugin-skill-descriptions-always-loaded
publishDate: 2026-11-08
tags: ['Xcode', 'AI', 'Claude Code']
draft: false
---

Claude Code に、Xcode の公式プラグイン (`xcode@claude-plugins-official`) を入れました。Xcode 27.3 beta 1 から書き出したもので、skill が 19 個入っています。skill は、名前と説明文 (frontmatter の `description`) だけが先に読み込まれ、中身は呼ばれたときに読み込まれます。中身は呼ぶまで場所を取らないので、入れておくだけなら損はないと思っていました。ところが、説明文のほうは毎回読み込まれていて、入れすぎると説明が省かれることが分かりました。

## skill の説明文は、毎回コンテキストに入る

Claude Code のドキュメントによると、Claude は毎ターン、skill の名前と説明文の一覧を見ています。Claude はこの説明文を読んで、どの skill を自分で呼ぶかを決めます。一覧には上限があり、既定ではコンテキストウィンドウの 1% です。上限を超えると、名前はすべて残りますが、あまり使われていない skill から説明文が外されます。説明文のない skill は、名前を指定すれば呼べますが、Claude が自分で選ぶことは少なくなります。

つまり、skill を入れるほど説明文の分だけコンテキストが毎回使われ、上限を超えると、入れた skill のいくつかはかえって呼ばれにくくなります。

## 19 個の説明文は、合わせて約 1 万 500 字あった

プラグインの中身は Xcode のビルドごとに書き出され、書き出した場所は `xcrun agent plugin path --plugin-format claude` で分かります。そこにある `skills/*/SKILL.md` の frontmatter から `description` を取り出し、文字数を数えました。

```python
import glob, os, re, sys
import yaml

total = 0
paths = sorted(glob.glob(os.path.join(sys.argv[1], "skills", "*", "SKILL.md")))
for path in paths:
    front = re.match(r"---\n(.*?)\n---", open(path).read(), re.S).group(1)
    total += len(yaml.safe_load(front)["description"])
print(len(paths), "skills,", total, "characters")
```

`xcrun` で選ぶ Xcode を `DEVELOPER_DIR` で切り替えて、2 つの版で数えました。

| Xcode | skill の数 | 説明文の合計 |
|---|---|---|
| 27.2 (27B52) | 16 | 11,101 字 |
| 27.3 beta 1 (27C5020n) | 19 | 10,503 字 |

27.3 beta では skill が 3 個増えましたが、説明文の合計は 27.2 より少し短くなっていました。いちばん長い説明文は 963 字で、1 つの skill の説明文が切られる長さ (1,536 字) には届いていません。

## 9 個は名前だけになっていたと見ている

確かめたセッションでは、19 個のうち 9 個が、説明文のない名前だけの表示になっていたと見ています。これは推定です。frontmatter の書き方には問題がなかったので、一覧が上限を超えて説明文が外されたのだと考えています。ただし、どの skill が外されたかを Claude Code の記録や `/context` の表示で確かめたわけではありません。

## 手で置いた同じ名前の skill も、一覧に並んでいた

プラグインを入れる前に、Xcode の skill のいくつかを手で `~/.claude/skills` にコピーしていました。プラグインの skill と同じ名前のものを探すと、6 個ありました。

```sh
for d in "$(xcrun agent plugin path --plugin-format claude)"/skills/*/; do
  n=$(basename "$d"); [ -d ~/.claude/skills/"$n" ] && echo "$n"
done
```

6 個のうち、27.3 beta のプラグインと中身が同じだったのは 1 個だけでした。27.2 のプラグインと同じだったのは 2 個で、残りの 4 個はどちらの版とも違っていました。ドキュメントによると、プラグインの skill は `プラグイン名:skill 名` の名前になるので、手で置いた skill とは別のものとして扱われます。同じ用途の skill が 2 つずつ一覧に入り、その分だけ説明文が増えていました。

## まとめ

- skill の中身は呼ばれたときに読み込まれるが、説明文は毎ターン読み込まれる
- 説明文の一覧が上限を超えると、あまり使われていない skill から説明文が外され、Claude が自分で呼びにくくなる
- Xcode 27.3 beta 1 のプラグインは skill が 19 個で、説明文は合わせて 10,503 字あった
- 確かめたセッションでは 9 個が名前だけになっていたと見ている。上限を超えたためだと考えているが、推定である
- 手でコピーした同じ名前の skill が 6 個あり、プラグインの skill と一緒に一覧に入っていた

確かめた環境は次のとおりです。

- Claude Code 2.1.319
- Xcode 27.3 beta 1 (27C5020n) と Xcode 27.2 (27B52)

参考にしたもの:

- [Extend Claude with skills](https://code.claude.com/docs/en/skills) (Claude Code のドキュメント)
- [Settings reference](https://code.claude.com/docs/en/settings-reference) (Claude Code のドキュメント)
