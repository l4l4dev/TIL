# Swift Testing MainActor sample

記事「Swift Testing で @MainActor のテストが同時に走ると、AsyncStream の値が届くまでの時間は main を使うテストの数に比例して延びた」で使ったパッケージです。
The package used in the post "When @MainActor tests run in parallel in Swift Testing, AsyncStream values arrive later in proportion to the number of tests using main".

## 必要なもの / Requirements

- Xcode 27.2 (Swift 6.4.2) 以降 / Xcode 27.2 (Swift 6.4.2) or later
- macOS 15 以降 / macOS 15 or later

## 流し方 / Run

```sh
LOAD=8 swift test --filter ContentionTests
swift test --filter BlockedMainTests
```

`LOAD` は同時に走らせる重いテストの数 (0〜16、既定は 0)、`CHUNK` は重いテストが 1 回に main を使う ms (既定は 50) です。
`LOAD` is the number of busy tests that run at the same time (0 to 16, default 0), and `CHUNK` is how many ms each busy test keeps main per turn (default 50).

```sh
LOAD=4 CHUNK=100 swift test --filter ContentionTests
SWT_EXPERIMENTAL_MAXIMUM_PARALLELIZATION_WIDTH=2 LOAD=8 swift test --filter ContentionTests
```

`BlockedMainTests` は、時間の制限を超えるテストをわざと含むので失敗します。終わるまで約 90 秒かかります。
`BlockedMainTests` fails on purpose because some tests go over their time limit. It takes about 90 seconds.

## 中身 / Contents

| ファイル / File | 内容 / What it does |
|---|---|
| `Sources/MainActorLab/Probe.swift` | 経過時間・スレッドの番号・main かどうかを `LAB` で始まる行に出す。main を使い続ける `spin` と、スレッドを止める `blockThread` / Prints the elapsed time, thread number, and whether it runs on main on lines starting with `LAB`. Also `spin`, which keeps the thread busy, and `blockThread`, which blocks it |
| `Tests/ContentionTests/ContentionTests.swift` | `@MainActor` の重いテストと、AsyncStream で値を待つ 3 通りのテスト / Busy `@MainActor` tests and three tests that wait for a value on an AsyncStream |
| `Tests/BlockedMainTests/BlockedMainTests.swift` | `.timeLimit` を付けて値の来ない AsyncStream を待つテスト、main を 90 秒止めるテスト、1 秒で終わる 2 つのテスト / A test with `.timeLimit` that waits on a silent AsyncStream, a test that blocks main for 90 seconds, and two tests that need 1 second |

結果はテストのログに `LAB` と `RESULT` で始まる行として出ます。
Results appear in the test log as lines starting with `LAB` and `RESULT`.
