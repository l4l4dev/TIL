---
title: 'XcodeGen をやめて、Xcode 27 の project.xcproj を git で持つ'
description: 'Xcode 27.2 で .xcodeproj の中身が JSON5 になったので、XcodeGen をやめてプロジェクトをそのまま git で持つことにした。移るときに確かめたことと、移った後に出てきた「Xcode が勝手に書き直す」問題の調べ方。'
lang: ja
translationKey: xcodegen-to-xcproj
publishDate: 2026-10-01
tags: ['Xcode', 'XcodeGen', 'iOS', 'macOS', 'AI']
draft: false
---

個人で作っている macOS の1日プランナー [FirnPlanner](https://github.com/l4l4dev/FirnPlanner) (iPhone 版も開発中) で、XcodeGen をやめました。Xcode 27.2 から `.xcodeproj` の中身が `project.pbxproj` (plist) ではなく `project.xcproj` (JSON5) になり、差分を人が読めるようになったからです。プロジェクトファイルをそのまま git で持てば、生成の手間がまるごと無くなります。実装の大半を AI のエージェントに任せているので、人もエージェントも忘れがちな「生成し直す」手順を無くせることも、移った大きな理由です。

移ってみると、もう一つ分かったことがありました。プロジェクトを git に入れると、開いている Xcode がプロジェクトファイルを保存し直していることが差分として見えるようになります。そのときに消える設定があったので、残すべきか確かめた話も書きます。

![このプロジェクトでは、project.yml から毎回生成する方式から、project.xcproj を Git で直接管理する方式へ移行した](/TIL/images/project-workflow-ja.svg)

## XcodeGen では、生成を忘れるたびに何かが壊れた

XcodeGen は `project.yml` から `.xcodeproj` を作るツールです。`.xcodeproj` を git に入れずに済むので、`project.pbxproj` のコンフリクトに悩まなくて済みます。FirnPlanner では `.xcodeproj` を git に入れず、`project.yml` から毎回作る構成にしていました。この構成ではプロジェクトの中身を生成のたびに作り直すので、ファイルを足す・消す・名前を変えたら `xcodegen generate` を流し直す運用でした。Xcode の画面で付けた設定は次の生成で消えるため、New File も使わない決まりにしていました。

この「流し直す」を忘れたときの失敗が、実際に何度もありました。

- ブランチを main に取り込んだ後、生成し直す前に全件テストを流して、ビルドが落ちた。取り込んだブランチで足した `PlacementLedger.swift` が、古いプロジェクトに入っていなかった
- Xcode を開いたまま生成すると、ローカルの Swift パッケージ (FirnPlannerCore) が読めなくなることがあった。閉じて生成し直せば戻るが、壊れ方からは原因が分かりにくい
- 開いたまま生成と ⌘R を繰り返していたら、`Package.resolved` と `Localizable.xcstrings` に、触っていない変更が 2 回混ざった (依存の一覧に別の依存が入る、無関係な英訳が書き換わる)。コミットの前に気づいて戻した
- 生成のたびに iPhone 版の `Info.plist` が書き換わり、毎回同じ差分が出た

人が手元で確かめるときの手順も、毎回「Xcode を閉じてから `mint run xcodegen generate`、それから開いて ⌘R」で始まっていました。コントリビューターが増えると、この前置きを全員が覚えておく必要があります。

## AI に実装を任せると、生成の手順が効いてくる

FirnPlanner の実装の大半は、AI のコーディングエージェント (Claude Code) に任せています。司令塔のセッションがタスクを分け、作業用のエージェントが別々の git worktree で同時に実装し、司令塔がテストとレビューを確かめてから main に取り込む形です。人 (私) は、何を作るか・いつ移るかを決め、画面で動きを確かめ、コントリビューターとやりとりします。

この形だと、XcodeGen の手間がそのまま増えます。worktree ごとに生成が要り、取り込むたびに main で生成し直す。エージェントへの指示にも「ファイルを足したら生成する」「Xcode を開いたまま生成しない」を毎回書く必要がありました。上の「生成を忘れて落ちた」も、取り込みの手順の中で起きています。人が忘れる手順は、エージェントも忘れます。

だから、プロジェクトの形式を変えて手順そのものを無くす方を選びました。移行の作業そのものはエージェントに任せました。変換、ビルド設定の比較、2 つの Xcode でのテスト、CI と手順書の直しです。人が受け持ったのは、「beta のうちに移るか」の判断と、Xcode の画面での確認です。

### 失敗は、エージェントが次に読む場所に残している

エージェントは、セッションをまたぐと前の失敗を覚えていません。なので失敗は、次のエージェントが必ず読む場所に書き残すようにしています。置き場所は 4 つです。

- **タスクの記録**: タスク管理には Backlog.md を使い、タスクごとに計画・作業の記録 (notes)・コメント・最終のまとめを CLI で書く。上の「生成を忘れて落ちた」も、その日のタスクの notes に「再生成の前にビルドして失敗。教訓: 取り込み後は generate を必ず先に」と残っている
- **エージェントのメモリ**: 次のセッションでも効かせたいことは、Claude Code のメモリに 1 件 1 ファイルで書く。何が起きたか、なぜ困るか (Why)、次にどうするか (How to apply) の 3 つをそろえる。「作業用のエージェントに git stash を使わせない (worktree 間で退避が入れ替わった)」「取り込みは fast-forward の成否を見てから次へ進む」などが入っている
- **手順の doc**: 開発環境と検証の手順は 1 本の doc にまとめ、そこを正にする。メモリや指示には「その doc を読む」とだけ書き、同じ内容を何か所にも持たない
- **スクリプト**: 機械で止められるものは、点検のスクリプトにする。プロジェクトの 2 つの形式が並んだら FAIL、などがそう

作業の流れも決めてあります。司令塔が作業用のエージェントにタスクを渡すときは、次の 5 つを指示に必ず書きます。対象のファイル、従う既存のパターン、終わりの条件、検証のコマンド、禁止事項 (git stash を使わない、xcodebuild は同時に 1 本だけ、など) です。返ってきた結果は司令塔がテストで確かめ、ロジックに触る変更は PR にして別の AI (Codex) にもレビューさせます。画面の見た目が変わるものは「確認待ち」にして、人が手順どおりに確かめるまで終わりにしません。

この記事の後半に出てくる失敗も、同じ形で残しました。Xcode の書き直しはタスクの notes に 2 回分の時刻つきで書き、調べた結果は手順の doc に「Xcode が保存し直した形を正にする」として足しています。

## project.xcproj は、読める差分のプロジェクトファイル

新しい形式については、Apple の公式資料 [Updating your Xcode project configuration file format](https://developer.apple.com/documentation/xcode/updating-your-xcode-project-configuration-file-format) に説明があります。要点は次のとおりです。

- Xcode 27.2 で新規に作るプロジェクトは、`.xcodeproj` の中身が `project.xcproj` (JSON5) になる
- 読めるのは Xcode 27.0 以降。26 以前では開けない
- 既存のプロジェクトは `xcodebuild -project App.xcodeproj -convert-project xcproj` で変換できる (逆向きは `pbxproj`)
- 編集用の CLI `xcodeproj` と、整形用の `xcprojformatter` が付く

差分が読めるなら、少なくともこのプロジェクトでは XcodeGen を使う理由の大半が無くなります。2026 年 9 月に調べた時点では、XcodeGen はこの形式に対応していませんでした。

## 移る前に、変換したプロジェクトが同じものか確かめた

27.2 はまだ beta だったので、正式版を待つ案もありました。それでも先に移ることにしたのは、他のプロジェクトにも同じやり方を使えそうだったからです。そのかわり、変換したプロジェクトが元と同じものかを先に確かめました。

1. XcodeGen で生成したプロジェクトを `-convert-project xcproj` で変換する
2. 全ターゲット (6 個) × 全構成 (Debug / Release / Beta) で `xcodebuild -showBuildSettings` を変換の前後で出し、差を取る。違ったのは `PROJECT_GUID` だけで、これも最後には揃った
3. ターゲットごとのファイル数を比べる
4. Xcode 27.0 と 27.2 beta 2 の両方で、Mac のテスト全件・スナップショットテスト・iPhone 版のビルドとテスト・UI テストのビルドを流す

ビルド設定の差を取る手順を最初に決めておいたのがよかったと思います。「なんとなく動く」ではなく、差が 0 であることを確かめてから切り替えられました。

ついでに分かったこともあります。27.2 beta 2 で試した範囲では、`xcodebuild` は XcodeGen が作った `project.pbxproj` を勝手に変換しませんでした。一方で、`project.xcproj` がある場所で `xcodegen generate` を流すと、同じ `.xcodeproj` に 2 つの形式が並び、Xcode はどちらも読めなくなります。古い手順を覚えている人が生成を流すと壊れるので、環境を点検するスクリプトで、2 つが並んでいたら FAIL にしました。

## ファイルの列挙は、同期フォルダに置き換えた

変換しただけのプロジェクトには、XcodeGen が並べたファイルが 950 件、1 件ずつ書かれたままです。これでは New File の手間が XcodeGen のときと変わらないので、ソースのフォルダを同期フォルダ (フォルダに置けばターゲットに入る形) に置き換えました。

`project.xcproj` では、フォルダとターゲットの対応がこう書けます。

```json5
{ "kind": "folder", "path": "MobileTests", "target-membership": [ "FirnPlannerMobileTests" ] },
{ "kind": "folder", "path": "Tests/SnapshotTests", "opaque-folders": [ "__Snapshots__" ], "target-membership": [ "FirnPlannerSnapshotTests" ] },
```

いくつか例外もあります。

- iPhone 版と共有する Mac のファイルは、フォルダの例外 (`membership-exceptions` の `inclusions`) に並べる。Xcode のファイルインスペクタで Target Membership を付ければ、Xcode がここに書く
- スナップショットテストの参照画像のように、フォルダの形のままリソースに入れたいものは `opaque-folders` にする。このプロジェクトで個々のファイルとして扱ったときは、png がバラで Resources の直下にコピーされ、`Bundle.url(forResource:)` でフォルダとして見つけられなくなった
- `Info.plist` は実ファイルのまま git で持つ。配列や辞書の値があって、ビルド設定 (`INFOPLIST_KEY_*`) に寄せられなかった

`project.xcproj` にはコメントを書けません。整形すると消えます。ビルド設定の理由は xcconfig の末尾に、Info.plist のキーの理由は Info.plist のコメントに書くことにしました。

移行のついでに、CI のスクリプト、パッケージの版を固定する `Package.resolved` の置き場所、開発環境の手順書、`.gitignore` の 9 か所を直しています。コントリビューターには「Xcode 27.0 以上が要る」「pull した後に古い `project.pbxproj` を消す」を伝えました。

一つ見落としもありました。エージェントが過去に書いた「人が確かめる手順」が、タスクのコメントに残っていたことです。8 本のタスクの手順が、まだ「`mint run xcodegen generate` してから開く」で始まっていました。今の形のプロジェクトで流すと `project.pbxproj` ができて、Xcode がプロジェクトを開けなくなります。人がそのとおりに操作する前に気づいて、訂正を足しました。手順書は直しても、過去の作業の記録に書いた手順までは追いかけにくい、という教訓です。

## 移った後、開いている Xcode が project.xcproj を書き直していた

移った日の夜、触っていないはずの `project.xcproj` に差分が出ていました。

削除されたのは、`SnapshotTests` を除外する `membership-exceptions` の設定です。

<details>
<summary>実際の差分を開く</summary>

```diff
-    }, {
-      "kind": "folder",
-      "path": "Tests",
-      "opaque-folders": [
-        "SnapshotTests",
-      ],
-      "target-membership": [
-        "FirnPlannerTests",
-      ],
-      "membership-exceptions": [
-        {
-          "target": "FirnPlannerTests",
-          "exclusions": [
-            "SnapshotTests",
-          ],
-        },
-      ],
     },
+    { "kind": "folder", "path": "Tests", "opaque-folders": [ "SnapshotTests" ], "target-membership": [ "FirnPlannerTests" ] },
```

</details>

私が Xcode を開いたままにしている間に、エージェントがブランチを main に取り込んでいました。作業ツリーのファイルが変わったのを Xcode が読み直し、プロジェクトを自分の形で保存し直したようです。私が寝ている間の夜中の取り込みでも、同じ書き直しが起きました。AI が git を操作する作業ツリーと、人が開いている IDE が同じ場所にある、という組み合わせだったから気づけたのだと思います。

書き直しは、たぶん XcodeGen のころから起きていました。当時は `.xcodeproj` を `.gitignore` に入れていたので、書き直されても誰も気づかず、次の生成で上書きされていただけです。プロジェクトを git で持つようにしたので、見えるようになりました。

気になったのは、差分が整形だけではないことです。`Tests` フォルダから `SnapshotTests` を外す例外 (`membership-exceptions` の `exclusions`) が消えています。このままコミットすると、スナップショットテストのファイルがユニットテストのターゲットにも入ってしまうかもしれません。最初の 2 回は、git の版に戻しました。

## 例外のあり・なしで、比べた範囲には差が無かった

Xcode が例外を消す理由は 2 つ考えられました。同じ項目に `opaque-folders` があるので Xcode から見ると要らない設定として詰めているのか、意味のある設定を beta の不具合で落としているのか。

どちらかを確かめる実験は、エージェントに頼みました。リポジトリを 2 つ複製して、片方を git の形 (例外あり)、もう片方を Xcode が書いた形 (例外なし) にしました。両方を `build-for-testing` して、ユニットテストのバンドルを比べます。

| 比べたもの | 例外あり | 例外なし |
| --- | --- | --- |
| `FirnPlannerTests.xctest` の中のファイル | 36 個 | 36 個 (一覧が同じ) |
| テストの実行ファイルの大きさ | 83,685,136 バイト | 83,685,136 バイト |
| スナップショットテストのシンボル (`nm`) | 0 | 0 |
| テスト全件 | 通過 (同じ日の main で流したもの) | 通過 |

比べた範囲では同じでした。どちらのバンドルにも SnapshotTests のファイルは 1 つも入っておらず、スナップショットテストのシンボルも 0 でした。

ここから先は解釈です。`Tests` フォルダの項目では、`SnapshotTests` が `opaque-folders` に入っています。そのため、このプロジェクトのこの構成では、外す例外が無くても FirnPlannerTests にスナップショットテストのソースが入らないのだと考えています。Xcode はそれを要らない設定とみなして、保存し直すたびに詰めていたのでしょう。`opaque-folders` と例外の組み合わせが一般にどう扱われるかは、Apple の資料では確かめていません。

比べたのは、macOS の Debug 構成、Xcode 27.2 beta 2、FirnPlannerTests のバンドルだけです。スナップショットテストのターゲットとアプリ本体のバンドル、Release の構成、Xcode 27.0 は比べていません。

**今回は、この Debug・FirnPlannerTests の比較をもとに Xcode が書く形を採り、git の正にしました。ほかの範囲は未確認のままです。** `xcprojformatter` を通しても形が変わらないことは確かめています。Xcode を開いたまま取り込んでも、この差分は出なくなるはずです。

## project.xcproj を手で直したら、Xcode で開いて差分が出ないか見る

今回の件から、手順を 1 つ足しました。`project.xcproj` を手で直したり CLI で書いたりしたら、整形したあとに一度 Xcode で開き、Xcode が保存し直しても差分が出ないことを確かめます。

今後は、差分が出てもすぐには Xcode の形を採らないことにします。その設定が Xcode から見て要らないだけなのか、Xcode (特に beta) の不具合で意味のある設定が落ちているのかは、差分だけでは分からないからです。採る前に、その設定が効くはずのターゲットと構成を洗い出し、両方の形でビルドして中身を比べます。今回の件に当てはめると、FirnPlannerTests のほかに、スナップショットテストのターゲット、Release の構成、基準にしている別の Xcode の版が比べる対象になります (今回はここまで比べていません)。比べた範囲で違いが無ければ Xcode の形を採り、何を比べて何を比べていないかを記録に残します。違いが出たら git の形を残し、不具合として Apple に報告します。

まだ確かめていないこともあります。Xcode の画面でファイルを足したときに、`project.xcproj` のまま期待どおりの差分で保存されるか。Xcode Cloud が使う Xcode の版でビルドが通るか。27.2 はまだ beta なので、正式版で挙動が変わることもありそうです。分かったら追記します。
