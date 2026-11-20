---
title: 'Swift Testing の UI テストで存在しない要素を tap すると、テストは先へ進み、終わったあとでテストランナーが起動し直された'
description: 'UI テストを XCTest から Swift Testing と XCUIAutomation に移した。書き換えはほぼ 1 対 1 で済んだ。存在しない要素を tap すると、失敗は行番号なしで記録され、テストは次の行へ進み、終わったあとでテストランナーが起動し直された。先に try #require で存在を確かめると、起動し直されなかった。'
lang: ja
translationKey: ui-tests-xctest-to-swift-testing
publishDate: 2026-11-20
tags: ['Xcode', 'Swift', 'Testing']
draft: false
---

個人で作っている macOS の1日プランナー [FirnPlanner](https://firnplanner.l4l4.dev/) では、UI テストを XCTest から Swift Testing に移しました。Mac 版と、開発中の iPhone 版の両方です。Xcode 27.3 beta から、UI テストも Swift Testing と XCUIAutomation で書けます。単体テストはすでに Swift Testing だったので、書き方を 1 つにそろえるための移行です。

書き換えそのものは、ほぼ 1 対 1 で済みました。違ったのは、失敗したときの動きです。ボタンを 1 つ置いただけのアプリと、同じ内容のテストを XCTest と Swift Testing の両方で書いたサンプルを作り、iOS のシミュレータで確かめました。

## 書き換えは、ほぼ 1 対 1 で済んだ

| XCTest | Swift Testing |
|---|---|
| `import XCTest` | `import Testing` と `import XCUIAutomation` |
| `XCTestCase` のクラス | `@MainActor` を付けた struct の Suite |
| `setUp` でアプリを起動する | 各テストの最初で起動する |
| `tearDown` でアプリを終了する | 各テストの `defer` で終了する |
| `XCTAssertTrue`、`XCTAssertEqual` | `#expect`、`try #require` |
| `try XCTSkipUnless(...)` | Suite に付ける `.enabled(if:)` |
| `XCTAttachment` | `Attachment.record(_:named:)` |

XCTest で書いたテストは、次の形でした。

```swift
@MainActor
final class BasicXCTests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = launchApp()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    func testTapIncrementsLabel() {
        app.buttons["button"].tap()
        XCTAssertTrue(app.staticTexts["Count: 1"].waitForExistence(timeout: 5))
    }
}
```

Swift Testing では、こう書きました。`launchApp()` は、`XCUIApplication()` を作って `launch()` するだけの関数です。

```swift
@Suite(.serialized) enum UITests {}

extension UITests {
    @MainActor
    struct BasicTests {
        @Test func tapIncrementsLabel() throws {
            let app = launchApp()
            defer { app.terminate() }
            app.buttons["button"].tap()
            try #require(app.staticTexts["Count: 1"].waitForExistence(timeout: 5))
        }
    }
}
```

すべての Suite は、`.serialized` を付けた親の Suite の extension に入れました。UI テストは 1 台のシミュレータと 1 つのアプリを使い回すので、同時に走らせないためです。ただし今回のサンプルでは、`.serialized` を外した親に入れ、`-parallel-testing-enabled YES` で流しても、テストは 1 つずつ流れました。[Xcode 27.3 beta 1 で確かめたとき](/TIL/ja/posts/swift-testing-serialized-timelimit/)と同じです。ほかの設定でも同じとは限らないので、`.serialized` は付けたままにしています。

## 後片付けは defer で書いた。deinit でも動いた

struct の Suite には `deinit` がありません。`tearDown` に書いていたアプリの終了は、各テストの `defer` に移しました。テストが途中で `try #require` から抜けても、`defer` は走ります。

Suite を final class にして、`deinit` で終了する形も試しました。`@MainActor` の class の普通の `deinit` から `app.terminate()` を呼ぶと、次の警告が出ます。

```
warning: call to main actor-isolated instance method 'terminate()' in a synchronous nonisolated context
note: add 'isolated' to run isolated to 'MainActor', which may be later than 'nonisolated deinit'
```

警告が出たままでもビルドは通り、今回の実行では `deinit` はメインスレッドで走って、アプリも終了しました。`isolated deinit` と書くと、警告は出ません。こちらも動きました。普通の `deinit` がいつもメインスレッドで走るかは確かめていません。

## 存在しない要素を tap すると、テストは先へ進み、終わったあとでテストランナーが起動し直された

3 つのテストを並べ、2 つ目で、存在しないボタンを tap しました。テストごとに static のカウンターを 1 増やし、テストランナーのプロセスの番号と一緒にログに出します。

```swift
@Test func test2TapMissing() {
    let app = launchApp()
    defer { log("st.tapMissing.2 cleanup state=\(app.state.rawValue)"); app.terminate() }
    Self.counter += 1
    log("st.tapMissing.2 counter=\(Self.counter) before tap")
    app.buttons["missing"].tap()
    log("st.tapMissing.2 after tap")
}
```

出力はこうなりました。長い行は途中で切っています。`pid` はテストランナーのプロセスの番号で、`log` が付けます。`state=4` は、アプリが前面で動いていることを表す `runningForeground` です。

```
st.tapMissing.1 counter=1 pid=39022
st.tapMissing.2 counter=2 before tap pid=39022
✘ Test test2TapMissing() recorded an issue: Issue recorded
↳ Failed to tap "missing" Button: No matches found for Elements matching predicate ...
st.tapMissing.2 after tap pid=39022
st.tapMissing.2 cleanup state=4 pid=39022
Restarting after unexpected exit, crash, or test timeout; summary will include totals from previous launches.
st.tapMissing.3 counter=1 pid=39248
```

ここから分かったことは 4 つあります。

- 失敗は記録されたが、ファイル名と行番号は付かなかった
- テストは tap の次の行へ進み、`defer` も走った
- テストが終わったあとで、テストランナーのプロセスが起動し直された。3 つ目のテストは、新しいプロセスで流れた
- static のカウンターは 0 に戻った。3 つ目のテストでは 3 ではなく 1 になっている

この 3 つのテストは 3 回流し、3 回ともテストランナーが起動し直されました。後片付けを書かないテストでも 1 回試しました。1 つ目のテストが起動したアプリは、テストランナーが起動し直されたあと、動いていませんでした。

XCTest では、tap の行でテストが打ち切られ、失敗にはファイル名と行番号が付きました。テストランナーが起動し直されるかは、クラスによって違いました。async の `setUp` か `tearDown` を持つクラスでは起動し直され、持たないクラスでは同じプロセスのまま次のテストが流れました。何がこの違いを生むのかは、切り分けていません。

テストランナーが起動し直されると、テストのあいだで static の値に持たせた状態は消えます。FirnPlanner のテストは、どのテストも「データの置き場を新しく作ってアプリを起動する」ところから始めているので、起動し直されたあとのテストもそのまま通りました。

## 先に try #require で存在を確かめると、起動し直されなかった

同じ 3 つのテストで、2 つ目を、存在を確かめてから操作する形に変えました。

```swift
try #require(app.buttons["missing"].waitForExistence(timeout: 2))
app.buttons["missing"].tap()
```

```
st.waitRequire.2 counter=2 before wait pid=39248
✘ Test test2WaitMissing() recorded an issue at ExperimentTests.swift:80:17: Expectation failed: app.buttons["missing"].waitForExistence(timeout: 2)
st.waitRequire.2 cleanup pid=39248
st.waitRequire.3 counter=3 pid=39248
```

失敗には行番号が付き、テストはその行で終わりました。テストランナーは起動し直されず、カウンターも 3 まで続きました。`#expect` で確かめた場合も、起動し直されませんでした。

移行では、要素を操作する前の確認を `try #require` で書きました。失敗した場所がすぐ分かり、起動し直しも起きないためです。

## 添付と、環境変数があるときだけ走るテスト

スクリーンショットは、PNG のデータにして `Attachment.record` に渡しました。

```swift
Attachment.record(XCUIScreen.main.screenshot().pngRepresentation, named: "x.png")
```

`xcodebuild test` に `-resultBundlePath` を付けて流し、`xcrun xcresulttool export attachments` で取り出すと、XCTest の `XCTAttachment` のときと同じ形で、PNG と `manifest.json` が出てきました。`XCTAttachment` では `lifetime = .keepAlways` を指定していましたが、`Attachment.record` で残した画像は、何も指定しなくても、通ったテストの分が残っていました。

撮影用のテストのように、ふだんは流さないテストは、Suite に `.enabled(if:)` を付けました。

```swift
@Suite(.enabled(if: ProcessInfo.processInfo.environment["RUN_GATED"] != nil))
```

`xcodebuild` の前に `TEST_RUNNER_RUN_GATED=1` を付けると、テストランナーには `RUN_GATED` として渡り、Suite が走ります。付けないと `Suite GatedTests skipped.` と出て、飛ばされました。

## アプリのテストでは起きたが、サンプルでは再現しなかったこと

FirnPlanner のテストでは、アプリを終了した直後に次のテストが起動すると、流すたびに違うテストが失敗しました。終了のあとに `app.wait(for: .notRunning, timeout: 10)` を入れてからは、失敗していません。サンプルでは、`terminate()` の直後に `launch()` するのを 20 回繰り返しても、待つ場合と待たない場合のどちらも、XCTest と Swift Testing の両方で 1 回も失敗しませんでした。アプリの大きさや終了にかかる時間が関係しているのかもしれませんが、確かめていません。

起動と後片付けを自作の trait にまとめる形も、FirnPlanner ではテストランナーがクラッシュしたので、やめていました。サンプルでは、`TestScoping` を実装して `isRecursive` を `true` にした trait を Suite に付け、`provideScope` の中でアプリを起動して終了しても、テストランナーはクラッシュせず、テストも通りました。何が違ったのかは調べていません。trait からテストへ `XCUIApplication` を渡す方法は見つからなかったので、テストの側でもう一度 `XCUIApplication()` を作る形になりました。

## まとめ

- XCTest の UI テストは、ほぼ 1 対 1 で Swift Testing に書き換えられた。後片付けは各テストの `defer` に書いた
- 存在しない要素を tap すると、失敗は行番号なしで記録され、テストは先へ進み、終わったあとでテストランナーが起動し直された。static の値は初めに戻った
- 操作の前に `try #require` で存在を確かめると、失敗に行番号が付き、テストランナーは起動し直されなかった
- 起動し直されても続けられるよう、どのテストもアプリの起動から始める

試したプロジェクトは [samples/xcuitest-to-swift-testing](https://github.com/l4l4dev/TIL/tree/main/samples/xcuitest-to-swift-testing) に置きました。わざと失敗するテストは、通るテストと別の Suite に分けてあります。流し方は README に書きました。

確かめた環境: Xcode 27.3 beta 2 (27C5035i)、iOS 27.3 のシミュレータ (iPhone 18 Pro)、`xcodebuild test` で実行。
