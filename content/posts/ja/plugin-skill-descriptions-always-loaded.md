---
title: 'Xcode のプラグインを入れたら、skill の説明文が約 1 万字ぶん毎ターン読み込まれるようになった'
description: 'Claude Code に Xcode 27.3 beta のプラグインを入れると、19 個の skill の説明文、合わせて 10,503 字が毎ターン読み込まれる。手で置いた同じ名前の skill も 6 個残っていた。説明文の一覧には上限があり、超えると使われていない skill から説明文が外される。'
lang: ja
translationKey: plugin-skill-descriptions-always-loaded
publishDate: 2026-11-08
tags: ['Xcode', 'AI', 'Claude Code']
draft: false
---

Claude Code に Xcode の公式プラグイン (`xcode@claude-plugins-official`) を入れると、19 個の skill の説明文、合わせて 10,503 字が毎ターン読み込まれるようになりました。skill の中身は呼ばれるまで読み込まれないので、入れておくだけなら場所を取らないと思っていましたが、説明文 (frontmatter の `description`) は別でした。説明文の一覧には上限があり、超えると説明文が外された skill は Claude から呼ばれにくくなります。

## 説明文の長さは、SKILL.md の frontmatter から数えられる

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

27.3 beta では skill が 3 個増えましたが、説明文の合計は少し短くなっていました。いちばん長い説明文は 963 字です。

## 手で置いた同じ skill が 6 個残っていた

プラグインを入れる前に、Xcode の skill のいくつかを手で `~/.claude/skills` にコピーしていました。プラグインの skill と同じ名前のものを探すと、6 個ありました。

```sh
for d in "$(xcrun agent plugin path --plugin-format claude)"/skills/*/; do
  n=$(basename "$d"); [ -d ~/.claude/skills/"$n" ] && echo "$n"
done
```

中身を比べると、27.3 beta のプラグインと同じだったのは 1 個、27.2 のプラグインと同じだったのは 2 個で、残りの 4 個はどちらの版とも違っていました。ドキュメントによると、プラグインの skill は `プラグイン名:skill 名` という名前になるので、手で置いた skill とは別のものとして両方読み込まれます。同じ用途の説明文が、6 個ぶん二重に入っていたことになります。

## 一覧が上限を超えると、使われていない skill から説明文が外される

Claude Code のドキュメントによると、Claude は毎ターン skill の名前と説明文の一覧を見て、どの skill を自分で呼ぶかを決めます。この一覧の上限は、既定ではコンテキストウィンドウの 1% です。上限を超えると、名前はすべて残りますが、あまり使われていない skill から説明文が外されます。説明文のない skill も名前を指定すれば呼べますが、Claude が自分で選ぶことは少なくなります。

プラグインを入れたあとのセッションでは、19 個のうち次の 9 個が、skill の一覧に名前だけで出ていて、説明文がありませんでした。

- swiftui-specialist、swiftui-whats-new-27
- translation、translation-coordinator
- siri-app-integration、siri-evaluations
- xctrace、macos-touch-gestures、building-document-based-swiftui-applications

この 9 個の frontmatter の書き方には問題がありませんでした。そのため、一覧が上限を超えて説明文が外されたのだと推定しています。`/context` の表示やデバッグログの警告で、上限を超えていたことを確かめてはいません。

skill を入れるほど毎ターン読み込まれる説明文が増え、上限を超えると、入れた skill のいくつかはかえって呼ばれにくくなります。

## 一覧の量は `/doctor` と `/context` で確かめられる

ドキュメントには、一覧の量を確かめる方法と減らす方法も書いてあります。どれも今回はまだ試していません。

- `/doctor` で一覧のおおよその量と、量の多い skill が分かる。`/context` の Skills の行には、上限に合わせて説明文を外したあとの量が出る
- `--debug` で起動すると、一覧が上限を超えたときにデバッグログに警告が出る
- 設定の `skillOverrides` で skill を `"name-only"` にすると、説明文を出さずに名前だけを一覧に載せられる

手で置いた 6 個は、プラグインと同じ用途なので、消してよいと考えています。

## まとめ

- skill の中身は呼ばれたときに読み込まれるが、説明文は毎ターン読み込まれる。Xcode 27.3 beta 1 のプラグインでは 19 個、10,503 字だった
- 手でコピーした同じ名前の skill が 6 個あり、プラグインの skill とは別に読み込まれていた
- 説明文の一覧が上限を超えると、あまり使われていない skill から説明文が外され、Claude が自分で呼びにくくなる。プラグインを入れたあとのセッションでは 9 個が名前だけで出ていた。上限を超えたためだと推定している

確かめた環境は次のとおりです。

- Claude Code 2.1.319
- Xcode 27.3 beta 1 (27C5020n) と Xcode 27.2 (27B52)

参考にしたもの:

- [Extend Claude with skills](https://code.claude.com/docs/en/skills) (Claude Code のドキュメント)
- [Settings reference](https://code.claude.com/docs/en/settings-reference) (Claude Code のドキュメント)
