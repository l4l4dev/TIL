---
title: 'Swift Testing で @MainActor のテストが同時に走ると、AsyncStream の値が届くまでの時間は main を使うテストの数に比例して延びた'
description: '@MainActor のテストは同時に走っても、main スレッドは 1 本なので順番に使う。値を待つテストが main にいると、ほかのテストが main を使う時間の分だけ値の受け取りが遅れ、自前の 1 秒のタイムアウトが切れることもあった。main がふさがっていると、.timeLimit で時間切れになってもテストは終わらなかった。'
lang: ja
translationKey: swift-testing-mainactor-contention
publishDate: 2026-11-07
tags: ['Swift', 'Testing']
draft: false
---

個人で作っている macOS の1日プランナー [FirnPlanner](https://firnplanner.l4l4.dev/) では、`@MainActor` を付けたテストがたくさんあります。CI のように手元より遅いマシンで流すと、AsyncStream で値を待つテストの自前のタイムアウトが切れやすくなるのではないか、という話になりました。そこで、`@MainActor` のテストが同時に走るとき値の受け取りがどれだけ遅れるかを、小さなパッケージで確かめました。

## @MainActor のテストは同時に走るが、main は 1 本しかない

Swift Testing は、何も指定しなければテストを同時に走らせます。`@MainActor` を付けたテストも同時に始まりますが、動くのはどれも main スレッドです。テストの中で `pthread_main_np()` を呼ぶと、`@MainActor` のテストでは毎回 main と出ました。main は 1 本なので、`@MainActor` のテストは `await` で順番を譲り合いながら main を使います。

この順番待ちで値の受け取りがどれだけ遅れるかを、次のように測りました。

- 待つテスト: AsyncStream から値を 1 つ受け取る。値は、送る側のタスクが始まってから 300ms 後に送る。1 秒たっても届かなければ、タイマーが AsyncStream を終わらせる (自前のタイムアウト)。これを 5 回くり返し、300ms から何 ms 遅れて届いたかを記録する
- 重いテスト: `@MainActor` で、main を 50ms 使い続けてから `Task.yield()` で順番を譲る。これを約 4 秒くり返す。同時に走らせる数を 0、2、4、8 と変える

```swift
let (stream, continuation) = AsyncStream<Int>.makeStream()
Task { @MainActor in            // 送る側を main に置く場合
    try? await Task.sleep(for: .milliseconds(300))
    continuation.yield(1)
}
Task.detached {                 // 自前の 1 秒のタイムアウト
    try? await Task.sleep(for: .seconds(1))
    continuation.finish()
}
for await _ in stream { received = true; break }
```

待つテストは 3 通り用意しました。待つ側も送る側も main 以外、待つ側だけ main、待つ側も送る側も main、です。

## 待つ側が main にいると、遅れは重いテストの数 × 50ms になった

3 回流して、遅れは次のとおりでした。

| 同時に走る重いテスト | 待つ側も送る側も main 以外 | 待つ側だけ main | 待つ側も送る側も main |
|---|---|---|---|
| 0 個 | 0〜14ms | 0〜14ms | 0〜14ms |
| 2 個 | 0〜16ms | 50〜100ms | 200〜300ms |
| 4 個 | 0〜19ms | 200ms | 500〜600ms |
| 8 個 | 0〜20ms | 350〜400ms | 5 回中 2 回、1 秒で時間切れ |

待つ側だけ main にいるとき、遅れはほとんどの回で、2 個なら 100ms、4 個なら 200ms、8 個なら 400ms でした。重いテストの数 × 50ms と同じです。待つ側は、値が届いたあと main で続きを動かす順番を、重いテストの後ろで待っていると考えています。待つ側が main 以外にいれば、重いテストが 8 個でも遅れは 20ms 以下でした。

送る側も main にいると、遅れはおよそ倍になりました。送る側が値を送るときにも、main の順番を待つからだと考えています。重いテストが 8 個のときは、3 回とも 5 回中 2 回が 1 秒の自前のタイムアウトで切れました。

各行の最後の 1〜2 回は、遅れが小さくなることがありました。重いテストは約 4 秒で終わるので、その後の待ちでは main の順番待ちがなくなるためです。表の範囲には、この小さな値を入れていません。

![300ms 後に送られる値を AsyncStream で待ったときの遅れ。待つ側だけ main にいると、同時に走る @MainActor の重いテストが 0、2、4、8 個のとき、遅れはほぼ 0、100ms、200ms、400ms だった。送る側も main にいると、ほぼ 0、200〜300ms、500〜600ms で、8 個では 5 回中 2 回が自前の 1 秒のタイムアウトで切れた。重いテストはそれぞれ main を 50ms 使ってから順番を譲る。重いテストが 8 個のときの遅れ 400ms は、待つ側が 8 個の後ろに並んだときの 8 × 50ms と同じだった。main 以外で待つと、8 個でも遅れは 20ms 以下だった。](/TIL/images/swift-testing-mainactor-ja.svg)

## 1 回に main を使う時間を倍にすると、遅れも倍になった

同じ処理が遅いマシンで動く場合を真似て、4 個の重いテストが 1 回に main を使う時間を 50ms から 100ms にしました。3 回流すと、待つ側だけ main のときの遅れは 400ms になり、50ms のときの 200ms の倍でした。待つ側も送る側も main のときは、3 回とも、5 回中 1〜2 回が 1 秒で時間切れになりました。50ms のときは、4 個では 1 回も切れていません。

## --num-workers では、同時に走るテストの数は変わらなかった

同時に走る数を絞れば main の順番待ちも減るはずなので、絞り方も試しました。

`swift test --parallel --num-workers 2` で流しても、結果は絞らないときと同じでした。8 個のときで比べると、待つ側だけ main の遅れは 400ms、待つ側も送る側も main では 5 回中 2 回が時間切れでした。`--parallel` を付けずに `--num-workers` だけを渡すと、`error: --num-workers must be used with --parallel` で止まりました。

同時に走る数が変わったのは、環境変数 `SWT_EXPERIMENTAL_MAXIMUM_PARALLELIZATION_WIDTH=2` を付けたときです。重いテストは 2 つずつ流れ、8 個 × 4 秒を流し終えるまでに約 21 秒かかりました。2 回流して、どの待つテストの遅れも 50ms 以下でした。ただし、2 回とも待つテストのほうが重いテストより先に流れていたので、遅れが減ったのは流れた順番のせいでもあります。この環境変数は Testing.framework の中にある名前で、名前のとおり experimental です。公式ドキュメントの [Running tests serially or in parallel](https://github.com/swiftlang/swift-testing/blob/main/Sources/Testing/Testing.docc/Parallelization.md) には、同時に走るテストの数は Swift のランタイムが決める、とだけ書かれています。

## main がふさがっていると、.timeLimit で時間切れになってもテストは終わらない

`.timeLimit` が AsyncStream の待ちを止めるかも確かめました。値も終わりも来ない AsyncStream を `for await` で待つテストに、`.timeLimit(.minutes(1))` を付けました。

```swift
@Test(.timeLimit(.minutes(1))) @MainActor func waitsOnSilentStream() async {
    let (stream, continuation) = AsyncStream<Int>.makeStream()
    for await _ in stream {}
    continuation.finish()
}
```

このテストだけを流すと、約 64 秒でタスクがキャンセルされてループを抜け、`Time limit was exceeded: 60.000 seconds` で失敗しました。

次に、同じ Suite に `@MainActor` で main を 90 秒止めるテスト (`Thread.sleep(forTimeInterval: 90)`) と、1 秒で終わる `@MainActor` のテストと、1 秒で終わる main 以外のテストを並べました。3 回流して、どれも次のようになりました。

- 値を待つテストと main を止めるテストは、どちらも時間切れが記録された
- ただし、値を待つテストがループを抜けて失敗したのは約 90 秒後だった。キャンセルされても、ループを抜けて続きを動かすには main が空くのを待つ必要がある
- 1 秒で終わるはずの `@MainActor` のテストも、終わったのは約 90 秒後だった
- main 以外のテストは 1 秒で終わった

1 回目は、値を待つテストの本体が始まったのは約 90 秒後でした。それでも時間切れは記録されていました。制限時間は、本体が main で動き始めた時点ではなく、テストが始まった時点から数えているように見えます。

## CI で切れやすくなるのはどういうときか

ここからは、上の結果からの推測です。CI の実機では試していません。

遅れは、同時に走る `@MainActor` のテストの数と、それぞれが 1 回に main を使い続ける時間で決まっていました。CI のマシンが遅いと 1 回に main を使う時間が延びるので、テストの数とのかけ算で遅れが増えると考えています。main は 1 本なので、CI でコアの数が増えても、この順番待ちは減らないはずです。

テストを書くときは、次の順で手を打つのがよいと考えています。

- AsyncStream で値を送る側と、テストしたい処理の本体を main から外す。今回の結果では、待つ側が main 以外にいれば遅れは 20ms 以下だった
- 秒単位の自前のタイムアウトで待つのをやめ、値が届くまで待つ。値が届かないまま止まったときに失敗させるのは `.timeLimit` に任せる。Hacking with Swift の記事も、AsyncStream は `confirmation(expectedCount:)` の中で `for await` して確かめる書き方を勧めている
- main を長く使うテストを `.serialized` の Suite にまとめ、同時に走らないようにする
- main を同期で止めるコードはテストに入れない。止まっているあいだは、`.timeLimit` もほかの `@MainActor` のテストも進まない

`confirmation` は、呼んだ側のアクターで中身を動かします (`isolation: isolated (any Actor)? = #isolation`)。`@MainActor` のテストから呼べば中身も main で動くので、今回の順番待ちはそのまま起きると考えています。

## まとめ

- `@MainActor` のテストは同時に走るが、main は 1 本なので順番に使う。値を待つテストが main にいると、遅れは同時に走る重いテストの数 × 1 回に main を使う時間になった
- 送る側も main にいると遅れはおよそ倍になり、自前の 1 秒のタイムアウトが切れた
- 同時に走る数は `--num-workers` では変わらず、experimental な環境変数でだけ絞れた
- `.timeLimit` は AsyncStream の待ちをキャンセルして止めるが、main がふさがっているあいだは、時間切れが記録されてもテストは終わらない

試したパッケージは [samples/swift-testing-mainactor](https://github.com/l4l4dev/TIL/tree/main/samples/swift-testing-mainactor) に置きました。`LOAD=8 swift test --filter ContentionTests` で順番待ちの実験を、`swift test --filter BlockedMainTests` で `.timeLimit` の実験を試せます。`BlockedMainTests` はわざと失敗するテストを含み、終わるまで約 90 秒かかります。

確かめた環境は次のとおりです。

- Xcode 27.2 (27B52)
- Swift 6.4.2
- macOS 27.2
- `swift test` で実行
- Apple シリコンの Mac (論理 CPU 18 個)

参考にしたもの:

- [Running tests serially or in parallel](https://github.com/swiftlang/swift-testing/blob/main/Sources/Testing/Testing.docc/Parallelization.md) (Swift Testing の公式ドキュメント)
- [Testing asynchronous code](https://github.com/swiftlang/swift-testing/blob/main/Sources/Testing/Testing.docc/testing-asynchronous-code.md) (Swift Testing の公式ドキュメント)
- [How to force concurrent tests to run on a specific actor](https://www.hackingwithswift.com/quick-start/concurrency/how-to-force-concurrent-tests-to-run-on-a-specific-actor) (Hacking with Swift)
- [How to test AsyncSequence and AsyncStream](https://www.hackingwithswift.com/quick-start/concurrency/how-to-test-asyncsequence-and-asyncstream) (Hacking with Swift)
