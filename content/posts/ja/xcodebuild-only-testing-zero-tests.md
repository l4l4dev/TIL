---
title: 'xcodebuild の -only-testing は、指定が外れるとテスト 0 件で「成功」になる'
description: 'Swift Testing のテストを xcodebuild の -only-testing で絞ると、Suite の入れ子や () の付け方を間違えたときに 1 件も走らず TEST SUCCEEDED と終了コード 0 が返る。Executed の行もあてにならないので、Test run with N tests の N を見る。'
lang: ja
translationKey: xcodebuild-only-testing-zero-tests
publishDate: 2026-10-31
tags: ['Xcode', 'Swift', 'Testing']
draft: false
---

[FirnPlanner](https://firnplanner.l4l4.dev/) の開発で、落ちたスナップショットテストを 1 本だけ流し直したら「通った」と出ました。あとでログを見ると、1 件も走っていませんでした。

## わざと失敗するテストで試す

小さいパッケージに、必ず失敗するテストを 1 本だけ置きました。Suite は入れ子にしてあります。

```swift
import Testing
@testable import Calc

@Suite struct Outer {
    @Suite struct AddTests {
        @Test func addsTwoNumbers() {
            #expect(add(1, 2) == 4) // わざと失敗させる
        }
    }
}
```

これを `-only-testing` の書き方だけ変えて流しました。

```sh
xcodebuild test -scheme Calc-Package -destination 'platform=macOS' \
  -only-testing:CalcTests/Outer/AddTests
```

| `-only-testing:` の値 | 走った数 | 結果 |
|---|---|---|
| `CalcTests` | 1 | 失敗 (正しい) |
| `CalcTests/Outer/AddTests` | 1 | 失敗 (正しい) |
| `CalcTests/Outer/AddTests/addsTwoNumbers()` | 1 | 失敗 (正しい) |
| `CalcTests/AddTests` (親の Suite を飛ばした) | 0 | **成功** |
| `CalcTests/Outer/AddTests/addsTwoNumbers` (`()` が無い) | 0 | **成功** |
| `CalcTests/Outer()` (Suite に `()` を付けた) | 0 | **成功** |
| `CalcTests/Outre` (つづりの間違い) | 0 | **成功** |

外れた 4 つは、どれも `** TEST SUCCEEDED **` で、終了コードも 0 でした。存在しない名前を渡しても、名前が見つからないという警告は出ませんでした。

## Swift Testing の指定の形

試した範囲では、こうなりました。

- Suite は入れ子のとおりに全部たどる (`Outer/AddTests`)。親を飛ばすと当たらない
- テストの関数は、末尾に `()` を付ける (`addsTwoNumbers()`)
- Suite (struct) には `()` を付けない

## 「Executed」の行は見ない

ログには、XCTest の形の `Executed 0 tests` という行が、正しく 1 件走ったときにも出ていました。Swift Testing のテストは、この行には数えられていないようです。

件数は、Swift Testing が出す次の行で確かめます。

```text
✘ Test run with 1 test in 2 suites failed after 0.001 seconds with 1 issue.
```

外れたときは、この行が `Test run with 0 tests` になるか、行そのものが出ません。

## まとめ

- `-only-testing` の指定が外れると、テストが 0 件のまま「成功」になる
- Swift Testing では、Suite を入れ子のとおりにたどり、関数にだけ `()` を付ける
- 一部だけ流したときは、`Test run with N tests` の N が 0 でないことを見てから「通った」と言う

確かめた環境: Xcode 27.2 (27B52)、macOS 27.2。
