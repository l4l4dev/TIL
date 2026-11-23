# Cancelled task writes late sample

記事「Task を cancel した直後にデータを消すと、遅れて終わった処理が消したデータを書き戻した」で使ったパッケージです。
The package used in the post "Removing data right after cancelling a Task let the late-finishing work write the removed data back".

## 必要なもの / Requirements

- Xcode 27.3 (Swift 6.4.4) 以降 / Xcode 27.3 (Swift 6.4.4) or later
- macOS 15 以降 / macOS 15 or later

## 流し方 / Run

```sh
swift run cancel-demo
swift test
```

`swift run cancel-demo` は 5 つの実験を順に流し、時刻つきのログと、最後にファイルの中身を出します。`swift test` は同じ結果を Swift Testing で確かめます。
`swift run cancel-demo` runs five experiments in order and prints a timestamped log and the file contents at the end. `swift test` checks the same results with Swift Testing.

環境変数 `CANCEL_LAB_LOG_DIR` にディレクトリを渡すと、実験ごとのログをファイルにも書きます。
Set the `CANCEL_LAB_LOG_DIR` environment variable to a directory to also write a log file per experiment.

## 実験 / Experiments

| 実験 / Experiment | 内容 / What it does | 鍵 / Key |
|---|---|---|
| 1 | cancel してすぐ消す / Cancel, then remove right away | 戻る / Comes back |
| 2a | 書く直前に `Task.isCancelled` を確かめる / Check `Task.isCancelled` before writing | 戻らない / Stays removed |
| 2b | 確認と書き込みのあいだに cancel と消去を入れる / Cancel and remove between the check and the write | 戻る / Comes back |
| 3 | cancel のあと `await task.value` で待ってから消す / Cancel, await `task.value`, then remove | 戻らない / Stays removed |
| 4 | 世代を lock の中で確かめてから書く。割り込みは 2b と同じ / Check a generation under a lock before writing, with the same interruption as 2b | 戻らない / Stays removed |

## 中身 / Contents

| ファイル / File | 内容 / What it does |
|---|---|
| `Sources/CancelLab/Support.swift` | 鍵のファイルの置き場、ログ、合図を待つ `Gate`、キャンセルに反応しない `slowCheck`、世代つきの `GuardedKeyStore` / The key file store, the log, a `Gate` that waits for a signal, a `slowCheck` that does not react to cancellation, and `GuardedKeyStore` with a generation |
| `Sources/CancelLab/SaveJob.swift` | 「遅い確認のあとで鍵を書く」仕事の 3 つの版 / Three versions of the "slow check, then write the key" job |
| `Sources/CancelLab/Experiments.swift` | 5 つの実験 / The five experiments |
| `Sources/cancel-demo/main.swift` | 実験を順に流す / Runs the experiments in order |
| `Tests/CancelLabTests/CancelLabTests.swift` | 同じ結果を確かめるテスト / Tests that check the same results |
