# Swift Testing traits in Xcode sample

記事「Swift Testing の .serialized はテストを 1 つずつ流すが、同じスレッドで動くとは限らない」の、UI テストの節で使ったプロジェクトです。
The project used in the UI test section of the post "Swift Testing .serialized runs tests one at a time but not on the same thread".

## 必要なもの / Requirements

- Xcode 27.3 beta 1 以降 / Xcode 27.3 beta 1 or later
- iOS 27.3 のシミュレータ / An iOS 27.3 simulator

`TraitsXcode.xcodeproj` は XcodeGen 2.45.4 で `project.yml` から生成したものです。XcodeGen がなくても、そのまま開けます。
`TraitsXcode.xcodeproj` was generated from `project.yml` with XcodeGen 2.45.4. You can open it without XcodeGen.

## 流し方 / Run

```sh
D='platform=iOS Simulator,name=iPhone 18 Pro,OS=27.3'

# 同時に走るか / Whether tests run in parallel
xcodebuild test -project TraitsXcode.xcodeproj -scheme TraitsXcode -destination "$D" \
  -only-testing:TraitsXcodeUnitTests/NoAppTests -parallel-testing-enabled YES
xcodebuild test -project TraitsXcode.xcodeproj -scheme TraitsXcode -destination "$D" \
  -only-testing:TraitsXcodeUITests/NoAppTests -parallel-testing-enabled YES

# .timeLimit
xcodebuild test -project TraitsXcode.xcodeproj -scheme TraitsXcode -destination "$D" \
  -only-testing:TraitsXcodeUITests/TimeLimitUITests
```

`TimeLimitUITests` と `TimeLimitUnitTests` は、時間の制限を超えるテストをわざと含むので失敗します。終わるまで約 3 分かかります。
`TimeLimitUITests` and `TimeLimitUnitTests` fail on purpose because some tests go over their time limit. Each takes about 3 minutes.

## 中身 / Contents

| ファイル / File | 内容 / What it does |
|---|---|
| `App/TraitsXcodeApp.swift` | 文字を 1 つ表示するだけのアプリ / An app that only shows one label |
| `UITests/NoAppTests.swift`, `UnitTests/NoAppTests.swift` | 3 秒待つだけの 3 つのテスト。UI テストと単体テストのターゲットに同じものを置いた / Three tests that only wait 3 seconds, placed in both the UI test and unit test targets |
| `UITests/LaunchingUITests.swift` | アプリを起動して 5 秒待つテスト。何も付けない Suite と `.serialized` の Suite / Tests that launch the app and wait 5 seconds, in a suite with no traits and in a `.serialized` suite |
| `UITests/TimeLimitUITests.swift` | `.timeLimit(.minutes(1))` を超える UI テスト。`Task.sleep` で待つものと `waitForExistence(timeout: 90)` で待つもの / UI tests that go over `.timeLimit(.minutes(1))`, one waiting with `Task.sleep` and one with `waitForExistence(timeout: 90)` |
| `UnitTests/TimeLimitUnitTests.swift` | 同じ制限を超える単体テスト。`Task.sleep` で待つものとスレッドを止めるもの / Unit tests that go over the same limit, one waiting with `Task.sleep` and one blocking its thread |

結果は `/tmp/traits-xcode.log` に、時刻 (UNIX 時間の秒)、テストの名前、プロセスの番号の行として追記されます。複製されたシミュレータで動くテストの出力は xcodebuild に出ないので、ファイルにも書いています。
Results are appended to `/tmp/traits-xcode.log` as lines with the time (UNIX seconds), the test name, and the process ID. The tests also write to a file because xcodebuild does not show the output of tests running on cloned simulators.
