# Swift Testing traits sample

記事「Swift Testing の .serialized はテストを 1 つずつ流すが、同じスレッドで動くとは限らない」で使ったパッケージです。
The package used in the post "Swift Testing .serialized runs tests one at a time but not on the same thread".

## 必要なもの / Requirements

- Xcode 27.2 (Swift 6.4.2) 以降 / Xcode 27.2 (Swift 6.4.2) or later
- macOS 15 以降 / macOS 15 or later

## 流し方 / Run

```sh
swift test --filter ParallelTests
swift test --filter TimeLimitTests
```

`TimeLimitTests` は、時間の制限を超えるテストをわざと含むので失敗します。終わるまで約 90 秒かかります。
`TimeLimitTests` fails on purpose because some tests go over their time limit. It takes about 90 seconds.

## 中身 / Contents

| ファイル / File | 内容 / What it does |
|---|---|
| `Sources/TraitsLab/Probe.swift` | 経過時間とスレッドの番号を `LAB` で始まる行に出す / Prints the elapsed time and thread number on lines starting with `LAB` |
| `Tests/ParallelTests/ParallelTests.swift` | 何も付けない Suite、`.serialized` の Suite、引数を渡すテスト、入れ子の Suite / Suites with no traits and with `.serialized`, parameterized tests, and a nested suite |
| `Tests/TimeLimitTests/TimeLimitTests.swift` | `.timeLimit` を超えるテスト、Suite とテストの両方に付けた制限、引数を渡すテスト、スレッドを止めるテスト、`.minutes(0)` / Tests that go over `.timeLimit`, limits on both suite and test, a parameterized test, a test that blocks its thread, and `.minutes(0)` |

結果はテストのログに `LAB` で始まる行として出ます。
Results appear in the test log as lines starting with `LAB`.
