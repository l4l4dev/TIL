# XCUITest to Swift Testing sample

記事「Swift Testing の UI テストで存在しない要素を tap すると、テストは先へ進み、終わったあとでテストランナーが起動し直された」で使ったプロジェクトです。
The project used in the post "Tapping a missing element in a Swift Testing UI test let the test continue, and the test runner restarted after it finished".

## 必要なもの / Requirements

- Xcode 27.3 beta 2 以降 / Xcode 27.3 beta 2 or later
- iOS 27.3 のシミュレータ / An iOS 27.3 simulator

`XCUITestMigration.xcodeproj` は XcodeGen 2.45.4 で `project.yml` から生成したものです。XcodeGen がなくても、そのまま開けます。
`XCUITestMigration.xcodeproj` was generated from `project.yml` with XcodeGen 2.45.4. You can open it without XcodeGen.

## 中身 / Contents

アプリはボタン 1 つとラベル 1 つだけです。UI テストのターゲットが 2 つあり、同じ内容のテストを XCTest と Swift Testing で書いています。
The app has one button and one label. There are two UI test targets with the same tests written in XCTest and in Swift Testing.

| XCTest (`XCTestUITests/`) | Swift Testing (`SwiftTestingUITests/`) |
|---|---|
| `XCTestCase` のクラス / `XCTestCase` classes | 親の `@Suite(.serialized) enum UITests` の extension に入れた `@MainActor` の struct / `@MainActor` structs in an extension of the parent `@Suite(.serialized) enum UITests` |
| `setUp` で `launchApp()`、`tearDown` で `terminate()` / `launchApp()` in `setUp`, `terminate()` in `tearDown` | テストの中で `launchApp()` と `defer { app.terminate() }` / `launchApp()` and `defer { app.terminate() }` in each test |
| `XCTAssertEqual`, `XCTAssertTrue` | `#expect`, `try #require` |
| `try XCTSkipUnless(...)` | Suite の `.enabled(if:)` / `.enabled(if:)` on the suite |
| `XCTAttachment` + `.keepAlways` | `Attachment.record(_, named:)` |

| ファイル / File | 内容 / What it does |
|---|---|
| `App/MigrationApp.swift` | ボタンを押すとラベルの数字が増えるアプリ / An app whose label counts button taps |
| `XCTestUITests/BasicXCTests.swift` | 通るのが正のテスト (基本、環境変数つき、添付、起動の確認) / Tests that should pass |
| `SwiftTestingUITests/BasicTests.swift` | 同じ内容の Swift Testing 版 / The same in Swift Testing |
| `SwiftTestingUITests/AppScopeTrait.swift` | 起動と後片付けをする自作の trait `AppScope` と、それを付けた Suite / A custom trait `AppScope` that launches and cleans up, and a suite using it |
| `SwiftTestingUITests/DeinitExperiment.swift` | `deinit` と `isolated deinit` で後片付けをする Suite / Suites that clean up in `deinit` and `isolated deinit` |
| `XCTestUITests/ExperimentXCTests.swift`, `SwiftTestingUITests/ExperimentTests.swift` | わざと失敗する実験用のテスト / Tests that fail on purpose |

実行ごとのログは `/tmp/xcuitest-migration.log` に、時刻 (UNIX 時間の秒)、ラベル、テストランナーのプロセスの番号の行として追記されます。複製されたシミュレータで動くテストの出力は xcodebuild に出ないので、ファイルにも書いています。
Each run appends lines to `/tmp/xcuitest-migration.log` with the time (UNIX seconds), a label, and the test runner's process ID. The tests also write to a file because xcodebuild does not show the output of tests running on cloned simulators.

## 流し方 / Run

```sh
D='platform=iOS Simulator,name=iPhone 18 Pro,OS=27.3'
T='-project XCUITestMigration.xcodeproj -scheme XCUITestMigration'

# 通るのが正のテスト / Tests that should pass
xcodebuild test $T -destination "$D" \
  -only-testing:XCTestUITests/BasicXCTests -only-testing:XCTestUITests/GatedXCTests -only-testing:XCTestUITests/ProbeXCTests
xcodebuild test $T -destination "$D" \
  -only-testing:SwiftTestingUITests/UITests/BasicTests -only-testing:SwiftTestingUITests/UITests/GatedTests \
  -only-testing:SwiftTestingUITests/UITests/ProbeTests -only-testing:SwiftTestingUITests/UITests/TraitScopedTests \
  -only-testing:SwiftTestingUITests/UITests/DeinitTests -only-testing:SwiftTestingUITests/UITests/IsolatedDeinitTests

# RUN_GATED を付けたときだけ走るテスト / Tests that run only with RUN_GATED
TEST_RUNNER_RUN_GATED=1 xcodebuild test $T -destination "$D" \
  -only-testing:XCTestUITests/GatedXCTests -only-testing:SwiftTestingUITests/UITests/GatedTests

# 同時に走るか / Whether tests run in parallel (parent suite without .serialized)
xcodebuild test $T -destination "$D" -parallel-testing-enabled YES \
  -only-testing:SwiftTestingUITests/UnserializedUITests
```

`-only-testing` は該当するテストが 0 件でも成功になります。出力の `Test run with N tests` や `Executed N tests` の件数を見てください。Swift Testing のテスト 1 件を選ぶときは `.../BasicTests/attachesScreenshot()` のように括弧まで書きます。
`-only-testing` succeeds even when it matches no tests. Check the count in `Test run with N tests` or `Executed N tests`. To select one Swift Testing test, include the parentheses, as in `.../BasicTests/attachesScreenshot()`.

`RUN_GATED` なしの通常の実行では、XCTest の 1 件と Swift Testing の 1 件が skip になります (XCTest: `Executed 7 tests, with 1 test skipped`、Swift Testing: `Test run with 11 tests`)。
Without `RUN_GATED`, one XCTest test and one Swift Testing test are skipped (XCTest: `Executed 7 tests, with 1 test skipped`; Swift Testing: `Test run with 11 tests`).

## わざと失敗するテスト / Tests that fail on purpose

次のテストは失敗するのが正です。
These tests are supposed to fail.

```sh
# 存在しない要素を tap する / Taps an element that does not exist
-only-testing:XCTestUITests/TapMissingXCTests
-only-testing:XCTestUITests/TapMissingNoCleanupXCTests
-only-testing:XCTestUITests/ContinueAfterFailureXCTests
-only-testing:XCTestUITests/RestartAsyncSetUpFalseXCTests   # RestartSyncSetUpFalse, RestartAsyncSetUpDefault, RestartAsyncTearDown も同じ / same for the others
-only-testing:SwiftTestingUITests/UITests/TapMissingTests
-only-testing:SwiftTestingUITests/UITests/TapMissingNoCleanupTests

# 存在しない要素を待って結果を確かめる / Waits for a missing element and checks the result
-only-testing:XCTestUITests/WaitMissingXCTests
-only-testing:SwiftTestingUITests/UITests/WaitMissingExpectTests
-only-testing:SwiftTestingUITests/UITests/WaitMissingRequireTests
```

`RelaunchXCTests` と `UITests/RelaunchTests` は、終了を待たずに `launch()` を 20 回繰り返します。失敗するとは限りません。
`RelaunchXCTests` and `UITests/RelaunchTests` call `launch()` 20 times right after `terminate()`. They do not necessarily fail.
