---
title: 'XCUIHinge でヒンジの角度を UI テストから動かせる。ただし同じ角度でもレイアウトは同じにならない'
description: 'Xcode 27.3 beta 1 で入った XCUIHinge を iPhone Duo のシミュレータで試した。角度はラジアンで設定でき、XCTest でも Swift Testing でも動く。読み返す角度は設定値より手前で止まり、同じ角度でもそこまでの開き方でレイアウトが変わった。'
lang: ja
translationKey: xcuihinge-ui-test
publishDate: 2026-11-05
tags: ['Xcode', 'iOS', 'Simulator', 'Testing']
draft: false
---

個人で作っている macOS の1日プランナー [FirnPlanner](https://firnplanner.l4l4.dev/) では、iPhone Duo 向けの版を開発しています。開いたときと閉じたときでレイアウトを変えるので、ヒンジの角度を UI テストから動かせる `XCUIHinge` が Xcode 27.3 beta 1 で入ったと聞いて、シミュレータで試しました。

## API は角度のプロパティが 1 つだけ

ヘッダ (`XCUIAutomation.framework/Headers/XCUIHinge.h`) にあるのは、これだけでした。

- `XCUIDevice.shared.hinge` で取る。型は `XCUIHinge?` で、ヒンジのない機種では `nil`
- `angle` は `CGFloat` で、単位はラジアン。0 が閉じた状態、π が平らに開いた状態
- MainActor から使う
- 実機では、閉じた状態からプログラムで開くとテストが失敗する、と注記がある

ヘッダには「角度を読んでも、アプリがどちらのレイアウトかは分からない」とも書いてあります。後で、この注記どおりの結果になりました。

## XCTest でも Swift Testing でも書ける

試すために、画面の幅と size class を表示するだけのアプリを作り、UI テストのターゲットを 2 つ付けました。XCTest のほうは `import XCTest` だけで `hinge` が使えます。

```swift
import XCTest

final class HingeXCTests: XCTestCase {
    @MainActor
    func testOpenFlat() throws {
        let app = XCUIApplication()
        app.launch()

        let hinge = try XCTUnwrap(XCUIDevice.shared.hinge)
        hinge.angle = .pi // 平らに開く

        let sizeClass = app.staticTexts["sizeClass"]
        XCTAssertTrue(sizeClass.wait(for: \.label, toEqual: "regular", timeout: 5))
    }
}
```

Swift Testing では `Testing` と `XCUIAutomation` を読み込み、Suite を `@MainActor` にしました。ターゲットは普通の UI テストのターゲットで、特別な設定は加えていません。

```swift
import Testing
import XCUIAutomation

@MainActor
struct HingeSwiftTests {
    @Test func openFlatShowsRegularWidth() throws {
        let app = XCUIApplication()
        app.launch()

        let hinge = try #require(XCUIDevice.shared.hinge)
        hinge.angle = .pi

        let sizeClass = app.staticTexts["sizeClass"]
        #expect(sizeClass.wait(for: \.label, toEqual: "regular", timeout: 5))
    }
}
```

どちらも iPhone Duo のシミュレータで通りました。iPhone 18 Pro のシミュレータでは、`hinge` が `nil` でした。実機では試していません。

## 読み返す角度は、設定した値より手前で止まる

角度を設定し、表示が 2 秒変わらなくなるまで待ってから `angle` を読み返しました。

| 動かし方 | 設定 | 読み返した値 |
|---|---|---|
| 0° から開く | 30° | 28.46° |
| 60° から開く | 90° | 88.46° |
| 120° から閉じる | 90° | 91.54° |
| 0° から一気に | 90° | 85.38° |
| 180° から一気に | 90° | 94.62° |
| どこからでも | 0° / 180° | 0° / 180° |

途中の角度では、動かした幅のおよそ 5% だけ手前で止まりました。0° と 180° は設定どおりになり、範囲外の値 (200°、-10°) はそれぞれ 180° と 0° になりました。同じ並びで 3 回流すと、ほとんどの値は 0.1° 以内で揃いました。1 か所だけ (150° から 120° に閉じたとき)、121.54° と 120.93° の 2 通りに分かれました。

なぜ手前で止まるのかは分かりません。テストで角度を比べるなら、設定値とぴったり同じになる前提では書けません。

## 同じ 90° でも、開き方でレイアウトが変わる

同じテストで、size class も記録しました。

- 0° から 15〜30° ずつ開くと、120° までは compact、150° で regular に変わった
- 180° から 15〜30° ずつ閉じると、30° まで regular のままで、0° で compact に戻った
- 0° から一気に 90° に開くと regular になった

つまり 90° のときの size class は、0° から少しずつ開くと compact、一気に開くと regular でした。3 回とも同じでした。

ほかに、3 回のうち 1 回だけ、0° まで閉じたのに regular のまま残りました。この 1 回は再現していません。

なお、最初に `sleep(1)` で 1 秒だけ待って読んだときは、45° で regular という、ほかと合わない値が出ました。レイアウトが切り替わり終わる前に読んでいたためだと考えています。テストで表示を確かめるときは、一定時間待つより、表示が変わらなくなるまで待つほうが安定しました。

## まとめ

- `XCUIDevice.shared.hinge?.angle` にラジアンで入れると、シミュレータのヒンジが動く。XCTest でも Swift Testing でも使える
- 読み返す角度は、途中の値では設定値とずれる。比べるなら幅を持たせる
- 角度だけでレイアウトは決まらない。テストでは角度を設定した後、画面の表示そのものを確かめる

試したプロジェクトは [samples/xcuihinge](https://github.com/l4l4dev/TIL/tree/main/samples/xcuihinge) に置きました。表の値は、この中の `HingeSettleTests` で取ったものです。

確かめた環境は次のとおりです。

- Xcode 27.3 beta 1 (27C5020n)
- iOS 27.3 シミュレータ (24C5037i) の iPhone Duo と iPhone 18 Pro
- macOS 27.2
- プロジェクトの生成: XcodeGen 2.45.4
